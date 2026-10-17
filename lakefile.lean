import Lake
open System Lake DSL

-- libhiredis must be installed on the system

package redisLean where
  extraDepTargets := #[`libhiredis_shim]
  moreLinkArgs := #[
    "-L/usr/lib/x86_64-linux-gnu",
    "-Wl,-rpath,/usr/lib/x86_64-linux-gnu",
    "-L/usr/local/lib",
    "-Wl,-rpath,/usr/local/lib",
    "-Wl,--allow-shlib-undefined",
    "-lhiredis",
    "-lhiredis_ssl",
    "-lssl",
    "-lcrypto",
    "-lzlog"
  ]

@[default_target]
lean_lib RedisLean

lean_lib RedisArrow

lean_lib RedisExamples

lean_lib RedisTests

lean_lib RedisModel

lean_exe redis_examples where
  root := `RedisExamples.Main

lean_exe redis_tests where
  root := `RedisTests.TestRunner

/-- Authentication test (username / password, reconnect): `RedisTests/run-auth-test.sh`
    starts a throwaway redis-server and runs this. -/
lean_exe «auth-test» where
  root := `RedisTests.AuthMain

target hiredis_shim_o pkg : FilePath := do
  let hiredisDir := pkg.dir / "hiredis"
  let srcFile := hiredisDir / "shim.c"
  let oFile   := pkg.buildDir / "hiredis" / "shim.o"
  IO.FS.createDirAll oFile.parent.get!
  -- `shim.c` is a single translation unit that #includes every other .c in this
  -- directory, so all of them are build inputs. Without this the object file has
  -- no trace and edits to the wrappers never trigger a rebuild.
  let cFiles := (← hiredisDir.readDir).map (·.path)
    |>.filter (fun p => p.extension == some "c")
    |>.qsort (fun a b => a.toString < b.toString)
  let mut inputJobs : Array (Job FilePath) := #[]
  for path in cFiles do
    inputJobs := inputJobs.push (← inputTextFile path)
  let srcJob ← (Job.collectArray inputJobs).mapM fun _ => pure srcFile
  -- Path-dependent, deliberately kept out of the trace.
  let weakArgs := #["-I", (← getLeanIncludeDir).toString]
  -- Behaviour-affecting: a change here must force a rebuild.
  let traceArgs := #["-fPIC", "-O2", "-fno-stack-protector",
                     "-Wall", "-Wextra", "-Wno-unused-parameter",
                     "-Werror=return-type", "-Werror=implicit-function-declaration"]
  buildO oFile srcJob weakArgs traceArgs

@[default_target]
extern_lib libhiredis_shim pkg := do
  let obj ← hiredis_shim_o.fetch
  let name := nameToStaticLib "hiredis_shim"
  buildStaticLib (pkg.staticLibDir / name) #[obj]

require Cli from git
  "https://github.com/leanprover/lean4-cli.git" @ "v4.35.0"

require LSpec from git
  "https://github.com/argumentcomputer/LSpec.git" @ "main"

require zlogLean from git
  "git@github.com:marcellop71/zlog-lean.git" @ "v4.35.0"

require arrowLean from git
  "git@github.com:marcellop71/arrow-lean.git" @ "v4.35.0"

