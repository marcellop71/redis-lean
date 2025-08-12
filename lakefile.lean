import Lake
open System Lake DSL

/-- libhiredis must be installed on the system -/

package redisLean where
  extraDepTargets := #[`libhiredis_shim]
  moreLinkArgs := #[
    "-L/usr/lib/x86_64-linux-gnu",
    "-Wl,-rpath,/usr/lib/x86_64-linux-gnu",
    "-lhiredis"
  ]

lean_lib RedisLean

lean_lib RedisModel

lean_lib Examples

target hiredis_shim_o pkg : FilePath := do
  let srcFile := pkg.dir / "hiredis" / "shim.c"
  let oFile   := pkg.buildDir / "hiredis" / "shim.o"
  IO.FS.createDirAll oFile.parent.get!
  let flags := #["-fPIC", "-O2", "-I", (← getLeanIncludeDir).toString]
  compileO oFile srcFile flags
  return .pure oFile

extern_lib libhiredis_shim pkg := do
  let obj ← hiredis_shim_o.fetch
  let name := nameToStaticLib "hiredis_shim"
  buildStaticLib (pkg.staticLibDir / name) #[obj]

require mathlib from git
  "https://github.com/leanprover-community/mathlib4" @ "master"

require Cli from git
  "https://github.com/leanprover/lean4-cli.git" @ "main"

@[default_target]
lean_exe examples where
  root := `Examples.Main
