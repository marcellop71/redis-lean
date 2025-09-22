import Examples.FFI.Del
import Examples.FFI.Get
import Examples.FFI.SAdd
import Examples.FFI.Set

import Examples.Monadic.Del
import Examples.Monadic.Get
import Examples.Monadic.SAdd
import Examples.Monadic.Set
import Examples.Monadic.ConnectionReuse

import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad
import Cli

open RedisLean
open Cli

-- Command-line options for selecting example types
inductive ExampleType where
  | All     : ExampleType
  | FFI     : ExampleType
  | Monadic : ExampleType
  deriving Repr, BEq

def runFFIExamples : IO Unit := do
  Log.info "Direct Foreign Function Interface to hiredis"
  try
    Log.info "📝 Running FFI Set Examples..."
    discard $ EIO.toIO (fun e => IO.userError (toString e)) FFISetExample.runAllExamples

    Log.info "📖 Running FFI Get Examples..."
    discard $ EIO.toIO (fun e => IO.userError (toString e)) FFIGetExample.runAllExamples

    Log.info "🗑️  Running FFI Del Examples..."
    discard $ EIO.toIO (fun e => IO.userError (toString e)) FFIDelExample.runAllExamples

    Log.info "📦 Running FFI SAdd Examples..."
    discard $ EIO.toIO (fun e => IO.userError (toString e)) FFISAddExample.runAllExamples

    Log.info "✅ All FFI Examples Completed Successfully!"
  catch e =>
    Log.error s!"❌ FFI Examples failed: {e}"

def runMonadicExamples : IO Unit := do
  Log.info "Higher-level monadic Redis client"
  let config : Config := {}  -- Using default config
  let redisConfig : RedisConfig := { config := config, enableMetrics := false }
  try
    -- Run Set examples
    Log.info "📝 Running Monadic Set Examples..."
    let setResult ← runRedisNoState redisConfig MonadicSetExample.runAllExamples
    match setResult with
    | Except.ok _ => Log.info "✅ Set examples completed successfully"
    | Except.error e => Log.error s!"❌ Set examples failed: {e}"

    -- Run Get examples
    Log.info "📖 Running Monadic Get Examples..."
    let getResult ← runRedisNoState redisConfig MonadicGetExample.runAllExamples
    match getResult with
    | Except.ok _ => Log.info "✅ Get examples completed successfully"
    | Except.error e => Log.error s!"❌ Get examples failed: {e}"

    -- Run Del examples
    Log.info "🗑️  Running Monadic Del Examples..."
    let delResult ← runRedisNoState redisConfig MonadicDelExample.runAllExamples
    match delResult with
    | Except.ok _ => Log.info "✅ Del examples completed successfully"
    | Except.error e => Log.error s!"❌ Del examples failed: {e}"

    -- Run SAdd examples
    Log.info "📦 Running Monadic SAdd Examples..."
    let saddResult ← runRedisNoState redisConfig MonadicSAddExample.runAllExamples
    match saddResult with
    | Except.ok _ => Log.info "✅ SAdd examples completed successfully"
    | Except.error e => Log.error s!"❌ SAdd examples failed: {e}"

    -- Run ConnectionReuse examples
    Log.info "🔗 Running Connection Reuse Examples..."
    ConnectionReuseExample.runWithConnectionReuse
    Log.info "✅ Connection Reuse examples completed successfully"

    Log.info "✅ All Monadic Examples Completed!"
  catch e =>
    Log.error s!"❌ Monadic Examples failed: {e}"

/-- Determine example type from parsed flags -/
def getExampleType (p : Parsed) : ExampleType :=
  if p.hasFlag "ffi" then
    ExampleType.FFI
  else if p.hasFlag "monadic" then
    ExampleType.Monadic
  else
    ExampleType.All

/-- Command handler function -/
def runExamplesCmd (p : Parsed) : IO UInt32 := do
  Log.info "🔥 Redis-Lean Examples Showcase"

  let exampleType := getExampleType p

  match exampleType with
  | ExampleType.FFI =>
    Log.info "Running FFI examples only..."
    runFFIExamples

  | ExampleType.Monadic =>
    Log.info "Running Monadic examples only..."
    runMonadicExamples

  | ExampleType.All =>
    Log.info "Running all examples (FFI + Monadic)..."

    runFFIExamples
    runMonadicExamples

  Log.info "🎉 Examples Showcase Completed!"

  return 0

/-- CLI command structure -/
def examplesCmd : Cmd := `[Cli|
  examples VIA runExamplesCmd; ["0.1.0"]
  "Redis-Lean Examples Showcase - demonstrates Redis operations using FFI and Monadic approaches"

  FLAGS:
    ffi;     "Run only FFI (Foreign Function Interface) examples"
    monadic; "Run only Monadic client examples"

  ARGS:
    ...args : String; "Additional arguments (currently unused)"
]/-- Main function using CLI library -/
def main (args : List String) : IO UInt32 :=
  examplesCmd.validate args
