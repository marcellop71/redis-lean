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
import RedisTests.StreamTests
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
    RedisTests.MathlibTests.allMathlibTests ++
    RedisTests.StreamTests.allStreamTests

-- Unit tests run at elaboration time, so a failure fails the build.
-- Integration tests need a live server and are run from `main` instead
-- (`lake exe redis_tests integration`), so building never requires Redis.
#lspec allUnitTests

/-- Run the integration suite. Returns the process exit code. -/
def runIntegration : IO UInt32 := do
  IO.println "Integration tests (database 15, prefixed keys, cleaned up afterwards)"
  if !(← RedisTests.Integration.serverAvailable) then
    IO.eprintln s!"  no Redis server reachable at \
      {RedisTests.Integration.testConfig.host}:{RedisTests.Integration.testConfig.port}"
    IO.eprintln "  start one and re-run, e.g.  docker run -p 6379:6379 redis:alpine"
    return 2
  let (passed, failed, failures) ← RedisTests.Integration.runAll
  IO.println ""
  IO.println s!"  {passed} passed, {failed} failed"
  if failed > 0 then
    IO.println ""
    IO.println "  Failures:"
    for f in failures do
      IO.println s!"    - {f}"
    return 1
  return 0

-- Main function for command-line execution.
--
-- Every branch returns a meaningful exit code. The previous version printed
-- "All tests passed at compile time via #lspec" and returned 0 unconditionally,
-- so running the binary in CI reported success no matter what.
def main (args : List String) : IO UInt32 := do
  let logOk ← Log.initZlog "config/zlog.conf" "redis-tests"
  if !logOk then
    IO.eprintln "Warning: Failed to initialize zlog, falling back to stderr"

  let usage (code : UInt32) : IO UInt32 := do
    IO.println "Usage: lake exe redis_tests [command]"
    IO.println ""
    IO.println "  unit         Report on the unit suite (it runs at build time via #lspec)"
    IO.println "  integration  Run the integration suite against a live Redis server"
    IO.println "  all          Both (default)"
    IO.println "  list         List available suites"
    return code

  let unitReport : IO UInt32 := do
    -- These are elaboration-time checks: reaching this point at all means the
    -- module compiled, which means they passed.
    IO.println "Unit tests: passed at build time (#lspec in RedisTests.TestRunner)"
    IO.println "  Codec, Config, Error, MockRedis, TypedKey, Metrics, Pool, Mathlib"
    return 0

  let code ← match args with
    | ["unit"]        => unitReport
    | ["integration"] => runIntegration
    | ["list"]        => do
        IO.println "Available suites:"
        IO.println "  unit         no Redis required (runs at build time)"
        IO.println "  integration  requires a Redis server on 127.0.0.1:6379"
        return 0
    | ["all"] | []    => do
        let a ← unitReport
        IO.println ""
        let b ← runIntegration
        return (if a != 0 then a else b)
    | _               => usage 1

  Log.finiZlog
  return code
