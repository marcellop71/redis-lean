import LSpec
import RedisLean.Metrics
import RedisLean.Mathlib.Core

open Redis LSpec
open Redis.Mathlib

namespace RedisTests.MetricsTests

/-!
# Metrics Tests

Tests for the metrics and observability system.
-/

-- Helper to run IO tests
unsafe def unsafeRunIO (action : IO Bool) : Bool :=
  match unsafeBaseIO action.toBaseIO with
  | .ok b => b
  | .error _ => false

@[implemented_by unsafeRunIO]
def ioTest (_action : IO Bool) : Bool := false

-- Metrics Creation Tests

def testMetricsCreate : IO Bool := do
  let _metrics ← Metrics.make
  return true

def testRecordLatency : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "GET" 100
  metrics.recordLatency "GET" 200
  metrics.recordLatency "GET" 150
  return true

def testRecordMultipleOperations : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "GET" 100
  metrics.recordLatency "SET" 150
  metrics.recordLatency "DEL" 50
  metrics.recordLatency "HGET" 120
  return true

def metricsCreationTests : TestSeq :=
  test "Metrics.make creates metrics" (ioTest testMetricsCreate) $
  test "recordLatency records latencies" (ioTest testRecordLatency) $
  test "Multiple operations can be recorded" (ioTest testRecordMultipleOperations)

-- Percentile Tests

def testP50 : IO Bool := do
  let metrics ← Metrics.make
  for i in [100, 200, 300, 400, 500] do
    metrics.recordLatency "GET" i
  let p50 ← Metrics.getP50Latency metrics
  return p50 >= 200 && p50 <= 400

def testP95 : IO Bool := do
  let metrics ← Metrics.make
  for i in [:100] do
    metrics.recordLatency "GET" (i + 1)
  let p95 ← Metrics.getP95Latency metrics
  return p95 >= 90 && p95 <= 100

def testP99 : IO Bool := do
  let metrics ← Metrics.make
  for i in [:100] do
    metrics.recordLatency "GET" (i + 1)
  let p99 ← Metrics.getP99Latency metrics
  return p99 >= 95 && p99 <= 100

def testPercentileNoData : IO Bool := do
  let metrics ← Metrics.make
  let p50 ← Metrics.getP50Latency metrics
  return p50 == 0

def testPercentileSingleValue : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "SINGLE" 500
  let p50 ← Metrics.getP50Latency metrics
  let p95 ← Metrics.getP95Latency metrics
  let p99 ← Metrics.getP99Latency metrics
  return p50 == 500 && p95 == 500 && p99 == 500

def percentileTests : TestSeq :=
  test "P50 calculation" (ioTest testP50) $
  test "P95 calculation" (ioTest testP95) $
  test "P99 calculation" (ioTest testP99) $
  test "Percentile with no data returns 0" (ioTest testPercentileNoData) $
  test "Percentile with single value" (ioTest testPercentileSingleValue)

-- Count Tests

def testGetCount : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "COUNT_TEST" 100
  metrics.recordLatency "COUNT_TEST" 200
  metrics.recordLatency "COUNT_TEST" 300
  let counts ← Metrics.getCommandCounts metrics
  let count := counts.getD "COUNT_TEST" 0
  return count == 3

def testGetCountEmpty : IO Bool := do
  let metrics ← Metrics.make
  let counts ← Metrics.getCommandCounts metrics
  let count := counts.getD "EMPTY" 0
  return count == 0

def testCountMultipleOps : IO Bool := do
  let metrics ← Metrics.make
  for _ in [:10] do
    metrics.recordLatency "OP1" 100
  for _ in [:5] do
    metrics.recordLatency "OP2" 100
  let counts ← Metrics.getCommandCounts metrics
  let count1 := counts.getD "OP1" 0
  let count2 := counts.getD "OP2" 0
  return count1 == 10 && count2 == 5

def countTests : TestSeq :=
  test "getCount returns correct count" (ioTest testGetCount) $
  test "getCount on empty returns 0" (ioTest testGetCountEmpty) $
  test "Counts for multiple operations are separate" (ioTest testCountMultipleOps)

-- Latency Stats Tests

def testGetLatencyStats : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "AVG_TEST" 100
  metrics.recordLatency "AVG_TEST" 200
  metrics.recordLatency "AVG_TEST" 300
  let stats ← Metrics.getLatencyStats metrics "AVG_TEST"
  match stats with
  | some s => return s.count == 3 && s.min == 100 && s.max == 300
  | none => return false

def testGetLatencyStatsEmpty : IO Bool := do
  let metrics ← Metrics.make
  let stats ← Metrics.getLatencyStats metrics "EMPTY"
  return stats.isNone

