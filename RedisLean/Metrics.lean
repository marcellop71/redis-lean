import Std.Data.HashMap
import Lean.Data.Json
import RedisLean.Log

namespace Redis

structure LatencyStats where
  count : Nat
  min : Nat
  max : Nat
  avg : Float
  deriving Repr

/-- Trace record for individual command execution -/
structure Trace where
  /-- Unique trace identifier -/
  traceId : String
  /-- Command name -/
  command : String
  /-- Start time in nanoseconds -/
  startTimeNs : Nat
  /-- End time in nanoseconds -/
  endTimeNs : Nat
  /-- Additional tags for filtering/grouping -/
  tags : List (String × String)
  /-- Whether the command succeeded -/
  success : Bool
  /-- Error message if failed -/
  errorMsg : Option String
  deriving Repr

namespace Trace

/-- Get duration in microseconds -/
def durationUs (t : Trace) : Nat :=
  (t.endTimeNs - t.startTimeNs) / 1000

/-- Get duration in milliseconds -/
def durationMs (t : Trace) : Nat :=
  (t.endTimeNs - t.startTimeNs) / 1000000

/-- Check if this trace represents a slow command (> threshold ms) -/
def isSlow (t : Trace) (thresholdMs : Nat) : Bool :=
  t.durationMs > thresholdMs

end Trace

/-- Metrics snapshot at a point in time -/
structure MetricsSnapshot where
  /-- Timestamp in nanoseconds -/
  timestamp : Nat
  /-- Total commands executed -/
  totalCommands : Nat
  /-- Total errors -/
  totalErrors : Nat
  /-- Average latency in milliseconds -/
  avgLatencyMs : Float
  /-- P99 latency in microseconds -/
  p99LatencyUs : Nat
  /-- Total bytes written -/
  bytesWritten : Nat
  /-- Total bytes read -/
  bytesRead : Nat
  deriving Repr

/-- How many recent latency samples to keep per command, for percentiles.
Running totals (count/sum/min/max) are exact and unbounded; only the sample
window is capped. -/
def maxLatencySamples : Nat := 1024

/-- How many recent slow-command records and connection events to retain. -/
def maxRetainedEvents : Nat := 256

/-- Per-command latency state: exact running totals plus a bounded ring of
recent samples.

The previous version appended every latency to an unbounded `Array Nat` and
re-sorted the whole history on each percentile query, so a long-lived process
grew without limit and got steadily slower at reporting. -/
structure LatencyAgg where
  count : Nat := 0
  sum : Nat := 0
  min : Nat := 0
  max : Nat := 0
  /-- Ring buffer of the most recent samples; at most `maxLatencySamples`. -/
  samples : Array Nat := #[]
  /-- Next write position within `samples` once it is full. -/
  cursor : Nat := 0
  deriving Repr, Inhabited

namespace LatencyAgg

/-- Record one sample in microseconds. -/
def push (a : LatencyAgg) (us : Nat) : LatencyAgg :=
  let samples := if a.samples.size < maxLatencySamples
    then a.samples.push us
    else a.samples.set! a.cursor us
  { count := a.count + 1
    sum := a.sum + us
    min := if a.count == 0 then us else Nat.min a.min us
    max := Nat.max a.max us
    samples := samples
    cursor := if a.samples.size < maxLatencySamples then 0 else (a.cursor + 1) % maxLatencySamples }

end LatencyAgg

/-- Append to a bounded array, dropping the oldest entry when full. -/
private def pushBounded (xs : Array α) (x : α) (cap : Nat) : Array α :=
  let xs := xs.push x
  if xs.size > cap then xs.extract (xs.size - cap) xs.size else xs

-- metrics collection for Redis operations
structure Metrics where
  -- per-command latency aggregates (microseconds)
  latencyBuckets : IO.Ref (Std.HashMap String LatencyAgg)
  -- command counters (command name -> count)
  commandCounts : IO.Ref (Std.HashMap String Nat)
  -- error counts (error type -> count)
  errorCounts : IO.Ref (Std.HashMap String Nat)
  -- connection events (event_type, timestamp_us)
  connectionEvents : IO.Ref (Array (String × Nat))
  -- traces (recent command traces)
  traces : IO.Ref (Array Trace)
  -- bytes written
  bytesWritten : IO.Ref Nat
  -- bytes read
  bytesRead : IO.Ref Nat
  -- slow commands (command name, duration_us) for commands exceeding threshold
  slowCommands : IO.Ref (Array (String × Nat))
  -- slow command threshold in milliseconds
  slowThresholdMs : IO.Ref Nat
  -- maximum traces to retain
  maxTraces : IO.Ref Nat

namespace Metrics

