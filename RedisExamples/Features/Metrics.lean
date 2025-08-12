import RedisLean.Metrics
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesMetricsExample

open Redis

/-!
# Metrics and Observability Examples

Demonstrates the metrics and tracing capabilities:
- Command latency tracking
- Error counting
- Percentile calculations (P50, P95, P99)
- Prometheus export
- JSON export
- Slow command detection
-/

/-- Example: Basic latency recording -/
def exBasicLatency : IO Unit := do
  Log.info "Example: Basic latency recording"

  let metrics ← Metrics.make

  -- Record some command latencies (in microseconds)
  metrics.recordLatency "GET" 150
  metrics.recordLatency "GET" 200
  metrics.recordLatency "GET" 180
  metrics.recordLatency "SET" 250
  metrics.recordLatency "SET" 300

  -- Get latency statistics
  let getStats ← metrics.getLatencyStats "GET"
  match getStats with
  | some stats =>
    Log.info s!"GET latency stats:"
    Log.info s!"  Count: {stats.count}"
    Log.info s!"  Min: {stats.min}μs"
    Log.info s!"  Max: {stats.max}μs"
    Log.info s!"  Avg: {stats.avg}μs"
  | none =>
    Log.info "No GET stats available"

/-- Example: Error tracking -/
def exErrorTracking : IO Unit := do
  Log.info "Example: Error tracking"

  let metrics ← Metrics.make

  -- Record some errors
  metrics.recordError "ConnectionTimeout"
  metrics.recordError "ConnectionTimeout"
  metrics.recordError "CommandFailed"
  metrics.recordError "AuthenticationError"

  -- Get error counts
  let errors ← metrics.getErrorCounts
  Log.info "Error counts:"
  for (errType, count) in errors.toList do
    Log.info s!"  {errType}: {count}"

/-- Example: Percentile latencies -/
def exPercentileLatencies : IO Unit := do
  Log.info "Example: Percentile latencies"

  let metrics ← Metrics.make

  -- Simulate realistic latency distribution
  let latencies := [
    50, 55, 60, 65, 70,      -- Fast responses
    100, 110, 120, 130, 140, -- Normal responses
    200, 250, 300,           -- Slower responses
    500, 1000                -- Outliers
  ]

  for lat in latencies do
    metrics.recordLatency "HGET" lat

  -- Calculate percentiles
  let p50 ← metrics.getP50Latency
  let p95 ← metrics.getP95Latency
  let p99 ← metrics.getP99Latency

  Log.info s!"Percentile latencies (microseconds):"
  Log.info s!"  P50 (median): {p50}μs"
  Log.info s!"  P95: {p95}μs"
  Log.info s!"  P99: {p99}μs"

/-- Example: Command tracing -/
def exCommandTracing : IO Unit := do
  Log.info "Example: Command tracing"

  let metrics ← Metrics.make

  -- Configure tracing
  metrics.setMaxTraces 100

  -- Simulate traced commands
  let simulateCommand (name : String) (durationMs : Nat) (success : Bool) : IO Unit := do
    let startNs ← IO.monoNanosNow
    IO.sleep (UInt32.ofNat durationMs)
    let endNs ← IO.monoNanosNow
    let errorMsg := if success then none else some "Command failed"
    metrics.recordTrace name startNs endNs success errorMsg [("key", "test:key")]

  -- Execute some traced operations
  simulateCommand "SET" 5 true
  simulateCommand "GET" 3 true
  simulateCommand "HGET" 4 true
  simulateCommand "ZADD" 10 false  -- Simulated failure

  -- Get recent traces
  let traces ← metrics.getRecentTraces 10
  Log.info s!"Recent traces ({traces.size}):"
  for trace in traces do
    let status := if trace.success then "OK" else "FAILED"
    Log.info s!"  [{status}] {trace.command}: {trace.durationUs}μs"

/-- Example: withTrace helper -/
def exWithTrace : IO Unit := do
  Log.info "Example: withTrace helper"

  let metrics ← Metrics.make

  -- Use withTrace for automatic tracing
  let result ← metrics.withTrace "expensive_operation" [("type", "computation")] do
    IO.sleep 20  -- Simulate work
    return 42

  match result with
  | .ok value => Log.info s!"Operation succeeded: {value}"
  | .error msg => Log.info s!"Operation failed: {msg}"

  -- Check the trace was recorded
  let traces ← metrics.getRecentTraces 1
  for trace in traces do
    Log.info s!"Traced: {trace.command}, duration: {trace.durationMs}ms"