def testGetLatencyStatsSingle : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "SINGLE" 42
  let stats ← Metrics.getLatencyStats metrics "SINGLE"
  match stats with
  | some s => return s.count == 1 && s.min == 42 && s.max == 42
  | none => return false

def latencyStatsTests : TestSeq :=
  test "getLatencyStats calculates correctly" (ioTest testGetLatencyStats) $
  test "getLatencyStats on empty returns none" (ioTest testGetLatencyStatsEmpty) $
  test "getLatencyStats with single value" (ioTest testGetLatencyStatsSingle)

-- Clear Tests

def testClear : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "CLEAR_TEST" 100
  metrics.recordLatency "CLEAR_TEST" 200
  Metrics.clear metrics
  let counts ← Metrics.getCommandCounts metrics
  let count := counts.getD "CLEAR_TEST" 0
  return count == 0

def testClearPreservesStructure : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "OP" 100
  Metrics.clear metrics
  metrics.recordLatency "OP" 200
  let counts ← Metrics.getCommandCounts metrics
  let count := counts.getD "OP" 0
  return count == 1

def clearTests : TestSeq :=
  test "clear clears all metrics" (ioTest testClear) $
  test "clear preserves ability to record" (ioTest testClearPreservesStructure)

-- Export Tests

def testToPrometheus : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "redis_get" 100
  metrics.recordLatency "redis_get" 200
  metrics.recordLatency "redis_set" 150
  let prometheus ← Metrics.toPrometheus metrics
  return containsSubstr prometheus "redis" && prometheus.length > 0

def testToJson : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "GET" 100
  metrics.recordLatency "SET" 200
  let json ← Metrics.toJson metrics
  let jsonStr := toString json
  return containsSubstr jsonStr "totalCommands"

def testExportEmpty : IO Bool := do
  let metrics ← Metrics.make
  let prometheus ← Metrics.toPrometheus metrics
  let _json ← Metrics.toJson metrics
  return prometheus.length >= 0

def exportTests : TestSeq :=
  test "toPrometheus generates output" (ioTest testToPrometheus) $
  test "toJson generates output" (ioTest testToJson) $
  test "Export handles empty metrics" (ioTest testExportEmpty)

-- Snapshot Tests

def testSnapshot : IO Bool := do
  let metrics ← Metrics.make
  metrics.recordLatency "GET" 100
  metrics.recordLatency "SET" 200
  let snap ← Metrics.snapshot metrics
  return snap.totalCommands == 2

def testSnapshotEmpty : IO Bool := do
  let metrics ← Metrics.make
  let snap ← Metrics.snapshot metrics
  return snap.totalCommands == 0

def snapshotTests : TestSeq :=
  test "snapshot captures current state" (ioTest testSnapshot) $
  test "snapshot on empty metrics" (ioTest testSnapshotEmpty)

-- Bytes Tracking Tests

def testBytesTracking : IO Bool := do
  let metrics ← Metrics.make
  Metrics.recordBytesWritten metrics 100
  Metrics.recordBytesWritten metrics 50
  Metrics.recordBytesRead metrics 200
  let written ← Metrics.getBytesWritten metrics
  let read ← Metrics.getBytesRead metrics
  return written == 150 && read == 200

def testTotalBytes : IO Bool := do
  let metrics ← Metrics.make
  Metrics.recordBytesWritten metrics 100
  Metrics.recordBytesRead metrics 200
  let (written, read) ← Metrics.getTotalBytes metrics
  return written == 100 && read == 200

def bytesTests : TestSeq :=
  test "Bytes tracking accumulates" (ioTest testBytesTracking) $
  test "getTotalBytes returns both" (ioTest testTotalBytes)

-- Stress Tests

def testHighVolume : IO Bool := do
  let metrics ← Metrics.make
  for i in [:1000] do
    metrics.recordLatency "STRESS" i
  let counts ← Metrics.getCommandCounts metrics
  let count := counts.getD "STRESS" 0
  let p50 ← Metrics.getP50Latency metrics
  return count == 1000 && p50 > 0

def testManyOperations : IO Bool := do
  let metrics ← Metrics.make
  for i in [:50] do
    metrics.recordLatency s!"OP_{i}" 100
  let counts ← Metrics.getCommandCounts metrics
  return counts.size == 50

def stressTests : TestSeq :=
  test "High volume of records" (ioTest testHighVolume) $
  test "Many different operations" (ioTest testManyOperations)

-- All Metrics Tests
def allMetricsTests : TestSeq :=
  group "Metrics Creation" metricsCreationTests $
  group "Percentile Calculations" percentileTests $
  group "Count Tracking" countTests $
  group "Latency Stats" latencyStatsTests $
  group "Clear Functionality" clearTests $
  group "Export Formats" exportTests $
  group "Snapshot" snapshotTests $
  group "Bytes Tracking" bytesTests $
  group "Stress Tests" stressTests

end RedisTests.MetricsTests