def make : IO Metrics := do
  let latency ← IO.mkRef (Std.HashMap.emptyWithCapacity 32)
  let counts ← IO.mkRef (Std.HashMap.emptyWithCapacity 32)
  let errors ← IO.mkRef (Std.HashMap.emptyWithCapacity 16)
  let events ← IO.mkRef #[]
  let traces ← IO.mkRef #[]
  let bytesWritten ← IO.mkRef 0
  let bytesRead ← IO.mkRef 0
  let slowCommands ← IO.mkRef #[]
  let slowThresholdMs ← IO.mkRef 100  -- default 100ms
  let maxTraces ← IO.mkRef 1000  -- default keep last 1000 traces
  pure {
    latencyBuckets := latency,
    commandCounts := counts,
    errorCounts := errors,
    connectionEvents := events,
    traces,
    bytesWritten,
    bytesRead,
    slowCommands,
    slowThresholdMs,
    maxTraces
  }

-- record latency for a command
def recordLatency (m : Metrics) (cmd : String) (microseconds : Nat) : IO Unit := do
  m.latencyBuckets.modify fun h =>
    h.insert cmd ((h.getD cmd {}).push microseconds)
  m.commandCounts.modify fun h =>
    h.insert cmd ((h.getD cmd 0) + 1)
  -- Check if this is a slow command
  let threshold ← m.slowThresholdMs.get
  if microseconds > threshold * 1000 then
    m.slowCommands.modify (pushBounded · (cmd, microseconds) maxRetainedEvents)

/-- Record an error occurrence.

`errorType` must be a low-cardinality label -- use `Redis.Error.kind`, not
`toString`, or the map grows one entry per distinct key or server message. -/
def recordError (m : Metrics) (errorType : String) : IO Unit := do
  m.errorCounts.modify fun h =>
    h.insert errorType ((h.getD errorType 0) + 1)

-- record a connection event
def recordEvent (m : Metrics) (eventType : String) : IO Unit := do
  let now ← IO.monoNanosNow
  let nowUs := now / 1000
  m.connectionEvents.modify (pushBounded · (eventType, nowUs) maxRetainedEvents)

-- record bytes written
def recordBytesWritten (m : Metrics) (bytes : Nat) : IO Unit := do
  m.bytesWritten.modify (· + bytes)

-- record bytes read
def recordBytesRead (m : Metrics) (bytes : Nat) : IO Unit := do
  m.bytesRead.modify (· + bytes)

-- generate a unique trace ID
private def generateTraceId : IO String := do
  let timestamp ← IO.monoNanosNow
  let random ← IO.rand 0 999999
  return s!"trace-{timestamp}-{random}"

-- record a trace
def recordTrace (m : Metrics) (cmd : String) (startNs endNs : Nat)
    (success : Bool) (errorMsg : Option String := none)
    (tags : List (String × String) := []) : IO Unit := do
  let traceId ← generateTraceId
  let trace : Trace := {
    traceId,
    command := cmd,
    startTimeNs := startNs,
    endTimeNs := endNs,
    tags,
    success,
    errorMsg
  }
  let maxTraces ← m.maxTraces.get
  m.traces.modify fun traces =>
    let newTraces := traces.push trace
    if newTraces.size > maxTraces then
      newTraces.extract (newTraces.size - maxTraces) newTraces.size
    else
      newTraces

-- execute an action with tracing
def withTrace (m : Metrics) (name : String) (tags : List (String × String) := [])
    (action : IO α) : IO (Except String α) := do
  let startNs ← IO.monoNanosNow
  try
    let result ← action
    let endNs ← IO.monoNanosNow
    recordTrace m name startNs endNs true none tags
    let durationUs := (endNs - startNs) / 1000
    recordLatency m name durationUs
    return .ok result
  catch e =>
    let endNs ← IO.monoNanosNow
    recordTrace m name startNs endNs false (some (toString e)) tags
    recordError m (toString e)
    return .error (toString e)

def getLatencyStats (m : Metrics) (cmd : String) : IO (Option LatencyStats) := do
  let buckets ← m.latencyBuckets.get
  match buckets.get? cmd with
  | none => return none
  | some agg =>
    if agg.count == 0 then return none
    else
      return some { count := agg.count, min := agg.min, max := agg.max,
                    avg := Float.ofNat agg.sum / Float.ofNat agg.count }

-- calculate percentile latency
/-- Percentile over the retained sample window (at most `maxLatencySamples`
per command), not over all history. -/
def getPercentileLatency (m : Metrics) (percentile : Nat) : IO Nat := do
  let buckets ← m.latencyBuckets.get
  let mut allLatencies : Array Nat := #[]
  for (_, agg) in buckets.toList do
    allLatencies := allLatencies ++ agg.samples
  if allLatencies.size == 0 then return 0
  let sorted := allLatencies.qsort (· < ·)
  let idx := (sorted.size * percentile) / 100
  let safeIdx := min idx (sorted.size - 1)
  return sorted[safeIdx]!

