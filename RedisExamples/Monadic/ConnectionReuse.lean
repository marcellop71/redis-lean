-- Examples/Monadic/ConnectionReuse.lean
-- Example demonstrating connection reuse with initWithConnect

import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace ConnectionReuseExample

open Redis

-- Helper function to cleanup connection
def cleanup (stateRef : StateRef) : IO Unit := do
  let state ← stateRef.get
  discard $ EIO.toIO (fun _ => IO.userError "Failed to free Redis context") (FFI.free state.ctx)

-- First operation: Set some keys
def setOperations : RedisM Unit := do
  Log.info "🔧 Setting keys..."
  set "user:1:name" "Alice"
  set "user:1:email" "alice@example.com"
  set "user:1:age" "25"
  Log.info "✅ Set operations completed"

-- Second operation: Get the keys we just set
def getOperations : RedisM Unit := do
  Log.info "📖 Getting keys..."

  let name ← getAs String "user:1:name"
  Log.info s!"Name: {name}"

  let email ← getAs String "user:1:email"
  Log.info s!"Email: {email}"

  let age ← getAs String "user:1:age"
  Log.info s!"Age: {age}"

  Log.info "✅ Get operations completed"

-- Third operation: Check if keys exist and get metrics
def existsAndMetrics : RedisM Unit := do
  Log.info "🔍 Checking key existence..."

  let nameExists ← existsKey "user:1:name"
  let emailExists ← existsKey "user:1:email"
  let fakeExists ← existsKey "user:1:nonexistent"

  Log.info s!"user:1:name exists: {nameExists}"
  Log.info s!"user:1:email exists: {emailExists}"
  Log.info s!"user:1:nonexistent exists: {fakeExists}"

  -- Get current metrics
  -- let metrics ← getMetrics
  Log.info "📊 Current metrics recorded during operations"

  Log.info "✅ Exists and metrics operations completed"

-- Fourth operation: Clean up the test data
def cleanupOperations : RedisM Unit := do
  Log.info "🗑️ Cleaning up test data..."

  let deletedCount ← del ["user:1:name", "user:1:email", "user:1:age"]
  Log.info s!"Deleted {deletedCount} keys"

  Log.info "✅ Cleanup operations completed"

-- Main example function using connection reuse
def runWithConnectionReuse : IO Unit := do
  Log.info "🔗 Connection Reuse Example"
  Log.info "This example demonstrates creating a connection once and reusing it for multiple operations"

  -- Create configuration with metrics enabled
  let config : Config := { host := "127.0.0.1", port := 6379 }
  let r : Read := { config := config, enableMetrics := true }

  -- Initialize connection
  Log.info "🚀 Initializing Redis connection..."
  let connectionResult ← init r

  match connectionResult with
  | Except.error e =>
    Log.error s!"❌ Failed to connect to Redis: {e}"
  | Except.ok stateRef =>
    try
      Log.info "✅ Successfully connected to Redis"

      -- Operation 1: Set data
      Log.info "\n--- Operation 1: Setting Data ---"
      let result1 ← runRedis r stateRef setOperations
      match result1 with
      | Except.ok _ => Log.info "✅ Set operations successful"
      | Except.error e => Log.error s!"❌ Set operations failed: {e}"

      -- Operation 2: Get data (reusing same connection)
      Log.info "\n--- Operation 2: Getting Data ---"
      let result2 ← runRedis r stateRef getOperations
      match result2 with
      | Except.ok _ => Log.info "✅ Get operations successful"
      | Except.error e => Log.error s!"❌ Get operations failed: {e}"

      -- Operation 3: Check existence and metrics (reusing same connection)
      Log.info "\n--- Operation 3: Checking Existence & Metrics ---"
      let result3 ← runRedis r stateRef existsAndMetrics
      match result3 with
      | Except.ok _ => Log.info "✅ Exists and metrics operations successful"
      | Except.error e => Log.error s!"❌ Exists and metrics operations failed: {e}"

      -- Operation 4: Cleanup (reusing same connection)
      Log.info "\n--- Operation 4: Cleanup ---"
      let result4 ← runRedis r stateRef cleanupOperations
      match result4 with
      | Except.ok _ => Log.info "✅ Cleanup operations successful"
      | Except.error e => Log.error s!"❌ Cleanup operations failed: {e}"

      -- Get final metrics from the connection
      Log.info "\n--- Final Metrics ---"
      -- let finalState ← stateRef.get
      Log.info "📊 All operations completed using the same Redis connection"
      Log.info "🔗 Connection was reused across multiple operation sets"

    finally
      -- Always cleanup the connection
      Log.info "🧹 Cleaning up Redis connection..."
      cleanup stateRef

-- Alternative example showing error handling with connection reuse
def runWithErrorHandling : IO Unit := do
  Log.info "\n🛡️ Connection Reuse with Error Handling Example"

  let config : Config := { host := "127.0.0.1", port := 6379 }
  let r : Read := { config := config, enableMetrics := true }

  let connectionResult ← init r

  match connectionResult with
  | Except.error e =>
    Log.error s!"❌ Connection failed: {e}"
  | Except.ok stateRef =>
    try
      -- Demonstrate that even if one operation fails, we can continue using the connection
      let operations := [
        ("Set operations", setOperations),
        ("Get operations", getOperations),
        ("Exists check", existsAndMetrics)
      ]

      for (opName, operation) in operations do
        Log.info s!"🔄 Running {opName}..."
        let result ← runRedis r stateRef operation
        match result with
        | Except.ok _ => Log.info s!"✅ {opName} completed successfully"
        | Except.error e =>
          Log.error s!"❌ {opName} failed: {e}"
          Log.info "🔗 But connection remains open for other operations"

    finally
      cleanup stateRef

def main : IO Unit := do
  Log.info "🏁 Starting Connection Reuse Examples"

  -- Run the main example
  runWithConnectionReuse

  IO.sleep 1000  -- Small delay between examples

  -- Run the error handling example
  runWithErrorHandling

  Log.info "🎉 All Connection Reuse Examples Completed!"

end ConnectionReuseExample
