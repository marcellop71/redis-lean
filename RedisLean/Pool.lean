import RedisLean.Config
import RedisLean.Error
import RedisLean.FFI
import RedisLean.Metrics
import RedisLean.Monad

namespace Redis

/-- Configuration for connection pool behavior -/
structure PoolConfig where
  /-- Maximum number of connections in the pool -/
  maxConnections : Nat := 10
  /-- Minimum number of connections to maintain -/
  minConnections : Nat := 1
  /-- Timeout in milliseconds when acquiring a connection -/
  acquireTimeoutMs : Nat := 5000
  /-- Time in milliseconds before an idle connection is closed -/
  idleTimeoutMs : Nat := 60000
  /-- Whether to validate connections before use -/
  validateOnAcquire : Bool := true
  deriving Repr

/-- Connection slot in the pool -/
structure PooledConnection where
  /-- The underlying FFI context -/
  ctx : FFI.Ctx
  /-- When this connection was created (nanoseconds) -/
  createdAt : Nat
  /-- When this connection was last used (nanoseconds) -/
  lastUsedAt : IO.Ref Nat
  /-- Whether this connection is currently in use -/
  inUse : IO.Ref Bool

namespace PooledConnection

/-- Create a new pooled connection -/
def create (ctx : FFI.Ctx) : IO PooledConnection := do
  let now ← IO.monoNanosNow
  let lastUsedAt ← IO.mkRef now
  let inUse ← IO.mkRef false
  return { ctx, createdAt := now, lastUsedAt, inUse }

/-- Mark connection as in use -/
def acquire (conn : PooledConnection) : IO Unit := do
  conn.inUse.set true
  let now ← IO.monoNanosNow
  conn.lastUsedAt.set now

/-- Mark connection as available -/
def release (conn : PooledConnection) : IO Unit := do
  conn.inUse.set false
  let now ← IO.monoNanosNow
  conn.lastUsedAt.set now

/-- Check if connection is available -/
def isAvailable (conn : PooledConnection) : IO Bool := do
  let inUse ← conn.inUse.get
  return !inUse

/-- Get idle time in milliseconds -/
def getIdleTimeMs (conn : PooledConnection) : IO Nat := do
  let now ← IO.monoNanosNow
  let lastUsed ← conn.lastUsedAt.get
  return (now - lastUsed) / 1000000

end PooledConnection

/-- Pool statistics -/
structure PoolStats where
  /-- Total connections created -/
  connectionsCreated : IO.Ref Nat
  /-- Total connections acquired -/
  acquireCount : IO.Ref Nat
  /-- Total connections released -/
  releaseCount : IO.Ref Nat
  /-- Acquire timeouts -/
  timeoutCount : IO.Ref Nat
  /-- Failed connection attempts -/
  failedConnections : IO.Ref Nat

namespace PoolStats

def create : IO PoolStats := do
  let connectionsCreated ← IO.mkRef 0
  let acquireCount ← IO.mkRef 0
  let releaseCount ← IO.mkRef 0
  let timeoutCount ← IO.mkRef 0
  let failedConnections ← IO.mkRef 0
  return { connectionsCreated, acquireCount, releaseCount, timeoutCount, failedConnections }

def incrementCreated (stats : PoolStats) : IO Unit :=
  stats.connectionsCreated.modify (· + 1)

def incrementAcquired (stats : PoolStats) : IO Unit :=
  stats.acquireCount.modify (· + 1)

def incrementReleased (stats : PoolStats) : IO Unit :=
  stats.releaseCount.modify (· + 1)

def incrementTimeout (stats : PoolStats) : IO Unit :=
  stats.timeoutCount.modify (· + 1)

def incrementFailed (stats : PoolStats) : IO Unit :=
  stats.failedConnections.modify (· + 1)

def getSnapshot (stats : PoolStats) : IO (Nat × Nat × Nat × Nat × Nat) := do
  let created ← stats.connectionsCreated.get
  let acquired ← stats.acquireCount.get
  let released ← stats.releaseCount.get
  let timeouts ← stats.timeoutCount.get
  let failed ← stats.failedConnections.get
  return (created, acquired, released, timeouts, failed)

