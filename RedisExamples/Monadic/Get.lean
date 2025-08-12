-- Examples/Monadic/Get.lean
-- Simple example demonstrating the use of the monadic Redis client for get operations

import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace MonadicGetExample

open Redis

def ex0 : RedisM Unit := do
  Log.info "example: basic get operations"

  let key1 := "get:name"
  let value1 := "Bob"

  let key2 := "get:score"
  let value2 := "42"

  -- Set up test data
  try
    Log.info s!"set {key1} → {value1}"
    set key1 value1
    Log.info "✓ success"
  catch e =>
    Log.error s!"✗ error setting {key1}: {e}"

  try
    Log.info s!"set {key2} → {value2}"
    set key2 value2
    Log.info "✓ success"
  catch e =>
    Log.error s!"✗ error setting {key2}: {e}"

  -- Get the values back
  try
    Log.info s!"get {key1}"
    let result ← getAs String key1
    Log.info s!"✓ retrieved: {result}"
  catch e =>
    Log.error s!"✗ error getting {key1}: {e}"

  try
    Log.info s!"get {key2}"
    let result ← getAs String key2
    Log.info s!"✓ retrieved: {result}"
  catch e =>
    Log.error s!"✗ error getting {key2}: {e}"

  -- Try to get a non-existent key
  try
    Log.info "get nonexistent:key"
    let _ ← getAs String "nonexistent:key"
    Log.info "✓ unexpected success"
  catch _ =>
    Log.info "✓ expected error (key not found)"

def ex1 : RedisM Unit := do
  Log.info "example: typed get operations"

  let stringKey := "typed:string"
  let natKey := "typed:nat"
  let boolKey := "typed:bool"

  -- Set up typed data
  try
    Log.info s!"set {stringKey} → \"Hello\" (String)"
    set stringKey "Hello"
    let result ← getAs String stringKey
    Log.info s!"✓ retrieved String: \"{result}\""
  catch e =>
    Log.error s!"✗ error with String: {e}"

  try
    Log.info s!"set {natKey} → 42 (Nat)"
    set natKey (42 : Nat)
    let result ← getAs Nat natKey
    Log.info s!"✓ retrieved Nat: {result}"
  catch e =>
    Log.error s!"✗ error with Nat: {e}"

  try
    Log.info s!"set {boolKey} → true (Bool)"
    set boolKey true
    let result ← getAs Bool boolKey
    Log.info s!"✓ retrieved Bool: {result}"
  catch e =>
    Log.error s!"✗ error with Bool: {e}"

  -- Test type mismatch
  try
    Log.info "get Nat value as String (type mismatch test)"
    let _ ← getAs String natKey
    Log.info "✓ unexpected success"
  catch e =>
    Log.info s!"✓ expected type error: {e}"

def runAllExamples : RedisM Unit := do
  ex0
  ex1

def main : IO Unit := do
  let config : Config := {}  -- Using default config
  let r : Read := { config := config, enableMetrics := false }
  let result ← runRedisNoState r runAllExamples
  match result with
  | Except.ok _ => Log.info "All examples completed successfully!"
  | Except.error e => Log.info s!"Error running examples: {e}"

end MonadicGetExample
