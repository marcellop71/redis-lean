-- Examples/FFI/Set.lean
-- Simple example demonstrating the use of the FFI set operations

import RedisLean.FFI
import RedisLean.Log

namespace FFISetExample

open Redis

def ex0 : EIO Error Unit := do
  Log.EIO.info "example: setting a key-value pair"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let key1 := String.toUTF8 "key1"
    let value1 := String.toUTF8 "Alice"

    try
      Log.EIO.info s!"set key1 → Alice"
      FFI.set ctx key1 value1
      Log.EIO.info s!"✓ success"
    catch e =>
      Log.EIO.error s!"✗ error {e}"

    try
      Log.EIO.info s!"set key1 → Alice [NX - set if not exists]"
      FFI.set ctx key1 value1 FFI.SetExistsOption.nx
      Log.EIO.info s!"✓ success"
    catch e =>
      Log.EIO.error s!"✗ error {e}"

    try
      Log.EIO.info s!"set key1 → Alice [XX - set if exists]"
      FFI.set ctx key1 value1 FFI.SetExistsOption.xx
      Log.EIO.info s!"✓ success"
    catch e =>
      Log.EIO.error s!"✗ error {e}"

def ex1 : EIO Error Unit := do
  Log.EIO.info "example: basic set/get operations"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let key := String.toUTF8 "message"
    let value := String.toUTF8 "Hello, Redis!"

    try
      Log.EIO.info "set message → Hello, Redis!"
      FFI.set ctx key value
      Log.EIO.info "✓ set complete"
    catch e =>
      Log.EIO.error s!"✗ set error: {e}"

    try
      Log.EIO.info "get message"
      let result ← FFI.get ctx key
      let retrieved := String.fromUTF8! result
      Log.EIO.info s!"✓ retrieved: {retrieved}"
    catch e =>
      Log.EIO.error s!"✗ get error: {e}"

def ex2 : EIO Error Unit := do
  Log.EIO.info "example: multiple key operations"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let keys := [
      ("name", "Bob"),
      ("age", "30"),
      ("city", "New York")
    ]

    -- Set multiple keys
    try
      for (keyStr, valueStr) in keys do
        let key := String.toUTF8 keyStr
        let value := String.toUTF8 valueStr
        FFI.set ctx key value
      Log.EIO.info "✓ set multiple keys"
    catch e =>
      Log.EIO.error s!"✗ set error: {e}"

    -- Get multiple keys
    try
      for (keyStr, _) in keys do
        let key := String.toUTF8 keyStr
        let result ← FFI.get ctx key
        let retrieved := String.fromUTF8! result
        Log.EIO.info s!"✓ {keyStr}: {retrieved}"
    catch e =>
      Log.EIO.error s!"✗ get error: {e}"

def runAllExamples : EIO Error Unit := do
  ex0
  ex1
  ex2

def main : IO Unit := do
  discard $ EIO.toIO (fun e => IO.userError (toString e)) runAllExamples

end FFISetExample
