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

-- metrics collection for Redis operations
structure Metrics where
  -- command latency buckets (command name -> array of latencies in microseconds)
  latencyBuckets : IO.Ref (Std.HashMap String (Array Nat))
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
    h.insert cmd ((h.getD cmd #[]).push microseconds)
  m.commandCounts.modify fun h =>
    h.insert cmd ((h.getD cmd 0) + 1)
  -- Check if this is a slow command
  let threshold ← m.slowThresholdMs.get
  if microseconds > threshold * 1000 then
    m.slowCommands.modify (·.push (cmd, microseconds))

-- record an error
def recordError (m : Metrics) (errorType : String) : IO Unit := do
  m.errorCounts.modify fun h =>
    h.insert errorType ((h.getD errorType 0) + 1)

-- record a connection event
def recordEvent (m : Metrics) (eventType : String) : IO Unit := do
  let now ← IO.monoNanosNow
  let nowUs := now / 1000
  m.connectionEvents.modify fun events =>
    events.push (eventType, nowUs)

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
  | some times =>
    if times.size == 0 then return none
    else
      let min := times.foldl Nat.min times[0]!
      let max := times.foldl Nat.max 0
      let sum := times.foldl (·+·) 0
      let avg := (Float.ofNat sum / Float.ofNat times.size)
      return some { count := times.size, min, max, avg }

-- calculate percentile latency
def getPercentileLatency (m : Metrics) (percentile : Nat) : IO Nat := do
  let buckets ← m.latencyBuckets.get
  let mut allLatencies : Array Nat := #[]
  for (_, times) in buckets.toList do
    allLatencies := allLatencies ++ times
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
  for (_, times) in buckets.toList do
    totalLatency := totalLatency + times.foldl (·+·) 0
    latencyCount := latencyCount + times.size
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

-- export metrics in Prometheus format
def toPrometheus (m : Metrics) : IO String := do
  let mut lines : Array String := #[]

  -- Command counts
  let counts ← m.commandCounts.get
  lines := lines.push "# HELP redis_command_total Total number of Redis commands executed"
  lines := lines.push "# TYPE redis_command_total counter"
  for (cmd, count) in counts.toList do
    lines := lines.push s!"redis_command_total\{command=\"{cmd}\"} {count}"

  -- Error counts
  let errors ← m.errorCounts.get
  lines := lines.push "# HELP redis_error_total Total number of Redis errors"
  lines := lines.push "# TYPE redis_error_total counter"
  for (errType, count) in errors.toList do
    lines := lines.push s!"redis_error_total\{error_type=\"{errType}\"} {count}"

  -- Latency stats
  lines := lines.push "# HELP redis_command_latency_microseconds Command latency in microseconds"
  lines := lines.push "# TYPE redis_command_latency_microseconds summary"
  let buckets ← m.latencyBuckets.get
  for (cmd, _) in buckets.toList do
    let stats ← getLatencyStats m cmd
    match stats with
    | some s =>
      lines := lines.push s!"redis_command_latency_microseconds\{command=\"{cmd}\",quantile=\"0.5\"} {s.avg}"
      lines := lines.push s!"redis_command_latency_microseconds\{command=\"{cmd}\",quantile=\"1\"} {s.max}"
      lines := lines.push s!"redis_command_latency_microseconds_count\{command=\"{cmd}\"} {s.count}"
    | none => pure ()

  -- Bytes transferred
  let bytesWritten ← m.bytesWritten.get
  let bytesRead ← m.bytesRead.get
  lines := lines.push "# HELP redis_bytes_written_total Total bytes written to Redis"
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