/-- Example: Slow command detection -/
def exSlowCommands : IO Unit := do
  Log.info "Example: Slow command detection"

  let metrics ← Metrics.make

  -- Set slow command threshold to 100ms
  metrics.setSlowThreshold 100

  -- Record various latencies (in microseconds)
  metrics.recordLatency "FAST_GET" 50000     -- 50ms - normal
  metrics.recordLatency "FAST_SET" 80000     -- 80ms - normal
  metrics.recordLatency "SLOW_SCAN" 150000   -- 150ms - SLOW
  metrics.recordLatency "SLOW_KEYS" 200000   -- 200ms - SLOW
  metrics.recordLatency "SLOW_SORT" 500000   -- 500ms - SLOW

  -- Get slow commands
  let slowCmds ← metrics.getSlowCommands 10
  Log.info s!"Slow commands detected ({slowCmds.size}):"
  for (cmd, durationUs) in slowCmds do
    Log.info s!"  {cmd}: {durationUs / 1000}ms"

/-- Example: Bytes tracking -/
def exBytesTracking : IO Unit := do
  Log.info "Example: Bytes tracking"

  let metrics ← Metrics.make

  -- Record bytes written and read
  metrics.recordBytesWritten 1024
  metrics.recordBytesWritten 2048
  metrics.recordBytesRead 512
  metrics.recordBytesRead 1024

  let (written, read) ← metrics.getTotalBytes
  Log.info s!"Bytes transferred:"
  Log.info s!"  Written: {written} bytes"
  Log.info s!"  Read: {read} bytes"
  Log.info s!"  Total: {written + read} bytes"

/-- Example: Metrics snapshot -/
def exMetricsSnapshot : IO Unit := do
  Log.info "Example: Metrics snapshot"

  let metrics ← Metrics.make

  -- Generate some activity
  for _ in List.range 10 do
    metrics.recordLatency "GET" 100
    metrics.recordLatency "SET" 150
  metrics.recordError "Timeout"
  metrics.recordBytesWritten 5000
  metrics.recordBytesRead 3000

  -- Take a snapshot
  let snap ← metrics.snapshot
  Log.info s!"Metrics snapshot:"
  Log.info s!"  Total commands: {snap.totalCommands}"
  Log.info s!"  Total errors: {snap.totalErrors}"
  Log.info s!"  Avg latency: {snap.avgLatencyMs}ms"
  Log.info s!"  P99 latency: {snap.p99LatencyUs}μs"
  Log.info s!"  Bytes written: {snap.bytesWritten}"
  Log.info s!"  Bytes read: {snap.bytesRead}"

/-- Example: Prometheus export -/
def exPrometheusExport : IO Unit := do
  Log.info "Example: Prometheus export"

  let metrics ← Metrics.make

  -- Generate activity
  metrics.recordLatency "GET" 100
  metrics.recordLatency "GET" 150
  metrics.recordLatency "SET" 200
  metrics.recordError "ConnectionError"
  metrics.recordBytesWritten 1024
  metrics.recordBytesRead 512

  -- Export as Prometheus format
  let prometheus ← metrics.toPrometheus
  Log.info "Prometheus metrics:"
  for line in prometheus.splitOn "\n" do
    if not (line.startsWith "#") && line.length > 0 then
      Log.info s!"  {line}"

/-- Example: JSON export -/
def exJsonExport : IO Unit := do
  Log.info "Example: JSON export"

  let metrics ← Metrics.make

  -- Generate activity
  metrics.recordLatency "HGET" 80
  metrics.recordLatency "HSET" 120
  metrics.recordBytesWritten 2048

  -- Export as JSON
  let json ← metrics.toJson
  Log.info s!"JSON metrics: {json.compress}"

/-- Example: Print summary -/
def exPrintSummary : IO Unit := do
  Log.info "Example: Print summary"

  let metrics ← Metrics.make

  -- Generate comprehensive activity
  for i in List.range 50 do
    metrics.recordLatency "GET" (100 + i * 10)
  for i in List.range 30 do
    metrics.recordLatency "SET" (150 + i * 15)
  metrics.recordError "Timeout"
  metrics.recordError "ConnectionLost"
  metrics.recordBytesWritten 10000
  metrics.recordBytesRead 8000

  -- Set low threshold to capture "slow" commands
  metrics.setSlowThreshold 1  -- 1ms threshold

  -- Print formatted summary
  metrics.printSummary

/-- Run all metrics examples -/
def runAllExamples : IO Unit := do
  Log.info "=== Metrics Examples ==="
  exBasicLatency
  exErrorTracking
  exPercentileLatencies
  exCommandTracing
  exWithTrace
  exSlowCommands
  exBytesTracking
  exMetricsSnapshot
  exPrometheusExport
  exJsonExport
  exPrintSummary
  Log.info "=== Metrics Examples Complete ==="

end FeaturesMetricsExample