end PoolStats

/-- Connection pool for managing multiple Redis connections.
    Note: This implementation uses a simple spin-lock approach for thread safety.
    For high-concurrency scenarios, consider using external synchronization. -/
structure Pool where
  /-- Pool configuration -/
  config : PoolConfig
  /-- Redis configuration for creating new connections -/
  redisConfig : Config
  /-- All connections in the pool -/
  connections : IO.Ref (Array PooledConnection)
  /-- Simple lock flag for synchronization -/
  lockFlag : IO.Ref Bool
  /-- Pool statistics -/
  stats : PoolStats

namespace Pool

/-- Acquire the lock (simple spin-lock) -/
private def acquireLock (pool : Pool) : IO Unit := do
  let mut acquired := false
  while !acquired do
    let current ← pool.lockFlag.get
    if !current then
      pool.lockFlag.set true
      acquired := true
    else
      IO.sleep 1

/-- Release the lock -/
private def releaseLock (pool : Pool) : IO Unit :=
  pool.lockFlag.set false

/-- Create a new connection pool -/
def create (cfg : Config) (poolCfg : PoolConfig := {}) : IO Pool := do
  let connections ← IO.mkRef #[]
  let lockFlag ← IO.mkRef false
  let stats ← PoolStats.create
  let pool : Pool := {
    config := poolCfg,
    redisConfig := cfg,
    connections,
    lockFlag,
    stats
  }
  -- Initialize minimum connections
  for _ in [:poolCfg.minConnections] do
    let _ ← createConnectionInternal pool
  return pool
where
  createConnectionInternal (pool : Pool) : IO (Option PooledConnection) := do
    let conns ← pool.connections.get
    if conns.size >= pool.config.maxConnections then
      return none
    try
      let ctx ← EIO.toIO (fun e => IO.userError s!"Connection failed: {e}")
        (FFI.connect pool.redisConfig.host (UInt32.ofNat pool.redisConfig.port) pool.redisConfig.ssl)
      let conn ← PooledConnection.create ctx
      pool.connections.modify (·.push conn)
      PoolStats.incrementCreated pool.stats
      return some conn
    catch _ =>
      PoolStats.incrementFailed pool.stats
      return none

/-- Create a new connection and add it to the pool -/
private def createConnection (pool : Pool) : IO (Option PooledConnection) := do
  let conns ← pool.connections.get
  if conns.size >= pool.config.maxConnections then
    return none
  try
    let ctx ← EIO.toIO (fun e => IO.userError s!"Connection failed: {e}")
      (FFI.connect pool.redisConfig.host (UInt32.ofNat pool.redisConfig.port) pool.redisConfig.ssl)
    let conn ← PooledConnection.create ctx
    pool.connections.modify (·.push conn)
    PoolStats.incrementCreated pool.stats
    return some conn
  catch _ =>
    PoolStats.incrementFailed pool.stats
    return none

/-- Find an available connection in the pool -/
private def findAvailable (pool : Pool) : IO (Option PooledConnection) := do
  let conns ← pool.connections.get
  for conn in conns do
    let available ← conn.isAvailable
    if available then
      return some conn
  return none

/-- Acquire a connection from the pool -/
def acquire (pool : Pool) : IO (Except Error FFI.Ctx) := do
  let startTime ← IO.monoNanosNow
  let timeoutNs := pool.config.acquireTimeoutMs * 1000000
  acquireLock pool
  try
    -- Try to find an available connection
    let mut result : Option PooledConnection := none
    while result.isNone do
      let available ← findAvailable pool
      match available with
      | some conn =>
        conn.acquire
        PoolStats.incrementAcquired pool.stats
        result := some conn
      | none =>
        -- Try to create a new connection
        let newConn ← createConnection pool
        match newConn with
        | some conn =>
          conn.acquire
          PoolStats.incrementAcquired pool.stats
          result := some conn
        | none =>
          -- Check timeout
          let now ← IO.monoNanosNow
          if now - startTime > timeoutNs then
            PoolStats.incrementTimeout pool.stats
            releaseLock pool
            return .error (.otherError "Connection pool acquire timeout")
          -- Wait a bit and retry
          releaseLock pool
          IO.sleep 10
          acquireLock pool
    releaseLock pool
    match result with
    | some conn => return .ok conn.ctx
    | none => return .error (.otherError "Failed to acquire connection")
  catch e =>
    releaseLock pool
    return .error (.otherError s!"Pool acquire error: {e}")