-- get P99 latency
def getP99Latency (m : Metrics) : IO Nat :=
  getPercentileLatency m 99

-- get P95 latency
def getP95Latency (m : Metrics) : IO Nat :=
  getPercentileLatency m 95

-- get P50 latency (median)
def getP50Latency (m : Metrics) : IO Nat :=
  getPercentileLatency m 50

def getCommandCounts (m : Metrics) : IO (Std.HashMap String Nat) :=
  m.commandCounts.get

def getErrorCounts (m : Metrics) : IO (Std.HashMap String Nat) :=
  m.errorCounts.get

def getRecentEvents (m : Metrics) (lastN : Nat := 100) : IO (Array (String × Nat)) := do
  let events ← m.connectionEvents.get
  let totalEvents := events.size
  if totalEvents <= lastN then
    return events
  else
    return events.extract (totalEvents - lastN) totalEvents

def getRecentTraces (m : Metrics) (lastN : Nat := 100) : IO (Array Trace) := do
  let traces ← m.traces.get
  let totalTraces := traces.size
  if totalTraces <= lastN then
    return traces
  else
    return traces.extract (totalTraces - lastN) totalTraces

def getSlowCommands (m : Metrics) (lastN : Nat := 100) : IO (Array (String × Nat)) := do
  let slow ← m.slowCommands.get
  let total := slow.size
  if total <= lastN then
    return slow
  else
    return slow.extract (total - lastN) total

def getBytesWritten (m : Metrics) : IO Nat :=
  m.bytesWritten.get

def getBytesRead (m : Metrics) : IO Nat :=
  m.bytesRead.get

def getTotalBytes (m : Metrics) : IO (Nat × Nat) := do
  let written ← m.bytesWritten.get
  let read ← m.bytesRead.get
  return (written, read)

def setSlowThreshold (m : Metrics) (thresholdMs : Nat) : IO Unit :=
  m.slowThresholdMs.set thresholdMs

def setMaxTraces (m : Metrics) (max : Nat) : IO Unit :=
  m.maxTraces.set max

def clear (m : Metrics) : IO Unit := do
  m.latencyBuckets.set (Std.HashMap.emptyWithCapacity 32)
  m.commandCounts.set (Std.HashMap.emptyWithCapacity 32)
  m.errorCounts.set (Std.HashMap.emptyWithCapacity 16)
  m.connectionEvents.set #[]
  m.traces.set #[]
  m.bytesWritten.set 0
  m.bytesRead.set 0
  m.slowCommands.set #[]

-- create a snapshot of current metrics
def snapshot (m : Metrics) : IO MetricsSnapshot := do
  let timestamp ← IO.monoNanosNow
  let counts ← m.commandCounts.get
  let totalCommands := counts.toList.foldl (fun acc (_, c) => acc + c) 0
  let errors ← m.errorCounts.get
  let totalErrors := errors.toList.foldl (fun acc (_, c) => acc + c) 0
  -- Calculate average latency
  let buckets ← m.latencyBuckets.get
  let mut totalLatency : Nat := 0
  let mut latencyCount : Nat := 0
  for (_, agg) in buckets.toList do
    totalLatency := totalLatency + agg.sum
    latencyCount := latencyCount + agg.count
  let avgLatencyMs := if latencyCount > 0
    then Float.ofNat totalLatency / Float.ofNat latencyCount / 1000.0
    else 0.0
  let p99 ← getP99Latency m
  let bytesWritten ← m.bytesWritten.get
  let bytesRead ← m.bytesRead.get
  return {
    timestamp,
    totalCommands,
    totalErrors,
    avgLatencyMs,
    p99LatencyUs := p99,
    bytesWritten,
    bytesRead
  }

/-- Escape a Prometheus label value: backslash, double quote and newline.

Label values reach here from command names and error kinds; without escaping a
stray quote produces an exposition body the scraper rejects. -/
private def escapeLabel (s : String) : String :=
  s.foldl (init := "") fun acc c =>
    match c with
    | '\\' => acc ++ "\\\\"
    | '"'  => acc ++ "\\\""
    | '\n' => acc ++ "\\n"
    | c    => acc.push c

