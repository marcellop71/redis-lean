import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace MonadicDelExample

open Redis

def ex0 : RedisM Unit := do
  Log.info "example: basic delete operations"

  let key1 := "del:single"
  let value1 := "Alice"

  try
    Log.info s!"set {key1} → {value1}"
    set key1 value1
    Log.info "✓ key set"
  catch e =>
    Log.error s!"✗ error setting key: {e}"

  try
    Log.info s!"del {key1}"
    let deletedCount ← del [key1]
    Log.info s!"✓ deleted {deletedCount} key"
  catch e =>
    Log.error s!"✗ error deleting key: {e}"

def ex1 : RedisM Unit := do
  Log.info "example: multiple key deletion"

  let keys := ["del:multi:1", "del:multi:2", "del:multi:3"]
  let values := ["Alice", "Bob", "Charlie"]

  try
    Log.info "setting multiple keys"
    for (key, value) in keys.zip values do
      set key value
    Log.info s!"✓ set {keys.length} keys"
  catch e =>
    Log.error s!"✗ error setting keys: {e}"

  try
    Log.info s!"del {keys}"
    let deletedCount ← del keys
    Log.info s!"✓ deleted {deletedCount} keys"
  catch e =>
    Log.error s!"✗ error deleting keys: {e}"

def ex2 : RedisM Unit := do
  Log.info "example: deleting non-existent keys"

  let nonExistentKeys := ["del:missing:1", "del:missing:2"]

  try
    Log.info s!"del {nonExistentKeys} (non-existent)"
    let deletedCount ← del nonExistentKeys
    Log.info s!"✓ deleted {deletedCount} keys (expected 0)"
  catch e =>
    Log.error s!"✗ error deleting non-existent keys: {e}"

def ex3 : RedisM Unit := do
  Log.info "example: mixed existent and non-existent keys"

  let existingKey := "del:mixed:real"
  let existingValue := "I exist"
  let mixedKeys := [existingKey, "del:mixed:fake1", "del:mixed:fake2"]

  try
    Log.info s!"set {existingKey} → {existingValue}"
    set existingKey existingValue
    Log.info "✓ set real key"
  catch e =>
    Log.error s!"✗ error setting real key: {e}"

  try
    Log.info s!"del {mixedKeys} (mixed)"
    let deletedCount ← del mixedKeys
    Log.info s!"✓ deleted {deletedCount} keys (expected 1)"
  catch e =>
    Log.error s!"✗ error deleting mixed keys: {e}"

def runAllExamples : RedisM Unit := do
  ex0
  ex1
  ex2
  ex3

def main : IO Unit := do
  let config : Config := {}  -- Using default config
  let r : Read := { config := config, enableMetrics := false }
  let result ← runRedisNoState r runAllExamples
  match result with
  | Except.ok _ => Log.info "All examples completed successfully!"
  | Except.error e => Log.info s!"Error running examples: {e}"

end MonadicDelExample
