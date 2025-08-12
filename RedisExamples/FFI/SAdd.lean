import RedisLean.FFI
import RedisLean.Log

namespace FFISAddExample

open Redis

def ex0 : EIO Error Unit := do
  Log.EIO.info "example: basic set operations"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let setKey := String.toUTF8 "fruits"

    try
      Log.EIO.info "sadd fruits apple"
      let count1 ← FFI.sadd ctx setKey (String.toUTF8 "apple")
      Log.EIO.info s!"✓ added {count1} member"
    catch e =>
      Log.EIO.error s!"✗ error: {e}"

    try
      Log.EIO.info "sadd fruits banana"
      let count2 ← FFI.sadd ctx setKey (String.toUTF8 "banana")
      Log.EIO.info s!"✓ added {count2} member"
    catch e =>
      Log.EIO.error s!"✗ error: {e}"

    try
      Log.EIO.info "sadd fruits apple [duplicate]"
      let count3 ← FFI.sadd ctx setKey (String.toUTF8 "apple")
      Log.EIO.info s!"✓ added {count3} member (should be 0)"
    catch e =>
      Log.EIO.error s!"✗ error: {e}"

    try
      Log.EIO.info "scard fruits"
      let setSize ← FFI.scard ctx setKey
      Log.EIO.info s!"✓ set size: {setSize}"
    catch e =>
      Log.EIO.error s!"✗ error: {e}"

def ex1 : EIO Error Unit := do
  Log.EIO.info "example: membership testing"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let setKey := String.toUTF8 "colors"

    try
      let _ ← FFI.sadd ctx setKey (String.toUTF8 "red")
      let _ ← FFI.sadd ctx setKey (String.toUTF8 "green")
      let _ ← FFI.sadd ctx setKey (String.toUTF8 "blue")
      Log.EIO.info "✓ set up test colors"
    catch e =>
      Log.EIO.error s!"✗ setup error: {e}"

    try
      Log.EIO.info "sismember colors red"
      let e ← FFI.sismember ctx setKey (String.toUTF8 "red")
      Log.EIO.info s!"✓ red exists: {e}"
    catch e =>
      Log.EIO.error s!"✗ error: {e}"

    try
      Log.EIO.info "sismember colors yellow"
      let e ← FFI.sismember ctx setKey (String.toUTF8 "yellow")
      Log.EIO.info s!"✓ yellow exists: {e}"
    catch e =>
      Log.EIO.error s!"✗ error: {e}"

    try
      Log.EIO.info "scard colors"
      let setSize ← FFI.scard ctx setKey
      Log.EIO.info s!"✓ final size: {setSize}"
    catch e =>
      Log.EIO.error s!"✗ error: {e}"

def ex2 : EIO Error Unit := do
  Log.EIO.info "example: multiple sets"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let teamA := String.toUTF8 "team:a"
    let teamB := String.toUTF8 "team:b"

    try
      let _ ← FFI.sadd ctx teamA (String.toUTF8 "alice")
      let _ ← FFI.sadd ctx teamA (String.toUTF8 "bob")
      let _ ← FFI.sadd ctx teamA (String.toUTF8 "charlie")
      let sizeA ← FFI.scard ctx teamA
      Log.EIO.info s!"✓ team A: {sizeA} members"
    catch e =>
      Log.EIO.error s!"✗ team A error: {e}"

    try
      let _ ← FFI.sadd ctx teamB (String.toUTF8 "bob")
      let _ ← FFI.sadd ctx teamB (String.toUTF8 "diana")
      let _ ← FFI.sadd ctx teamB (String.toUTF8 "eve")
      let sizeB ← FFI.scard ctx teamB
      Log.EIO.info s!"✓ team B: {sizeB} members"
    catch e =>
      Log.EIO.error s!"✗ team B error: {e}"

    try
      Log.EIO.info "checking bob membership"
      let inA ← FFI.sismember ctx teamA (String.toUTF8 "bob")
      let inB ← FFI.sismember ctx teamB (String.toUTF8 "bob")
      Log.EIO.info s!"✓ bob in team A: {inA}, team B: {inB}"
    catch e =>
      Log.EIO.error s!"✗ membership error: {e}"

def runAllExamples : EIO Error Unit := do
  ex0
  ex1
  ex2

def main : IO Unit := do
  discard $ EIO.toIO (fun e => IO.userError (toString e)) runAllExamples

end FFISAddExample