-- export metrics in Prometheus format
def toPrometheus (m : Metrics) : IO String := do
  let mut lines : Array String := #[]

  -- Command counts
  let counts ← m.commandCounts.get
  lines := lines.push "# HELP redis_command_total Total number of Redis commands executed"
  lines := lines.push "# TYPE redis_command_total counter"
  for (cmd, count) in counts.toList do
    lines := lines.push s!"redis_command_total\{command=\"{escapeLabel cmd}\"} {count}"

  -- Error counts
  let errors ← m.errorCounts.get
  lines := lines.push "# HELP redis_error_total Total number of Redis errors"
  lines := lines.push "# TYPE redis_error_total counter"
  for (errType, count) in errors.toList do
    lines := lines.push s!"redis_error_total\{error_type=\"{escapeLabel errType}\"} {count}"

  -- Latency stats
  lines := lines.push "# HELP redis_command_latency_microseconds Command latency in microseconds"
  lines := lines.push "# TYPE redis_command_latency_microseconds summary"
  let buckets ← m.latencyBuckets.get
  for (cmd, _) in buckets.toList do
    let stats ← getLatencyStats m cmd
    match stats with
    | some s =>
      lines := lines.push s!"redis_command_latency_microseconds\{command=\"{escapeLabel cmd}\",quantile=\"0.5\"} {s.avg}"
      lines := lines.push s!"redis_command_latency_microseconds\{command=\"{escapeLabel cmd}\",quantile=\"1\"} {s.max}"
      lines := lines.push s!"redis_command_latency_microseconds_count\{command=\"{escapeLabel cmd}\"} {s.count}"
    | none => pure ()

  -- Bytes transferred
  let bytesWritten ← m.bytesWritten.get
  let bytesRead ← m.bytesRead.get
  -- NOTE: the byte counters are caller-driven. The library does not populate
  -- them automatically (the FFI does not surface wire sizes), so these stay at
  -- zero unless you call `recordBytesWritten`/`recordBytesRead` yourself.
  lines := lines.push "# HELP redis_bytes_written_total Total bytes written to Redis (caller-recorded)"
  lines := lines.push "# TYPE redis_bytes_written_total counter"
  lines := lines.push s!"redis_bytes_written_total {bytesWritten}"
  lines := lines.push "# HELP redis_bytes_read_total Total bytes read from Redis"
  lines := lines.push "# TYPE redis_bytes_read_total counter"
  lines := lines.push s!"redis_bytes_read_total {bytesRead}"

  return String.intercalate "\n" lines.toList

-- export metrics as JSON
def toJson (m : Metrics) : IO Lean.Json := do
  let snap ← snapshot m
  let counts ← m.commandCounts.get
  let errors ← m.errorCounts.get
  let p95 ← getP95Latency m
  let p50 ← getP50Latency m

  let commandCountsJson := Lean.Json.mkObj (counts.toList.map fun (k, v) => (k, Lean.Json.num v))
  let errorCountsJson := Lean.Json.mkObj (errors.toList.map fun (k, v) => (k, Lean.Json.num v))

  -- Convert avgLatencyMs Float to integer microseconds for JSON compatibility
  let avgLatencyUs := snap.avgLatencyMs * 1000.0

  return Lean.Json.mkObj [
    ("timestamp", Lean.Json.num snap.timestamp),
    ("totalCommands", Lean.Json.num snap.totalCommands),
    ("totalErrors", Lean.Json.num snap.totalErrors),
    ("avgLatencyUs", Lean.Json.num avgLatencyUs.toUInt64.toNat),
    ("p50LatencyUs", Lean.Json.num p50),
    ("p95LatencyUs", Lean.Json.num p95),
    ("p99LatencyUs", Lean.Json.num snap.p99LatencyUs),
    ("bytesWritten", Lean.Json.num snap.bytesWritten),
    ("bytesRead", Lean.Json.num snap.bytesRead),
    ("commandCounts", commandCountsJson),
    ("errorCounts", errorCountsJson)
  ]

def printSummary (m : Metrics) : IO Unit := do
  Log.info "=== Redis Metrics Summary ==="

  let counts ← getCommandCounts m
  Log.info "Command Counts:"
  for (cmd, count) in counts.toList do
    Log.info s!"  {cmd}: {count}"

  Log.info "Latency Statistics (microseconds):"
  for (cmd, _) in counts.toList do
    let stats ← getLatencyStats m cmd
    match stats with
    | some s =>
      Log.info s!"  {cmd}: avg={s.avg}μs, min={s.min}μs, max={s.max}μs, count={s.count}"
    | none => Log.info s!"  {cmd}: no latency data"

  let p50 ← getP50Latency m
  let p95 ← getP95Latency m
  let p99 ← getP99Latency m
  Log.info s!"Percentile Latencies: p50={p50}μs, p95={p95}μs, p99={p99}μs"

  let (bytesWritten, bytesRead) ← getTotalBytes m
  Log.info s!"Bytes Transferred: written={bytesWritten}, read={bytesRead}"

  let errors ← getErrorCounts m
  if not errors.isEmpty then
    Log.info "Error Counts:"
    for (errType, count) in errors.toList do
      Log.error s!"  {errType}: {count}"

  let slow ← getSlowCommands m 10
  if not slow.isEmpty then
    Log.info "Recent Slow Commands:"
    for (cmd, durationUs) in slow.toList do
      Log.info s!"  {cmd}: {durationUs}μs"

end Metrics

end Redis
