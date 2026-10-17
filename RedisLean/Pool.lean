import Std.Sync.Mutex
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
  /-- Stable slot identity. `FFI.Ctx` is opaque and has no `BEq`, so the pool
      tracks slots by this rather than by comparing handles. -/
  id : Nat
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
def create (id : Nat) (ctx : FFI.Ctx) : IO PooledConnection := do
  let now ← IO.monoNanosNow
  let lastUsedAt ← IO.mkRef now
  let inUse ← IO.mkRef false
  return { id, ctx, createdAt := now, lastUsedAt, inUse }

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

All mutation of the pool's slot table happens under `lock`, a real mutex. The
previous version tested and set an `IO.Ref Bool`, which is not atomic and so
provided no mutual exclusion at all. -/
structure Pool where
  /-- Pool configuration -/
  config : PoolConfig
  /-- Redis configuration for creating new connections -/
  redisConfig : Config
  /-- All connections in the pool -/
  connections : IO.Ref (Array PooledConnection)
  /-- Guards `connections` and `nextId`. -/
  lock : Std.BaseMutex
  /-- Monotonic source of slot ids -/
  nextId : IO.Ref Nat
  /-- Pool statistics -/
  stats : PoolStats
  /-- Metrics shared by every `withConnection` call on this pool. -/
  metrics : Metrics

namespace Pool

/-- Run `act` holding the pool lock. Never nest these: `BaseMutex` is not
reentrant, so a nested lock on the same thread is undefined behaviour. -/
private def withLock {α : Type} (pool : Pool) (act : IO α) : IO α := do
  pool.lock.lock
  try act finally pool.lock.unlock

/-- Create a new connection and add it to the pool -/
private def createConnection (pool : Pool) : IO (Option PooledConnection) := do
  let conns ← pool.connections.get
  if conns.size >= pool.config.maxConnections then
    return none
  try
    let ctx ← EIO.toIO (fun e => IO.userError s!"Connection failed: {e}")
      (FFI.connectConfig pool.redisConfig)
    let id ← pool.nextId.modifyGet (fun n => (n, n + 1))
    let conn ← PooledConnection.create id ctx
    pool.connections.modify (·.push conn)
    PoolStats.incrementCreated pool.stats
    return some conn
  catch _ =>
    PoolStats.incrementFailed pool.stats
    return none

/-- Create a new connection pool -/
def create (cfg : Config) (poolCfg : PoolConfig := {}) : IO Pool := do
  let connections ← IO.mkRef #[]
  let lock ← Std.BaseMutex.new
  let nextId ← IO.mkRef 0
  let stats ← PoolStats.create
  let metrics ← Metrics.make
  let pool : Pool := {
    config := poolCfg,
    redisConfig := cfg,
    connections,
    lock,
    nextId,
    stats,
    metrics
  }
  -- Initialize minimum connections
  for _ in [:poolCfg.minConnections] do
    let _ ← createConnection pool
  return pool

/-- Find an available connection in the pool -/
private def findAvailable (pool : Pool) : IO (Option PooledConnection) := do
  let conns ← pool.connections.get
  for conn in conns do
    let available ← conn.isAvailable
    if available then
      return some conn
  return none

/-- Drop a slot from the pool and close its connection. Caller must hold the lock. -/
private def discardLocked (pool : Pool) (target : PooledConnection) : IO Unit := do
  pool.connections.modify (·.filter (fun c => c.id != target.id))
  let _ ← (FFI.close target.ctx).toBaseIO
  pure ()

/-- Check a connection is still usable, reconnecting once if it is not.
Honours `PoolConfig.validateOnAcquire`; a no-op when that is `false`. -/
private def validate (pool : Pool) (conn : PooledConnection) : IO Bool := do
  if !pool.config.validateOnAcquire then return true
  match ← (FFI.isConnected conn.ctx).toBaseIO with
  | .ok true => return true
  | _ =>
    match ← (FFI.reconnectConfig conn.ctx pool.redisConfig).toBaseIO with
    | .ok _ => return true
    | .error _ => return false

/-- One locked attempt to take a slot: reuse an idle one, else open a new one. -/
private def tryTakeSlot (pool : Pool) : IO (Option PooledConnection) :=
  pool.withLock do
    match ← findAvailable pool with
    | some conn =>
      conn.acquire
      PoolStats.incrementAcquired pool.stats
      return some conn
    | none =>
      match ← createConnection pool with
      | some conn =>
        conn.acquire
        PoolStats.incrementAcquired pool.stats
        return some conn
      | none => return none

/-- Acquire a connection from the pool, waiting up to `acquireTimeoutMs`. -/
partial def acquire (pool : Pool) : IO (Except Error PooledConnection) := do
  let startTime ← IO.monoNanosNow
  let timeoutNs := pool.config.acquireTimeoutMs * 1000000
  let rec go : IO (Except Error PooledConnection) := do
    match ← tryTakeSlot pool with
    | some conn =>
      if ← validate pool conn then
        return .ok conn
      else
        -- Dead connection: retire the slot and try again, which frees capacity
        -- for `createConnection` to open a replacement.
        pool.withLock (discardLocked pool conn)
        PoolStats.incrementFailed pool.stats
        go
    | none =>
      let now ← IO.monoNanosNow
      if now - startTime > timeoutNs then
        PoolStats.incrementTimeout pool.stats
        return .error (.otherError "Connection pool acquire timeout")
      IO.sleep 10
      go
  go

/-- Release a connection back to the pool -/
def release (pool : Pool) (target : PooledConnection) : IO Unit :=
  pool.withLock do
    let conns ← pool.connections.get
    for conn in conns do
      if conn.id == target.id then
        conn.release
        PoolStats.incrementReleased pool.stats
        break

/-- Execute an action with a pooled connection -/
def withConnection (pool : Pool) (action : RedisM α) : IO (Except Error α) := do
  let acquired ← pool.acquire
  match acquired with
  | .error e => return .error e
  | .ok conn =>
    -- Use the pool's own metrics, so measurements accumulate across calls
    -- instead of being created and discarded per `withConnection`.
    let state : State := {
      ctx := conn.ctx,
      isConnected := true,
      metrics := pool.metrics,
      recordLatency := fun cmd micros => Metrics.recordLatency pool.metrics cmd micros
    }
    let read : Read := { config := pool.redisConfig, enableMetrics := true }
    try
      let result ← runRedisFromState read state action
      pool.release conn
      return result
    catch e =>
      pool.release conn
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
def pruneIdleConnections (pool : Pool) : IO Nat := pool.withLock do
  let conns ← pool.connections.get
  let mut pruned := 0
  let mut newConns : Array PooledConnection := #[]
  for conn in conns do
    let available ← conn.isAvailable
    let idleMs ← conn.getIdleTimeMs
    if available && idleMs > pool.config.idleTimeoutMs && newConns.size >= pool.config.minConnections then
      -- Close this connection
      let _ ← EIO.toIO (fun _ => IO.userError "free failed") (FFI.Internal.close conn.ctx)
      pruned := pruned + 1
    else
      newConns := newConns.push conn
  pool.connections.set newConns
  return pruned

/-- Close all connections and reset the pool -/
def close (pool : Pool) : IO Unit := pool.withLock do
  let conns ← pool.connections.get
  for conn in conns do
    let _ ← EIO.toIO (fun _ => IO.userError "free failed") (FFI.Internal.close conn.ctx)
  pool.connections.set #[]

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
