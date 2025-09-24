-- Examples/FFI/Del.lean
-- Simple example demonstrating the use of the FFI del operations

import RedisLean.FFI
import RedisLean.Log

namespace FFIDelExample

open Redis

def ex0 : EIO Error Unit := do
  Log.EIO.info "example: basic set/del operations"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let key := String.toUTF8 "temp"
    let value := String.toUTF8 "temporary data"

    try
      Log.EIO.info "set temp → temporary data"
      FFI.set ctx key value
      Log.EIO.info "✓ set complete"
    catch e =>
      Log.EIO.error s!"✗ set error: {e}"

    try
      Log.EIO.info "del temp"
      let deleted ← FFI.del ctx [key]
      Log.EIO.info s!"✓ deleted {deleted} key"
    catch e =>
      Log.EIO.error s!"✗ del error: {e}"

    try
      Log.EIO.info "del temp [already deleted]"
      let deleted ← FFI.del ctx [key]
      Log.EIO.info s!"✓ deleted {deleted} key (should be 0)"
    catch e =>
      Log.EIO.error s!"✗ del error: {e}"

def ex1 : EIO Error Unit := do
  Log.EIO.info "example: multiple key deletion"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let testData := [
      ("user:1", "Alice"),
      ("user:2", "Bob"),
      ("user:3", "Charlie")
    ]

    -- Set up test data
    try
      for (keyStr, valueStr) in testData do
        let key := String.toUTF8 keyStr
        let value := String.toUTF8 valueStr
        FFI.set ctx key value
      Log.EIO.info "✓ set up test data"
    catch e =>
      Log.EIO.error s!"✗ setup error: {e}"

    -- Delete all keys at once
    try
      let keysToDelete := testData.map (fun (keyStr, _) => String.toUTF8 keyStr)
      let deleted ← FFI.del ctx keysToDelete
      Log.EIO.info s!"✓ deleted {deleted} keys"
    catch e =>
      Log.EIO.error s!"✗ delete error: {e}"

def ex2 : EIO Error Unit := do
  Log.EIO.info "example: existence checking with del"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let existingKey := String.toUTF8 "existing"
    let existingValue := String.toUTF8 "I exist"
    let missingKey := String.toUTF8 "missing"

    try
      Log.EIO.info "set existing → I exist"
      FFI.set ctx existingKey existingValue
      Log.EIO.info "✓ set complete"
    catch e =>
      Log.EIO.error s!"✗ set error: {e}"

    try
      Log.EIO.info "exists existing"
      let exists1 ← FFI.existsKey ctx existingKey
      Log.EIO.info s!"✓ existing key exists: {exists1}"
    catch e =>
      Log.EIO.error s!"✗ exists error: {e}"

    try
      Log.EIO.info "exists missing"
      let exists2 ← FFI.existsKey ctx missingKey
      Log.EIO.info s!"✓ missing key exists: {exists2}"
    catch e =>
      Log.EIO.error s!"✗ exists error: {e}"

    try
      Log.EIO.info "del existing missing"
      let deleted ← FFI.del ctx [existingKey, missingKey]
      Log.EIO.info s!"✓ deleted {deleted} keys (should be 1)"
    catch e =>
      Log.EIO.error s!"✗ del error: {e}"

def runAllExamples : EIO Error Unit := do
  ex0
  ex1
  ex2

def main : IO Unit := do
  discard $ EIO.toIO (fun e => IO.userError (toString e)) runAllExamples

end FFIDelExample