/-- Release a connection back to the pool -/
def release (pool : Pool) (ctx : FFI.Ctx) : IO Unit := do
  acquireLock pool
  let conns ← pool.connections.get
  for conn in conns do
    if conn.ctx == ctx then
      conn.release
      PoolStats.incrementReleased pool.stats
      break
  releaseLock pool

/-- Execute an action with a pooled connection -/
def withConnection (pool : Pool) (action : RedisM α) : IO (Except Error α) := do
  let ctxResult ← pool.acquire
  match ctxResult with
  | .error e => return .error e
  | .ok ctx =>
    let metrics ← Metrics.make
    let state : State := {
      ctx := ctx,
      isConnected := true,
      metrics := metrics,
      recordLatency := fun cmd micros => Metrics.recordLatency metrics cmd micros
    }
    let read : Read := { config := pool.redisConfig, enableMetrics := true }
    try
      let result ← runRedisFromState read state action
      pool.release ctx
      return result
    catch e =>
      pool.release ctx
      return .error (.otherError s!"Action failed: {e}")

/-- Get the current pool size -/
def size (pool : Pool) : IO Nat := do
  let conns ← pool.connections.get
  return conns.size

/-- Get the number of available connections -/
def availableCount (pool : Pool) : IO Nat := do
  let conns ← pool.connections.get
  let mut count := 0
  for conn in conns do
    let available ← conn.isAvailable
    if available then count := count + 1
  return count

/-- Get the number of connections in use -/
def inUseCount (pool : Pool) : IO Nat := do
  let total ← pool.size
  let available ← pool.availableCount
  return total - available

/-- Close idle connections that exceed the idle timeout -/
def pruneIdleConnections (pool : Pool) : IO Nat := do
  acquireLock pool
  let conns ← pool.connections.get
  let mut pruned := 0
  let mut newConns : Array PooledConnection := #[]
  for conn in conns do
    let available ← conn.isAvailable
    let idleMs ← conn.getIdleTimeMs
    if available && idleMs > pool.config.idleTimeoutMs && newConns.size >= pool.config.minConnections then
      -- Close this connection
      let _ ← EIO.toIO (fun _ => IO.userError "free failed") (FFI.Internal.free conn.ctx)
      pruned := pruned + 1
    else
      newConns := newConns.push conn
  pool.connections.set newConns
  releaseLock pool
  return pruned

/-- Close all connections and reset the pool -/
def close (pool : Pool) : IO Unit := do
  acquireLock pool
  let conns ← pool.connections.get
  for conn in conns do
    let _ ← EIO.toIO (fun _ => IO.userError "free failed") (FFI.Internal.free conn.ctx)
  pool.connections.set #[]
  releaseLock pool

/-- Get pool statistics -/
def getStats (pool : Pool) : IO (Nat × Nat × Nat × Nat × Nat) :=
  PoolStats.getSnapshot pool.stats

/-- Print pool status -/
def printStatus (pool : Pool) : IO Unit := do
  let total ← pool.size
  let available ← pool.availableCount
  let inUse ← pool.inUseCount
  let (created, acquired, released, timeouts, failed) ← pool.getStats
  IO.println s!"=== Pool Status ==="
  IO.println s!"  Size: {total} (available: {available}, in use: {inUse})"
  IO.println s!"  Config: max={pool.config.maxConnections}, min={pool.config.minConnections}"
  IO.println s!"  Stats: created={created}, acquired={acquired}, released={released}"
  IO.println s!"  Errors: timeouts={timeouts}, failed={failed}"

end Pool

end Redis
