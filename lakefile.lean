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

target hiredis_shim_o pkg : FilePath := do
  let srcFile := pkg.dir / "hiredis" / "shim.c"
  let oFile   := pkg.buildDir / "hiredis" / "shim.o"
  IO.FS.createDirAll oFile.parent.get!
  let flags := #["-fPIC", "-O2", "-I", (← getLeanIncludeDir).toString, "-fno-stack-protector"]
  compileO oFile srcFile flags
  return .pure oFile

extern_lib libhiredis_shim pkg := do
  let obj ← hiredis_shim_o.fetch
  let name := nameToStaticLib "hiredis_shim"
  buildStaticLib (pkg.staticLibDir / name) #[obj]

require Cli from git
  "https://github.com/leanprover/lean4-cli.git" @ "v4.27.0"

require LSpec from git
  "https://github.com/argumentcomputer/LSpec.git" @ "main"

require zlogLean from git
  "git@github.com:marcellop71/zlog-lean.git" @ "main"

require arrowLean from git
  "git@github.com:marcellop71/arrow-lean.git" @ "main"

