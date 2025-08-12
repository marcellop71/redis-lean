import RedisExamples.FFI.Del
import RedisExamples.FFI.Get
import RedisExamples.FFI.SAdd
import RedisExamples.FFI.Set

import RedisExamples.Monadic.Del
import RedisExamples.Monadic.Get
import RedisExamples.Monadic.SAdd
import RedisExamples.Monadic.Set
import RedisExamples.Monadic.ConnectionReuse

import RedisExamples.Mathlib.TacticCache
import RedisExamples.Mathlib.TheoremSearch
import RedisExamples.Mathlib.Declaration
import RedisExamples.Mathlib.InstanceCache
import RedisExamples.Mathlib.ProofState
import RedisExamples.Mathlib.DistProof

import RedisExamples.Features.TypedKeys
import RedisExamples.Features.Caching
import RedisExamples.Features.Pool
import RedisExamples.Features.Metrics
import RedisExamples.Features.Lists
import RedisExamples.Features.SortedSets
import RedisExamples.Features.Hashes
import RedisExamples.Features.HyperLogLog
import RedisExamples.Features.Bitmaps
import RedisExamples.Features.Streams
import RedisExamples.Features.PubSub
import RedisExamples.Features.KeyOperations

import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad
import Cli

open Redis
open Cli

-- Command-line options for selecting example types
inductive ExampleType where
  | All      : ExampleType
  | FFI      : ExampleType
  | Monadic  : ExampleType
  | Mathlib  : ExampleType
  | Features : ExampleType
  deriving Repr, BEq

def runFFIExamples : IO Unit := do
  Log.info "Direct Foreign Function Interface to hiredis"
  try
    Log.info "Running FFI Set Examples..."
    discard $ EIO.toIO (fun e => IO.userError (toString e)) FFISetExample.runAllExamples

    Log.info "Running FFI Get Examples..."
    discard $ EIO.toIO (fun e => IO.userError (toString e)) FFIGetExample.runAllExamples

    Log.info "Running FFI Del Examples..."
    discard $ EIO.toIO (fun e => IO.userError (toString e)) FFIDelExample.runAllExamples

    Log.info "Running FFI SAdd Examples..."
    discard $ EIO.toIO (fun e => IO.userError (toString e)) FFISAddExample.runAllExamples

    Log.info "All FFI Examples Completed Successfully!"
  catch e =>
    Log.error s!"FFI Examples failed: {e}"

def runMonadicExamples : IO Unit := do
  Log.info "Higher-level monadic Redis client"
  let config : Config := {}  -- Using default config
  let r : Read := { config := config, enableMetrics := false }
  try
    -- Run Set examples
    Log.info "Running Monadic Set Examples..."
    let setResult ← runRedisNoState r MonadicSetExample.runAllExamples
    match setResult with
    | Except.ok _ => Log.info "Set examples completed successfully"
    | Except.error e => Log.error s!"Set examples failed: {e}"

    -- Run Get examples
    Log.info "Running Monadic Get Examples..."
    let getResult ← runRedisNoState r MonadicGetExample.runAllExamples
    match getResult with
    | Except.ok _ => Log.info "Get examples completed successfully"
    | Except.error e => Log.error s!"Get examples failed: {e}"

    -- Run Del examples
    Log.info "Running Monadic Del Examples..."
    let delResult ← runRedisNoState r MonadicDelExample.runAllExamples
    match delResult with
    | Except.ok _ => Log.info "Del examples completed successfully"
    | Except.error e => Log.error s!"Del examples failed: {e}"

    -- Run SAdd examples
    Log.info "Running Monadic SAdd Examples..."
    let saddResult ← runRedisNoState r MonadicSAddExample.runAllExamples
    match saddResult with
    | Except.ok _ => Log.info "SAdd examples completed successfully"
    | Except.error e => Log.error s!"SAdd examples failed: {e}"

    -- Run ConnectionReuse examples
    Log.info "Running Connection Reuse Examples..."
    ConnectionReuseExample.runWithConnectionReuse
    Log.info "Connection Reuse examples completed successfully"

    Log.info "All Monadic Examples Completed!"
  catch e =>
    Log.error s!"Monadic Examples failed: {e}"

