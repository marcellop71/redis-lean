-- Examples/FFI/Get.lean
-- Simple example demonstrating the use of the FFI get operations

import RedisLean.FFI
import RedisLean.Log

namespace FFIGetExample

open Redis

def ex0 : EIO Error Unit := do
  Log.EIO.info "example: basic set/get operations"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let key := String.toUTF8 "message"
    let value := String.toUTF8 "Hello, FFI!"

    try
      Log.EIO.info "set message → Hello, FFI!"
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

def ex1 : EIO Error Unit := do
  Log.EIO.info "example: multiple key operations"

  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let testData := [
      ("name", "Alice"),
      ("age", "25"),
      ("city", "Boston")
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

    -- Retrieve all data
    try
      for (keyStr, _) in testData do
        let key := String.toUTF8 keyStr
        let result ← FFI.get ctx key
        let retrieved := String.fromUTF8! result
        Log.EIO.info s!"✓ {keyStr}: {retrieved}"
    catch e =>
      Log.EIO.error s!"✗ get error: {e}"

def ex2 : EIO Error Unit := do
  Log.EIO.info "example: non-existent key handling"

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
      Log.EIO.info "get existing"
      let result ← FFI.get ctx existingKey
      let retrieved := String.fromUTF8! result
      Log.EIO.info s!"✓ retrieved: {retrieved}"
    catch e =>
      Log.EIO.error s!"✗ get error: {e}"

    try
      Log.EIO.info "get missing"
      let result ← FFI.get ctx missingKey
      let retrieved := String.fromUTF8! result
      Log.EIO.info s!"✓ unexpected: {retrieved}"
    catch e =>
      Log.EIO.info s!"✓ expected error for missing key: {e}"

def runAllExamples : EIO Error Unit := do
  ex0
  ex1
  ex2

def main : IO Unit := do
  discard $ EIO.toIO (fun e => IO.userError (toString e)) runAllExamples

end FFIGetExample
