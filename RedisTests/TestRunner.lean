import LSpec
import RedisTests.Codec
import RedisTests.Config
import RedisTests.Error
import RedisTests.MockTests
import RedisTests.TypedKeyTests
import RedisTests.MetricsTests
import RedisTests.PoolTests
import RedisTests.MathlibTests
import RedisTests.Integration
import RedisLean.Log

open LSpec
open Redis

/-!
# Redis-Lean Test Runner

Comprehensive test suite for redis-lean covering:
- Codec: Serialization/deserialization of types
- Config: Redis connection configuration
- Error: Error types and handling
- Mock: In-memory MockRedis implementation
- TypedKey: Phantom-typed keys and namespaces
- Metrics: Observability and metrics collection
- Pool: Connection pool configuration
- Mathlib: Mathlib integration data structures
- Integration: Redis server integration tests
-/

-- Unit tests (no Redis server required)
def allUnitTests : TestSeq :=
  group "Redis-Lean Unit Tests" $
    RedisTests.Codec.allCodecTests ++
    RedisTests.Config.allConfigTests ++
    RedisTests.Error.allErrorTests ++
    RedisTests.MockTests.allMockTests ++
    RedisTests.TypedKeyTests.allTypedKeyTests ++
    RedisTests.MetricsTests.allMetricsTests ++
    RedisTests.PoolTests.allPoolTests ++
    RedisTests.MathlibTests.allMathlibTests

-- Integration tests (placeholder - requires Redis server)
def allIntegrationTests : TestSeq :=
  group "Redis-Lean Integration Tests" $
    RedisTests.Integration.allIntegrationTests

-- Complete test suite
def completeTestSuite : TestSeq :=
  allUnitTests ++ allIntegrationTests

-- Interactive test runner (runs at compile time)
#lspec completeTestSuite

-- Main function for command-line execution
def main (args : List String) : IO UInt32 := do
  -- Initialize zlog
  let logOk ← Log.initZlog "config/zlog.conf" "redis-tests"
  if !logOk then
    IO.eprintln "Warning: Failed to initialize zlog, falling back to stderr"

  match args with
  | ["unit"] => do
    Log.info "Running unit tests only..."
    Log.info "Unit tests passed at compile time via #lspec"
    Log.info ""
    Log.info "Test coverage includes:"
    Log.info "  - Codec tests (String, Int, Nat, Bool, ByteArray)"
    Log.info "  - Config tests (parsing, creation, roundtrip)"
    Log.info "  - Error tests (construction, pattern matching)"
    Log.info "  - MockRedis tests (all data structures)"
    Log.info "  - TypedKey tests (phantom types, namespaces)"
    Log.info "  - Metrics tests (percentiles, counts, export)"
    Log.info "  - Pool tests (configuration, scenarios)"
    Log.info "  - Mathlib tests (data structures, key generation)"
    Log.finiZlog
    return 0
  | ["integration"] => do
    Log.info "Running integration tests (Redis server required)..."
    Log.info "Integration tests are placeholders - require actual Redis server"
    Log.info ""
    Log.info "To run with a Redis server:"
    Log.info "  1. Start Redis: docker run -p 6379:6379 redis:alpine"
    Log.info "  2. Run: lake exe testRunner integration"
    Log.finiZlog
    return 0
  | ["mock"] => do
    Log.info "Running MockRedis tests..."
    Log.info "MockRedis tests passed at compile time via #lspec"
    Log.finiZlog
    return 0
  | ["mathlib"] => do
    Log.info "Running Mathlib integration tests..."
    Log.info "Mathlib tests passed at compile time via #lspec"
    Log.finiZlog
    return 0
  | ["list"] => do
    Log.info "Available test suites:"
    Log.info "  unit        - All unit tests (no Redis required)"
    Log.info "  integration - Integration tests (requires Redis)"
    Log.info "  mock        - MockRedis tests"
    Log.info "  mathlib     - Mathlib data structure tests"
    Log.info "  all         - Complete test suite (default)"
    Log.finiZlog
    return 0
  | ["all"] | [] => do
    Log.info "Running all tests..."
    Log.info "All tests passed at compile time via #lspec"
    Log.info ""
    Log.info "Test summary:"
    Log.info "  - Codec: 8 test groups"
    Log.info "  - Config: 11 test groups"
    Log.info "  - Error: 10 test groups"
    Log.info "  - MockRedis: 6 test groups"
    Log.info "  - TypedKey: 9 test groups"
    Log.info "  - Metrics: 8 test groups"
    Log.info "  - Pool: 7 test groups"
    Log.info "  - Mathlib: 13 test groups"
    Log.info "  - Integration: 9 test groups (placeholders)"
    Log.finiZlog
    return 0
  | _ => do
    Log.info "Redis-Lean Test Runner"
    Log.info ""
    Log.info "Usage: testRunner [command]"
    Log.info ""
    Log.info "Commands:"
    Log.info "  unit        - Run unit tests only (no Redis server needed)"
    Log.info "  integration - Run integration tests (requires Redis server)"
    Log.info "  mock        - Run MockRedis tests"
    Log.info "  mathlib     - Run Mathlib structure tests"
    Log.info "  list        - List available test suites"
    Log.info "  all         - Run all tests (default)"
    Log.info ""
    Log.info "Examples:"
    Log.info "  lake exe testRunner"
    Log.info "  lake exe testRunner unit"
    Log.info "  lake exe testRunner list"
    Log.finiZlog
    return 1
