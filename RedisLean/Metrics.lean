import Std.Data.HashMap
import RedisLean.Log

namespace RedisLean

structure LatencyStats where
  count : Nat
  min : Nat
  max : Nat
  avg : Float
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

namespace Metrics

def make : IO Metrics := do
  let latency ← IO.mkRef (Std.HashMap.emptyWithCapacity 32)
  let counts ← IO.mkRef (Std.HashMap.emptyWithCapacity 32)
  let errors ← IO.mkRef (Std.HashMap.emptyWithCapacity 16)
  let events ← IO.mkRef #[]
  pure { latencyBuckets := latency, commandCounts := counts, errorCounts := errors, connectionEvents := events }

-- record latency for a command
def recordLatency (m : Metrics) (cmd : String) (microseconds : Nat) : IO Unit := do
  m.latencyBuckets.modify fun h =>
    h.insert cmd ((h.getD cmd #[]).push microseconds)
  m.commandCounts.modify fun h =>
    h.insert cmd ((h.getD cmd 0) + 1)

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

def clear (m : Metrics) : IO Unit := do
  m.latencyBuckets.set (Std.HashMap.emptyWithCapacity 32)
  m.commandCounts.set (Std.HashMap.emptyWithCapacity 32)
  m.errorCounts.set (Std.HashMap.emptyWithCapacity 16)
  m.connectionEvents.set #[]

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

  let errors ← getErrorCounts m
  if not errors.isEmpty then
    Log.info "Error Counts:"
    for (errType, count) in errors.toList do
      Log.error s!"  {errType}: {count}"

end Metrics

end RedisLean
