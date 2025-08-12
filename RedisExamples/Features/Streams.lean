import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesStreamsExample

open Redis

/-!
# Redis Streams Examples

Demonstrates Redis Streams for:
- Event sourcing
- Message queues with persistence
- Activity logs
- Real-time data processing
-/

/-- Example: Basic stream operations -/
def exBasicStream : RedisM Unit := do
  Log.info "Example: Basic stream operations"

  let key := "stream:basic"

  -- Add entries to stream (auto-generate ID with "*")
  let id1 ← xadd key "*" [("field1", "value1"), ("field2", "value2")]
  Log.info s!"Added entry with ID: {id1}"

  let id2 ← xadd key "*" [("action", "click"), ("button", "submit")]
  Log.info s!"Added entry with ID: {id2}"

  let id3 ← xadd key "*" [("event", "pageview"), ("page", "/home")]
  Log.info s!"Added entry with ID: {id3}"

  -- Get stream length
  let len ← xlen key
  Log.info s!"Stream length: {len}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Reading stream entries -/
def exReadStream : RedisM Unit := do
  Log.info "Example: Reading stream entries"

  let key := "stream:read"

  -- Add some entries
  let _ ← xadd key "*" [("msg", "first")]
  let _ ← xadd key "*" [("msg", "second")]
  let _ ← xadd key "*" [("msg", "third")]

  -- Read entries in range (all entries)
  let entries ← xrange key "-" "+" none
  Log.info s!"All entries: {String.fromUTF8! entries}"

  -- Read with count limit
  let limited ← xrange key "-" "+" (some 2)
  Log.info s!"First 2 entries: {String.fromUTF8! limited}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Event sourcing pattern -/
def exEventSourcing : RedisM Unit := do
  Log.info "Example: Event sourcing pattern"

  let streamKey := "events:orders"

  -- Record order events
  let _ ← xadd streamKey "*" [
    ("event_type", "order_created"),
    ("order_id", "ORD-001"),
    ("customer", "john@example.com"),
    ("total", "99.99")
  ]

  let _ ← xadd streamKey "*" [
    ("event_type", "payment_received"),
    ("order_id", "ORD-001"),
    ("payment_method", "credit_card"),
    ("amount", "99.99")
  ]

  let _ ← xadd streamKey "*" [
    ("event_type", "order_shipped"),
    ("order_id", "ORD-001"),
    ("tracking_number", "TRK123456"),
    ("carrier", "USPS")
  ]

  Log.info "Order events recorded"

  -- Read all events
  let events ← xrange streamKey "-" "+" none
  Log.info s!"Order history: {String.fromUTF8! events}"

  -- Get event count
  let eventCount ← xlen streamKey
  Log.info s!"Total events: {eventCount}"

  -- Cleanup
  let _ ← del [streamKey]

/-- Example: Activity log -/
def exActivityLog : RedisM Unit := do
  Log.info "Example: Activity log"

  let logKey := "log:user:activities"

  -- Log user activities
  let activities := [
    [("action", "login"), ("ip", "192.168.1.1")],
    [("action", "view_profile"), ("profile_id", "123")],
    [("action", "update_settings"), ("setting", "notifications")],
    [("action", "send_message"), ("recipient", "user456")],
    [("action", "logout"), ("ip", "192.168.1.1")]
  ]

  for activity in activities do
    let _ ← xadd logKey "*" activity

  Log.info s!"Logged {activities.length} activities"

  -- Read recent activities
  let recent ← xrange logKey "-" "+" (some 3)
  Log.info s!"Recent activities: {String.fromUTF8! recent}"

  -- Cleanup
  let _ ← del [logKey]

/-- Example: Stream trimming -/
def exStreamTrimming : RedisM Unit := do
  Log.info "Example: Stream trimming"

  let key := "stream:trim"

  -- Add many entries
  for i in List.range 20 do
    let _ ← xadd key "*" [("idx", s!"{i}")]

  let beforeLen ← xlen key
  Log.info s!"Entries before trim: {beforeLen}"

  -- Trim to keep only last 5 entries
  let trimmed ← xtrim key "MAXLEN" 5
  Log.info s!"Trimmed {trimmed} entries"

  let afterLen ← xlen key
  Log.info s!"Entries after trim: {afterLen}"

  -- Read remaining entries
  let remaining ← xrange key "-" "+" none
  Log.info s!"Remaining: {String.fromUTF8! remaining}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Deleting specific entries -/
def exDeleteEntries : RedisM Unit := do
  Log.info "Example: Deleting specific entries"

  let key := "stream:delete"

  -- Add entries and capture IDs
  let id1 ← xadd key "*" [("data", "entry1")]
  let id2 ← xadd key "*" [("data", "entry2")]
  let id3 ← xadd key "*" [("data", "entry3")]

  Log.info s!"Added entries: {id1}, {id2}, {id3}"

  let beforeLen ← xlen key
  Log.info s!"Length before delete: {beforeLen}"

  -- Delete middle entry
  let deleted ← xdel key [id2]
  Log.info s!"Deleted {deleted} entry (ID: {id2})"

  let afterLen ← xlen key
  Log.info s!"Length after delete: {afterLen}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Sensor data stream -/
def exSensorData : RedisM Unit := do
  Log.info "Example: Sensor data stream"

  let sensorKey := "stream:sensor:temp"

  -- Simulate temperature readings
  let readings := [
    ("22.5", "normal"),
    ("23.1", "normal"),
    ("25.8", "elevated"),
    ("28.2", "warning"),
    ("24.0", "normal")
  ]

  for (temp, status) in readings do
    let _ ← xadd sensorKey "*" [
      ("temperature", temp),
      ("unit", "celsius"),
      ("status", status)
    ]

  Log.info s!"Recorded {readings.length} sensor readings"

  -- Read all sensor data
  let data ← xrange sensorKey "-" "+" none
  Log.info s!"Sensor data: {String.fromUTF8! data}"

  -- Get reading count
  let readingCount ← xlen sensorKey
  Log.info s!"Total readings: {readingCount}"

  -- Cleanup
  let _ ← del [sensorKey]

/-- Example: Multi-stream reading -/
def exMultiStreamRead : RedisM Unit := do
  Log.info "Example: Multi-stream reading"

  let stream1 := "stream:notifications"
  let stream2 := "stream:alerts"

  -- Add entries to both streams
  let _ ← xadd stream1 "*" [("type", "info"), ("msg", "System started")]
  let _ ← xadd stream2 "*" [("level", "warning"), ("msg", "High CPU usage")]
  let _ ← xadd stream1 "*" [("type", "success"), ("msg", "Backup completed")]
  let _ ← xadd stream2 "*" [("level", "error"), ("msg", "Disk full")]

  -- Read from both streams
  let results ← xread [(stream1, "0"), (stream2, "0")] (some 10) none
  Log.info s!"Multi-stream results: {String.fromUTF8! results}"

  -- Cleanup
  let _ ← del [stream1, stream2]

/-- Run all stream examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Redis Streams Examples ==="
  exBasicStream
  exReadStream
  exEventSourcing
  exActivityLog
  exStreamTrimming
  exDeleteEntries
  exSensorData
  exMultiStreamRead
  Log.info "=== Redis Streams Examples Complete ==="

end FeaturesStreamsExample
