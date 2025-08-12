-- Examples/Monadic/SAdd.lean
-- Simple example demonstrating the use of the monadic Redis client for set operations (Redis sets)

import RedisLean.Ops
import RedisLean.Log

open RedisLean

namespace MonadicSAddExample

def ex0 : Redis Unit := do
  Log.info "example: basic set operations"

  let setKey := "fruits"

  try
    Log.info s!"sadd {setKey} apple"
    let count1 ← sadd setKey "apple"
    Log.info s!"✓ added {count1} member"
  catch e =>
    Log.error s!"✗ error: {e}"

  try
    Log.info s!"sadd {setKey} banana"
    let count2 ← sadd setKey "banana"
    Log.info s!"✓ added {count2} member"
  catch e =>
    Log.error s!"✗ error: {e}"

  try
    Log.info s!"sadd {setKey} apple [duplicate]"
    let count3 ← sadd setKey "apple"
    Log.info s!"✓ added {count3} member (should be 0)"
  catch e =>
    Log.error s!"✗ error: {e}"

  try
    Log.info s!"scard {setKey}"
    let setSize ← scard setKey
    Log.info s!"✓ set size: {setSize}"
  catch e =>
    Log.error s!"✗ error: {e}"

def ex1 : Redis Unit := do
  Log.info "example: membership testing"

  let setKey := "colors"

  -- Set up test data
  try
    let _ ← sadd setKey "red"
    let _ ← sadd setKey "green"
    let _ ← sadd setKey "blue"
    Log.info "✓ set up test colors"
  catch e =>
    Log.error s!"✗ setup error: {e}"

  try
    Log.info s!"sismember {setKey} red"
    let e ← sismember setKey "red"
    Log.info s!"✓ red exists: {e}"
  catch e =>
    Log.error s!"✗ error: {e}"

  try
    Log.info s!"sismember {setKey} yellow"
    let e ← sismember setKey "yellow"
    Log.info s!"✓ yellow exists: {e}"
  catch e =>
    Log.error s!"✗ error: {e}"

  try
    Log.info s!"scard {setKey}"
    let setSize ← scard setKey
    Log.info s!"✓ final size: {setSize}"
  catch e =>
    Log.error s!"✗ error: {e}"

def ex2 : Redis Unit := do
  Log.info "example: multiple sets"

  let teamA := "team:a"
  let teamB := "team:b"

  -- Set up team A
  try
    let _ ← sadd teamA "alice"
    let _ ← sadd teamA "bob"
    let _ ← sadd teamA "charlie"
    let sizeA ← scard teamA
    Log.info s!"✓ team A: {sizeA} members"
  catch e =>
    Log.error s!"✗ team A error: {e}"

  -- Set up team B
  try
    let _ ← sadd teamB "bob"
    let _ ← sadd teamB "diana"
    let _ ← sadd teamB "eve"
    let sizeB ← scard teamB
    Log.info s!"✓ team B: {sizeB} members"
  catch e =>
    Log.error s!"✗ team B error: {e}"

  -- Check overlap
  try
    Log.info "checking bob membership"
    let inA ← sismember teamA "bob"
    let inB ← sismember teamB "bob"
    Log.info s!"✓ bob in team A: {inA}, team B: {inB}"
  catch e =>
    Log.error s!"✗ membership error: {e}"

def runAllExamples : Redis Unit := do
  ex0
  ex1
  ex2

def main : IO Unit := do
  let result ← runRedis {} runAllExamples
  match result with
  | Except.ok _ => Log.info "All examples completed successfully!"
  | Except.error e => Log.info s!"Error running examples: {e}"

end MonadicSAddExample
