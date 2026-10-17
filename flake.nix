{
  description = "redis-lean - Lean 4 bindings for Redis via hiredis";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    zlog-lean.url = "github:marcellop71/zlog-lean";
    arrow-lean.url = "github:marcellop71/arrow-lean";
  };

  outputs = { self, nixpkgs, flake-utils, zlog-lean, arrow-lean }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        zlogDeps = zlog-lean.lib.${system};
        arrowDeps = arrow-lean.lib.${system};
        # Lean 4 release binary. Keep `leanVersion` equal to
        # `lean-toolchain` (leanprover/lean4:v4.35.0) and refresh the
        # four hashes together:
        #   curl -sL https://github.com/leanprover/lean4/releases/download/v$V/lean-$V-$P.tar.zst \
        #     | sha256sum | cut -d' ' -f1 | xxd -r -p | base64      # → sha256-…
        # (or `nix hash file` on the downloaded tarball).
        leanVersion = "4.35.0";
        leanPlatform = {
          "x86_64-linux"   = "linux";
          "aarch64-linux"  = "linux_aarch64";
          "x86_64-darwin"  = "darwin";
          "aarch64-darwin" = "darwin_aarch64";
        }.${system} or (throw "redis-lean: no Lean release tarball for ${system}");
        leanSha256 = {
          "linux"          = "sha256-colZekRUMkbJInuMrlAXZ+CVzhf21Ei5X8So3Jcmj20=";
          "linux_aarch64"  = "sha256-yPD4o5IOg5cYsTQ+Z4H9gKPpsQJPvNcHjrMPVOgGsCg=";
          "darwin"         = "sha256-C0O+XH7Ps2AWVmpBAFq2K9sEdD5r/Vg35F95bvR1C04=";
          "darwin_aarch64" = "sha256-wMbzTzW6HcxcSl/RBv76uetehGlxJiTdLIaNUbYxd8I=";
        }.${leanPlatform};

        lean4Bin = pkgs.stdenv.mkDerivation {
          pname = "lean4";
          version = leanVersion;
          src = pkgs.fetchurl {
            url = "https://github.com/leanprover/lean4/releases/download/v${leanVersion}/lean-${leanVersion}-${leanPlatform}.tar.zst";
            sha256 = leanSha256;
          };
          nativeBuildInputs = [ pkgs.zstd ]
            ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.autoPatchelfHook ];
          buildInputs = pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib pkgs.zlib ];
          unpackPhase = ''
            tar --zstd -xf $src
          '';
          installPhase = ''
            mkdir -p $out
            cp -r lean-${leanVersion}-${leanPlatform}/* $out/
          '';
        };

        # Library path variable name (different on Darwin vs Linux)
        libPathVar = if pkgs.stdenv.isDarwin then "DYLD_LIBRARY_PATH" else "LD_LIBRARY_PATH";
        leanBin = lean4Bin;
        lakeBin = lean4Bin;

        # Native dependencies for building
        nativeDeps = [
          zlogDeps.zlog
          pkgs.hiredis
          pkgs.gmp
          pkgs.arrow-cpp
        ];

        # Development shell with all dependencies
        devShell = pkgs.mkShell {
          buildInputs = nativeDeps ++ [
            leanBin
            lakeBin
            pkgs.clang
            pkgs.lld
            pkgs.redis  # for testing
          ];

          "${libPathVar}" = pkgs.lib.makeLibraryPath nativeDeps;
          LIBRARY_PATH = pkgs.lib.makeLibraryPath nativeDeps;
          C_INCLUDE_PATH = pkgs.lib.makeSearchPath "include" [ zlogDeps.zlog pkgs.hiredis ];

          shellHook = ''
            echo "redis-lean development environment"
            echo "Lean version: $(lean --version 2>/dev/null || echo 'Lean not found')"
            echo "hiredis available at: ${pkgs.hiredis}"
          '';
        };

        # Build the Lean package
        redisLeanPackage = pkgs.stdenv.mkDerivation {
          pname = "redis-lean";
          version = "0.1.0";
          src = ./.;

          nativeBuildInputs = [ leanBin lakeBin pkgs.clang pkgs.lld pkgs.makeWrapper ];
          buildInputs = nativeDeps ++ [ zlogDeps.zlogLeanPackage arrowDeps.arrowLeanPackage ];

          patchPhase = ''
            # Remove require statements for dependencies we don't provide via lake-packages.json
            # zlogLean and arrowLean are provided via lake-packages.json, so keep those
            sed -i '/^require Cli from git/,+1d' lakefile.lean
            sed -i '/^require LSpec from git/,+1d' lakefile.lean
          '';

          configurePhase = ''
            export HOME=$TMPDIR

            # Set LEAN_PATH to include dependencies
            export LEAN_PATH="${zlogDeps.zlogLeanPackage}/lib/lean:$LEAN_PATH"
          '';

          buildPhase = ''
            # Set up library paths for FFI compilation
            export ${libPathVar}="${pkgs.lib.makeLibraryPath nativeDeps}"
            export LIBRARY_PATH="${pkgs.lib.makeLibraryPath nativeDeps}"
            export C_INCLUDE_PATH="${pkgs.lib.makeSearchPath "include" [ zlogDeps.zlog pkgs.hiredis ]}"
            export CPLUS_INCLUDE_PATH="${pkgs.arrow-cpp}/include"
            export ARROW_LIB_PATH="${pkgs.arrow-cpp}/lib"
            export LEAN_PATH="${zlogDeps.zlogLeanPackage}/lib/lean:${arrowDeps.arrowLeanPackage}/lib/lean:$LEAN_PATH"

            # Build the package
            ZLOG_LEAN_DIR="$TMPDIR/zlog-lean"
            ARROW_LEAN_DIR="$TMPDIR/arrow-lean"
            cp -r "${zlog-lean}" "$ZLOG_LEAN_DIR"
            cp -r "${arrow-lean}" "$ARROW_LEAN_DIR"
            chmod -R u+w "$ZLOG_LEAN_DIR" "$ARROW_LEAN_DIR"
            # Patch arrowLean's lakefile to remove its git requires
            sed -i '/^require Cli from git/,+1d' "$ARROW_LEAN_DIR/lakefile.lean"
            sed -i '/^require zlogLean from git/,+1d' "$ARROW_LEAN_DIR/lakefile.lean"
            cat > $TMPDIR/lake-packages.json <<EOF
            {
              "version": "1.1.0",
              "packages": [
                {
                  "type": "path",
                  "scope": "",
                  "name": "zlogLean",
                  "manifestFile": "lake-manifest.json",
                  "inherited": false,
                  "dir": "$ZLOG_LEAN_DIR",
                  "configFile": "lakefile.lean"
                },
                {
                  "type": "path",
                  "scope": "",
                  "name": "arrowLean",
                  "manifestFile": "lake-manifest.json",
                  "inherited": false,
                  "dir": "$ARROW_LEAN_DIR",
                  "configFile": "lakefile.lean"
                }
              ]
            }
            EOF
            lake build --packages $TMPDIR/lake-packages.json
          '';

          installPhase = ''
            mkdir -p $out/bin $out/lib

            # Copy executables if they exist
            if [ -d .lake/build/bin ]; then
              for bin in .lake/build/bin/*; do
                if [ -f "$bin" ]; then
                  cp "$bin" $out/bin/
                  wrapProgram "$out/bin/$(basename "$bin")" \
                    --prefix ${libPathVar} : "${pkgs.lib.makeLibraryPath nativeDeps}"
                fi
              done
            fi

            # Copy libraries
            if [ -d .lake/build/lib ]; then
              cp -r .lake/build/lib/* $out/lib/
            fi

            # Copy Lake package metadata for downstream consumers
            mkdir -p $out/share/lean
            cp -r .lake/build/ir $out/share/lean/ || true
            cp lakefile.lean $out/share/lean/
            cp lean-toolchain $out/share/lean/
          '';
        };

      in {
        devShells.default = devShell;

        packages.default = redisLeanPackage;

        lib = {
          inherit nativeDeps redisLeanPackage;
          hiredis = pkgs.hiredis;
        };
      }
    );
}
