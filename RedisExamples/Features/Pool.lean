import RedisLean.Pool
import RedisLean.Log
import RedisLean.Monad
import RedisLean.Ops

namespace FeaturesPoolExample

open Redis

/-!
# Connection Pool Examples

Demonstrates connection pooling for efficient Redis connection management.
Connection pools:
- Reuse connections to avoid connection overhead
- Limit concurrent connections
- Handle connection lifecycle automatically
-/

/-- Example: Basic pool usage -/
def exBasicPool : IO Unit := do
  Log.info "Example: Basic pool usage"

  -- Create a pool with default configuration
  let redisConfig : Config := {}  -- Default host/port
  let poolConfig : PoolConfig := {
    maxConnections := 10
    minConnections := 2
    acquireTimeoutMs := 5000
    idleTimeoutMs := 60000
  }

  let pool ← Pool.create redisConfig poolConfig
  Log.info s!"Created pool with max {poolConfig.maxConnections} connections"

  -- Use a connection from the pool with RedisM action
  let result ← pool.withConnection do
    set "pool:test" "Hello from pool"
    getAs String "pool:test"

  match result with
  | .ok value => Log.info s!"Result: {value}"
  | .error e => Log.info s!"Error: {e}"

  -- Connection is automatically returned to pool

/-- Example: Pool statistics -/
def exPoolStats : IO Unit := do
  Log.info "Example: Pool statistics"

  let redisConfig : Config := {}
  let poolConfig : PoolConfig := {
    maxConnections := 5
    minConnections := 1
    acquireTimeoutMs := 5000
    idleTimeoutMs := 60000
  }

  let pool ← Pool.create redisConfig poolConfig

  -- Get initial stats
  let (created1, acquired1, released1, timeouts1, failed1) ← pool.getStats
  Log.info s!"Initial stats:"
  Log.info s!"  Created: {created1}, Acquired: {acquired1}, Released: {released1}"
  Log.info s!"  Timeouts: {timeouts1}, Failed: {failed1}"

  -- Use a connection
  let _ ← pool.withConnection do
    set "stats:test" "value"

  let (created2, acquired2, released2, _, _) ← pool.getStats
  Log.info s!"After withConnection:"
  Log.info s!"  Created: {created2}, Acquired: {acquired2}, Released: {released2}"

  -- Get pool size info
  let total ← pool.size
  let available ← pool.availableCount
  let inUse ← pool.inUseCount
  Log.info s!"Pool size: total={total}, available={available}, inUse={inUse}"

/-- Example: Concurrent pool access -/
def exConcurrentAccess : IO Unit := do
  Log.info "Example: Concurrent pool access"

  let redisConfig : Config := {}
  let poolConfig : PoolConfig := {
    maxConnections := 3
    minConnections := 1
  }

  let pool ← Pool.create redisConfig poolConfig

  -- Run multiple operations (simplified - not truly concurrent)
  let _ ← pool.withConnection do
    set "concurrent:1" "Value 1"
  Log.info "  Task 1 done"

  let _ ← pool.withConnection do
    set "concurrent:2" "Value 2"
  Log.info "  Task 2 done"

  let _ ← pool.withConnection do
    set "concurrent:3" "Value 3"
  Log.info "  Task 3 done"

  let (_, acquired, released, _, _) ← pool.getStats
  Log.info s!"Final stats: acquired={acquired}, released={released}"

/-- Example: Pool configuration options -/
def exPoolConfiguration : IO Unit := do
  Log.info "Example: Pool configuration options"

  let redisConfig : Config := {}

  -- High-throughput configuration
  let highThroughputConfig : PoolConfig := {
    maxConnections := 50      -- Many connections for high concurrency
    minConnections := 10      -- Keep connections warm
    acquireTimeoutMs := 1000  -- Fast timeout
    idleTimeoutMs := 300000   -- 5 minutes idle timeout
    validateOnAcquire := true -- Validate connections
  }
  Log.info s!"High-throughput config: max={highThroughputConfig.maxConnections}, min={highThroughputConfig.minConnections}"

  -- Low-resource configuration
  let lowResourceConfig : PoolConfig := {
    maxConnections := 5       -- Limited connections
    minConnections := 1       -- Minimal warm connections
    acquireTimeoutMs := 10000 -- Longer timeout (willing to wait)
    idleTimeoutMs := 30000    -- Short idle timeout to free resources
  }
  Log.info s!"Low-resource config: max={lowResourceConfig.maxConnections}, min={lowResourceConfig.minConnections}"

  -- Create and test the low-resource pool
  let pool ← Pool.create redisConfig lowResourceConfig

  let result ← pool.withConnection do
    set "config:test" "test"
    pure "Configuration test successful"

  match result with
  | .ok msg => Log.info s!"  {msg}"
  | .error e => Log.info s!"  Error: {e}"

/-- Example: Pool status printing -/
def exPoolStatus : IO Unit := do
  Log.info "Example: Pool status"

  let redisConfig : Config := {}
  let poolConfig : PoolConfig := {
    maxConnections := 5
    minConnections := 2
  }

  let pool ← Pool.create redisConfig poolConfig

  -- Do some work
  let _ ← pool.withConnection do
    set "status:key1" "value1"
  let _ ← pool.withConnection do
    set "status:key2" "value2"

  -- Print pool status
  pool.printStatus

/-- Example: Pruning idle connections -/
def exPruneConnections : IO Unit := do
  Log.info "Example: Pruning idle connections"

  let redisConfig : Config := {}
  let poolConfig : PoolConfig := {
    maxConnections := 10
    minConnections := 1
    idleTimeoutMs := 100  -- Very short for testing
  }

  let pool ← Pool.create redisConfig poolConfig

  -- Create some connections
  let _ ← pool.withConnection do
    set "prune:test" "value"

  let sizeBefore ← pool.size
  Log.info s!"Pool size before prune: {sizeBefore}"

  -- Wait for connections to become idle
  IO.sleep 150

  -- Prune idle connections
  let pruned ← pool.pruneIdleConnections
  Log.info s!"Pruned {pruned} idle connections"

  let sizeAfter ← pool.size
  Log.info s!"Pool size after prune: {sizeAfter}"

/-- Example: Closing the pool -/
def exClosePool : IO Unit := do
  Log.info "Example: Closing the pool"

  let redisConfig : Config := {}
  let poolConfig : PoolConfig := {
    maxConnections := 5
    minConnections := 2
  }

  let pool ← Pool.create redisConfig poolConfig

  -- Do some work
  let _ ← pool.withConnection do
    set "close:test" "value"

  let sizeBefore ← pool.size
  Log.info s!"Pool size before close: {sizeBefore}"

  -- Close all connections
  pool.close
  Log.info "Pool closed"

  let sizeAfter ← pool.size
  Log.info s!"Pool size after close: {sizeAfter}"

/-- Run all pool examples -/
def runAllExamples : IO Unit := do
  Log.info "=== Connection Pool Examples ==="
  exBasicPool
  exPoolStats
  exConcurrentAccess
  exPoolConfiguration
  exPoolStatus
  exPruneConnections
  exClosePool
  Log.info "=== Connection Pool Examples Complete ==="

end FeaturesPoolExample