def runMathlibExamples : IO Unit := do
  Log.info "Mathlib Integration Features"
  let config : Config := {}
  let r : Read := { config := config, enableMetrics := false }
  try
    -- Run Tactic Cache examples
    Log.info "Running Tactic Cache Examples..."
    let tacticResult ← runRedisNoState r MathlibTacticCacheExample.runAllExamples
    match tacticResult with
    | Except.ok _ => Log.info "Tactic Cache examples completed successfully"
    | Except.error e => Log.error s!"Tactic Cache examples failed: {e}"

    -- Run Theorem Search examples
    Log.info "Running Theorem Search Examples..."
    let theoremResult ← runRedisNoState r MathlibTheoremSearchExample.runAllExamples
    match theoremResult with
    | Except.ok _ => Log.info "Theorem Search examples completed successfully"
    | Except.error e => Log.error s!"Theorem Search examples failed: {e}"

    -- Run Declaration examples
    Log.info "Running Declaration Storage Examples..."
    let declResult ← runRedisNoState r MathlibDeclarationExample.runAllExamples
    match declResult with
    | Except.ok _ => Log.info "Declaration Storage examples completed successfully"
    | Except.error e => Log.error s!"Declaration Storage examples failed: {e}"

    -- Run Instance Cache examples
    Log.info "Running Instance Cache Examples..."
    let instanceResult ← runRedisNoState r MathlibInstanceCacheExample.runAllExamples
    match instanceResult with
    | Except.ok _ => Log.info "Instance Cache examples completed successfully"
    | Except.error e => Log.error s!"Instance Cache examples failed: {e}"

    -- Run Proof State examples
    Log.info "Running Proof State Examples..."
    let proofResult ← runRedisNoState r MathlibProofStateExample.runAllExamples
    match proofResult with
    | Except.ok _ => Log.info "Proof State examples completed successfully"
    | Except.error e => Log.error s!"Proof State examples failed: {e}"

    -- Run Distributed Proof examples
    Log.info "Running Distributed Proof Checking Examples..."
    let distResult ← runRedisNoState r MathlibDistProofExample.runAllExamples
    match distResult with
    | Except.ok _ => Log.info "Distributed Proof Checking examples completed successfully"
    | Except.error e => Log.error s!"Distributed Proof Checking examples failed: {e}"

    Log.info "All Mathlib Examples Completed!"
  catch e =>
    Log.error s!"Mathlib Examples failed: {e}"

def runFeaturesExamples : IO Unit := do
  Log.info "Redis-Lean Features Showcase"
  let config : Config := {}
  let r : Read := { config := config, enableMetrics := false }
  try
    -- Run TypedKeys examples
    Log.info "Running TypedKeys Examples..."
    let typedKeysResult ← runRedisNoState r FeaturesTypedKeysExample.runAllExamples
    match typedKeysResult with
    | Except.ok _ => Log.info "TypedKeys examples completed successfully"
    | Except.error e => Log.error s!"TypedKeys examples failed: {e}"

    -- Run Caching examples
    Log.info "Running Caching Pattern Examples..."
    let cachingResult ← runRedisNoState r FeaturesCachingExample.runAllExamples
    match cachingResult with
    | Except.ok _ => Log.info "Caching examples completed successfully"
    | Except.error e => Log.error s!"Caching examples failed: {e}"

    -- Run Pool examples (IO-based, not RedisM)
    Log.info "Running Connection Pool Examples..."
    FeaturesPoolExample.runAllExamples

    -- Run Metrics examples (IO-based)
    Log.info "Running Metrics Examples..."
    FeaturesMetricsExample.runAllExamples

    -- Run Lists examples
    Log.info "Running Lists Examples..."
    let listsResult ← runRedisNoState r FeaturesListsExample.runAllExamples
    match listsResult with
    | Except.ok _ => Log.info "Lists examples completed successfully"
    | Except.error e => Log.error s!"Lists examples failed: {e}"

    -- Run Sorted Sets examples
    Log.info "Running Sorted Sets Examples..."
    let sortedSetsResult ← runRedisNoState r FeaturesSortedSetsExample.runAllExamples
    match sortedSetsResult with
    | Except.ok _ => Log.info "Sorted Sets examples completed successfully"
    | Except.error e => Log.error s!"Sorted Sets examples failed: {e}"

    -- Run Hashes examples
    Log.info "Running Hashes Examples..."
    let hashesResult ← runRedisNoState r FeaturesHashesExample.runAllExamples
    match hashesResult with
    | Except.ok _ => Log.info "Hashes examples completed successfully"
    | Except.error e => Log.error s!"Hashes examples failed: {e}"

    -- Run HyperLogLog examples
    Log.info "Running HyperLogLog Examples..."
    let hllResult ← runRedisNoState r FeaturesHyperLogLogExample.runAllExamples
    match hllResult with
    | Except.ok _ => Log.info "HyperLogLog examples completed successfully"
    | Except.error e => Log.error s!"HyperLogLog examples failed: {e}"

    -- Run Bitmaps examples
    Log.info "Running Bitmaps Examples..."
    let bitmapsResult ← runRedisNoState r FeaturesBitmapsExample.runAllExamples
    match bitmapsResult with
    | Except.ok _ => Log.info "Bitmaps examples completed successfully"
    | Except.error e => Log.error s!"Bitmaps examples failed: {e}"

    -- Run Streams examples
    Log.info "Running Streams Examples..."
    let streamsResult ← runRedisNoState r FeaturesStreamsExample.runAllExamples
    match streamsResult with
    | Except.ok _ => Log.info "Streams examples completed successfully"
    | Except.error e => Log.error s!"Streams examples failed: {e}"

    -- Run PubSub examples
    Log.info "Running Pub/Sub Examples..."
    let pubsubResult ← runRedisNoState r FeaturesPubSubExample.runAllExamples
    match pubsubResult with
    | Except.ok _ => Log.info "Pub/Sub examples completed successfully"
    | Except.error e => Log.error s!"Pub/Sub examples failed: {e}"

    -- Run Key Operations examples
    Log.info "Running Key Operations Examples..."
    let keyOpsResult ← runRedisNoState r FeaturesKeyOperationsExample.runAllExamples
    match keyOpsResult with
    | Except.ok _ => Log.info "Key Operations examples completed successfully"
    | Except.error e => Log.error s!"Key Operations examples failed: {e}"

    Log.info "All Features Examples Completed!"
  catch e =>
    Log.error s!"Features Examples failed: {e}"

