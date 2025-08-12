import RedisLean.FFI
import RedisLean.Log

namespace FeaturesReconnectionExample

open Redis

/-!
# Reconnection Examples

Demonstrates connection health monitoring and reconnection:
- Checking connection status
- Reconnecting after disconnection
- Error state management
- Building resilient connections

These patterns help build fault-tolerant Redis clients that
can recover from network issues.
-/

/-- Example: Check connection status -/
def exCheckConnection (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Check connection status"

  -- Check if connected
  let connected ← FFI.isConnected ctx
  Log.EIO.info s!"  Is connected: {connected}"

  -- Get file descriptor
  let fd ← FFI.getFd ctx
  Log.EIO.info s!"  File descriptor: {fd}"

  -- Check for errors
  let errorOpt ← FFI.getError ctx
  match errorOpt with
  | some err => Log.EIO.info s!"  Error state: {err}"
  | none => Log.EIO.info "  No errors"

/-- Example: Basic reconnection -/
def exBasicReconnect : IO Unit := do
  Log.info "Example: Basic reconnection"

  let result ← (FFI.connectPlain "127.0.0.1" 6379).toBaseIO
  match result with
  | .ok ctx =>
    Log.info "  Initial connection established"

    -- Verify connection
    let connected1 ← (FFI.isConnected ctx).toBaseIO
    Log.info s!"  Connected: {connected1.toOption.getD false}"

    -- Simulate using the connection
    let _ ← (FFI.ping ctx "test1".toUTF8).toBaseIO
    Log.info "  PING 1 successful"

    -- Reconnect (useful after network issues)
    let reconnResult ← (FFI.reconnect ctx).toBaseIO
    match reconnResult with
    | .ok _ =>
      Log.info "  Reconnected successfully"

      -- Verify new connection works
      let pingResult ← (FFI.ping ctx "test2".toUTF8).toBaseIO
      match pingResult with
      | .ok _ => Log.info "  PING 2 successful after reconnect"
      | .error e => Log.error s!"  PING 2 failed: {e}"

    | .error e =>
      Log.error s!"  Reconnection failed: {e}"

    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.error s!"  Initial connection failed: {e}"

/-- Example: Error state management -/
def exErrorStateManagement (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Error state management"

  -- Check current error state
  let error1 ← FFI.getError ctx
  Log.EIO.info s!"  Current error: {error1.getD "none"}"

  -- Clear any existing errors
  FFI.clearError ctx
  Log.EIO.info "  Cleared error state"

  -- Verify error was cleared
  let error2 ← FFI.getError ctx
  Log.EIO.info s!"  Error after clear: {error2.getD "none"}"

/-- Resilient connection wrapper with auto-reconnect -/
structure ResilientConnection where
  ctx : FFI.Ctx
  maxRetries : Nat := 3
  retryDelayMs : Nat := 1000

namespace ResilientConnection

/-- Create a resilient connection -/
def create (host : String := "127.0.0.1") (port : UInt32 := 6379) : IO (Option ResilientConnection) := do
  let result ← (FFI.connectWithTimeout host port 5000).toBaseIO
  match result with
  | .ok ctx => return some { ctx := ctx }
  | .error _ => return none

/-- Check if connection is healthy -/
def isHealthy (rc : ResilientConnection) : IO Bool := do
  let result ← (FFI.isConnected rc.ctx).toBaseIO
  match result with
  | .ok connected => return connected
  | .error _ => return false

/-- Attempt to reconnect with retries -/
def reconnectWithRetries (rc : ResilientConnection) : IO Bool := do
  for attempt in [:rc.maxRetries] do
    Log.info s!"  Reconnection attempt {attempt + 1}/{rc.maxRetries}"

    let result ← (FFI.reconnect rc.ctx).toBaseIO
    match result with
    | .ok _ =>
      -- Verify with ping
      let pingResult ← (FFI.ping rc.ctx "health".toUTF8).toBaseIO
      match pingResult with
      | .ok _ =>
        Log.info "  Reconnection successful"
        return true
      | .error _ =>
        Log.info "  Reconnected but ping failed, retrying..."

    | .error e =>
      Log.info s!"  Attempt failed: {e}"

    -- Wait before retry
    if attempt < rc.maxRetries - 1 then
      IO.sleep rc.retryDelayMs.toUInt32

  Log.error "  All reconnection attempts failed"
  return false

/-- Execute with auto-reconnect on failure -/
def withAutoReconnect (rc : ResilientConnection) (action : FFI.Ctx → EIO Error α) : IO (Option α) := do
  -- First attempt
  let result1 ← (action rc.ctx).toBaseIO
  match result1 with
  | .ok value => return some value
  | .error _ =>
    -- Connection might be broken, try reconnecting
    Log.info "  Action failed, attempting reconnect..."
    let reconnected ← rc.reconnectWithRetries
    if reconnected then
      -- Retry action after reconnection
      let result2 ← (action rc.ctx).toBaseIO
      match result2 with
      | .ok value => return some value
      | .error _ => return none
    else
      return none

/-- Close the connection -/
def close (rc : ResilientConnection) : IO Unit := do
  let _ ← (FFI.free rc.ctx).toBaseIO
  pure ()

end ResilientConnection

/-- Example: Using resilient connection wrapper -/
def exResilientConnection : IO Unit := do
  Log.info "Example: Resilient connection with auto-reconnect"

  let connOpt ← ResilientConnection.create "127.0.0.1" 6379
  match connOpt with
  | none =>
    Log.error "  Failed to create resilient connection"
  | some rc =>
    Log.info "  Created resilient connection"

    -- Check health
    let healthy ← rc.isHealthy
    Log.info s!"  Connection healthy: {healthy}"

    -- Use with auto-reconnect
    let result ← rc.withAutoReconnect fun ctx => do
      FFI.set ctx "resilient:key".toUTF8 "resilient:value".toUTF8
      let value ← FFI.get ctx "resilient:key".toUTF8
      pure (String.fromUTF8! value)

    match result with
    | some value => Log.info s!"  Got value: {value}"
    | none => Log.error "  Operation failed even after reconnect"

    -- Cleanup
    let _ ← (FFI.del rc.ctx ["resilient:key".toUTF8]).toBaseIO
    rc.close

/-- Example: Connection health monitoring -/
def exHealthMonitoring : IO Unit := do
  Log.info "Example: Connection health monitoring"

  let result ← (FFI.connectPlain "127.0.0.1" 6379).toBaseIO
  match result with
  | .ok ctx =>
    Log.info "  Connected"

    -- Periodic health check pattern
    for i in [:3] do
      let connected ← (FFI.isConnected ctx).toBaseIO
      let errorOpt ← (FFI.getError ctx).toBaseIO

      let connStr := match connected with
        | .ok true => "connected"
        | .ok false => "disconnected"
        | .error _ => "unknown"

      let errStr := match errorOpt with
        | .ok (some e) => e
        | _ => "none"

      Log.info s!"  Health check {i + 1}: status={connStr}, error={errStr}"

      -- Simulate some work
      let _ ← (FFI.ping ctx s!"health{i}".toUTF8).toBaseIO
      IO.sleep 500

    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.error s!"  Connection failed: {e}"

/-- Run all reconnection examples -/
def runReconnectionExamples : IO Unit := do
  let logOk ← Log.initZlog "config/zlog.conf" "reconnection-examples"
  if !logOk then
    IO.eprintln "Warning: Failed to initialize zlog"

  Log.info "=== Redis Reconnection Examples ==="

  -- First connect for examples that need an existing connection
  let result ← (FFI.connectPlain "127.0.0.1" 6379).toBaseIO
  match result with
  | .ok ctx =>
    FFI.toIO <| exCheckConnection ctx
    FFI.toIO <| exErrorStateManagement ctx
    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.error s!"Initial connection failed: {e}"

  exBasicReconnect
  exResilientConnection
  exHealthMonitoring

  Log.info "=== Reconnection Examples Complete ==="
  Log.finiZlog

end FeaturesReconnectionExample
