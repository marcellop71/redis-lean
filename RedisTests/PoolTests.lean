import LSpec
import RedisLean.Pool
import RedisLean.Config

open Redis LSpec

namespace RedisTests.PoolTests

/-!
# Connection Pool Tests

Tests for connection pool configuration and behavior.
Note: Actual connection pooling requires a Redis server,
so we focus on configuration and state management tests.
-/

-- PoolConfig Tests

def poolConfigDefaultTests : TestSeq :=
  test "Default PoolConfig has reasonable maxConnections" (
    let config : PoolConfig := {}
    config.maxConnections > 0) $
  test "Default PoolConfig has reasonable minConnections" (
    let config : PoolConfig := {}
    config.minConnections >= 0) $
  test "Default min <= max connections" (
    let config : PoolConfig := {}
    config.minConnections <= config.maxConnections) $
  test "Default acquireTimeout is positive" (
    let config : PoolConfig := {}
    config.acquireTimeoutMs > 0) $
  test "Default idleTimeout is positive" (
    let config : PoolConfig := {}
    config.idleTimeoutMs > 0)

def poolConfigCustomTests : TestSeq :=
  test "Custom maxConnections" (
    let config : PoolConfig := { maxConnections := 50 }
    config.maxConnections == 50) $
  test "Custom minConnections" (
    let config : PoolConfig := { minConnections := 5 }
    config.minConnections == 5) $
  test "Custom acquireTimeout" (
    let config : PoolConfig := { acquireTimeoutMs := 10000 }
    config.acquireTimeoutMs == 10000) $
  test "Custom idleTimeout" (
    let config : PoolConfig := { idleTimeoutMs := 60000 }
    config.idleTimeoutMs == 60000) $
  test "All custom values" (
    let config : PoolConfig := {
      maxConnections := 100
      minConnections := 10
      acquireTimeoutMs := 5000
      idleTimeoutMs := 30000
    }
    config.maxConnections == 100 &&
    config.minConnections == 10 &&
    config.acquireTimeoutMs == 5000 &&
    config.idleTimeoutMs == 30000)

def poolConfigEdgeCaseTests : TestSeq :=
  test "maxConnections of 1" (
    let config : PoolConfig := { maxConnections := 1 }
    config.maxConnections == 1) $
  test "minConnections of 0" (
    let config : PoolConfig := { minConnections := 0 }
    config.minConnections == 0) $
  test "Very large maxConnections" (
    let config : PoolConfig := { maxConnections := 10000 }
    config.maxConnections == 10000) $
  test "Zero timeout" (
    let config : PoolConfig := { acquireTimeoutMs := 0 }
    config.acquireTimeoutMs == 0)

-- PoolConfig Modification Tests

def poolConfigModificationTests : TestSeq :=
  test "Modify maxConnections preserves other fields" (
    let base : PoolConfig := { minConnections := 5, idleTimeoutMs := 30000 }
    let modified : PoolConfig := { base with maxConnections := 20 }
    modified.minConnections == 5 && modified.idleTimeoutMs == 30000) $
  test "Modify multiple fields" (
    let base : PoolConfig := { maxConnections := 10, minConnections := 2 }
    let modified : PoolConfig := { base with maxConnections := 20, minConnections := 5 }
    modified.maxConnections == 20 && modified.minConnections == 5)

-- Pool Configuration Scenarios

def scenarioTests : TestSeq :=
  test "Development config (small pool)" (
    let config : PoolConfig := { maxConnections := 5, minConnections := 1 }
    config.maxConnections == 5 && config.minConnections == 1) $
  test "Production config (large pool)" (
    let config : PoolConfig := { maxConnections := 100, minConnections := 10 }
    config.maxConnections == 100 && config.minConnections == 10) $
  test "High-throughput config" (
    let config : PoolConfig := {
      maxConnections := 200
      minConnections := 50
      acquireTimeoutMs := 1000  -- Fast fail
      idleTimeoutMs := 60000
    }
    config.maxConnections == 200 && config.acquireTimeoutMs == 1000) $
  test "Resource-constrained config" (
    let config : PoolConfig := {
      maxConnections := 3
      minConnections := 1
      acquireTimeoutMs := 30000  -- Wait longer
      idleTimeoutMs := 300000    -- Keep connections longer
    }
    config.maxConnections == 3 && config.idleTimeoutMs == 300000)

-- Combined Config Tests (Pool + Redis Config)

def combinedConfigTests : TestSeq :=
  test "PoolConfig with default Redis Config" (
    let redisConfig : Config := {}
    let poolConfig : PoolConfig := { maxConnections := 10 }
    redisConfig.host == "127.0.0.1" && poolConfig.maxConnections == 10) $
  test "PoolConfig with custom Redis Config" (
    let redisConfig : Config := { host := "redis.example.com", port := 6380 }
    let poolConfig : PoolConfig := { maxConnections := 50, minConnections := 5 }
    redisConfig.host == "redis.example.com" && poolConfig.maxConnections == 50) $
  test "Multiple database configs" (
    let db0Config : Config := { database := 0 }
    let db1Config : Config := { database := 1 }
    let poolConfig : PoolConfig := { maxConnections := 10 }
    db0Config.database != db1Config.database && poolConfig.maxConnections == 10)

-- Validation Logic Tests (conceptual - pool should validate)

def validationConceptTests : TestSeq :=
  test "min should not exceed max (valid case)" (
    let config : PoolConfig := { maxConnections := 10, minConnections := 5 }
    config.minConnections <= config.maxConnections) $
  test "Equal min and max is valid" (
    let config : PoolConfig := { maxConnections := 10, minConnections := 10 }
    config.minConnections == config.maxConnections) $
  test "Timeouts should be reasonable" (
    let config : PoolConfig := { acquireTimeoutMs := 5000, idleTimeoutMs := 60000 }
    config.acquireTimeoutMs < config.idleTimeoutMs)

-- All Pool Tests
def allPoolTests : TestSeq :=
  group "PoolConfig Defaults" poolConfigDefaultTests $
  group "PoolConfig Custom Values" poolConfigCustomTests $
  group "PoolConfig Edge Cases" poolConfigEdgeCaseTests $
  group "PoolConfig Modification" poolConfigModificationTests $
  group "Pool Scenarios" scenarioTests $
  group "Combined Configurations" combinedConfigTests $
  group "Validation Concepts" validationConceptTests

end RedisTests.PoolTests