/-- Determine example type from parsed flags -/
def getExampleType (p : Parsed) : ExampleType :=
  if p.hasFlag "ffi" then
    ExampleType.FFI
  else if p.hasFlag "monadic" then
    ExampleType.Monadic
  else if p.hasFlag "mathlib" then
    ExampleType.Mathlib
  else if p.hasFlag "features" then
    ExampleType.Features
  else
    ExampleType.All

/-- Command handler function -/
def runExamplesCmd (p : Parsed) : IO UInt32 := do
  -- Initialize zlog
  let logOk ← Log.initZlog "config/zlog.conf" "redis"
  unless logOk do
    IO.eprintln "Failed to initialize zlog from 'config/zlog.conf'"
    return 1

  Log.info "Redis-Lean Examples Showcase"

  let exampleType := getExampleType p

  match exampleType with
  | ExampleType.FFI =>
    Log.info "Running FFI examples only..."
    runFFIExamples

  | ExampleType.Monadic =>
    Log.info "Running Monadic examples only..."
    runMonadicExamples

  | ExampleType.Mathlib =>
    Log.info "Running Mathlib examples only..."
    runMathlibExamples

  | ExampleType.Features =>
    Log.info "Running Features examples only..."
    runFeaturesExamples

  | ExampleType.All =>
    Log.info "Running all examples (FFI + Monadic + Mathlib + Features)..."
    runFFIExamples
    runMonadicExamples
    runMathlibExamples
    runFeaturesExamples

  Log.info "Examples Showcase Completed!"

  -- Cleanup zlog
  Log.finiZlog

  return 0

/-- CLI command structure -/
def examplesCmd : Cmd := `[Cli|
  examples VIA runExamplesCmd; ["0.1.0"]
  "Redis-Lean Examples Showcase - demonstrates Redis operations using FFI, Monadic, and Mathlib approaches"

  FLAGS:
    ffi;      "Run only FFI (Foreign Function Interface) examples"
    monadic;  "Run only Monadic client examples"
    mathlib;  "Run only Mathlib integration examples"
    features; "Run only Features examples (TypedKeys, Caching, Pool, Metrics, Data Structures)"

  ARGS:
    ...args : String; "Additional arguments (currently unused)"
]

/-- Main function using CLI library -/
def main (args : List String) : IO UInt32 :=
  examplesCmd.validate args
