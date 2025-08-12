import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace MonadicSetExample

open Redis

def ex0 : RedisM Unit := do
  Log.info "example: setting a key-value pair"

  let key1 := "key1"
  let value1 := "Alice"

  try
    Log.info s!"set {key1} → {value1}"
    set key1 value1
    Log.info s!"✓ success"
  catch e =>
    Log.error s!"✗ error {e}"

  try
    Log.info s!"setnx {key1} → {value1} [set if key does not exist]"
    setnx key1 value1
    Log.info s!"✓ success"
  catch e =>
    Log.error s!"✗ error {e}"

  try
    Log.info s!"setxx {key1} → {value1} [set if key does exist]"
    setxx key1 value1
    Log.info s!"✓ success"
  catch e =>
    Log.error s!"✗ error {e}"

def ex1 : RedisM Unit := do
  Log.info "example: typed set/get operations with different data types"

  -- Working with String type
  let stringKey := "typed:string"
  let stringValue := "Hello, Redis!"

  try
    Log.info s!"set {stringKey} → \"{stringValue}\" (String)"
    set stringKey stringValue
    let retrieved ← getAs String stringKey
    Log.info s!"✓ retrieved: \"{retrieved}\""
  catch e =>
    Log.error s!"✗ error with String: {e}"

  -- Working with Nat type
  let natKey := "typed:nat"
  let natValue : Nat := 42

  try
    Log.info s!"set {natKey} → {natValue} (Nat)"
    set natKey natValue
    let retrieved ← getAs Nat natKey
    Log.info s!"✓ retrieved: {retrieved}"
  catch e =>
    Log.error s!"✗ error with Nat: {e}"

  -- Working with Int type
  let intKey := "typed:int"
  let intValue : Int := -123

  try
    Log.info s!"set {intKey} → {intValue} (Int)"
    set intKey intValue
    let retrieved ← getAs Int intKey
    Log.info s!"✓ retrieved: {retrieved}"
  catch e =>
    Log.error s!"✗ error with Int: {e}"

  -- Working with Bool type
  let boolKey := "typed:bool"
  let boolValue : Bool := true

  try
    Log.info s!"set {boolKey} → {boolValue} (Bool)"
    set boolKey boolValue
    let retrieved ← getAs Bool boolKey
    Log.info s!"✓ retrieved: {retrieved}"
  catch e =>
    Log.error s!"✗ error with Bool: {e}"

  -- Demonstrating type mismatch handling
  try
    Log.info "attempting to retrieve Nat value as String (type mismatch test)"
    let _ ← getAs String natKey
    Log.info "✓ unexpected success - type conversion worked"
  catch e =>
    Log.info s!"✓ expected error with type mismatch: {e}"

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

end MonadicSetExample
