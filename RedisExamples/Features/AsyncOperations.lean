import RedisLean.FFI
import RedisLean.Log

namespace FeaturesAsyncOperationsExample

open Redis

/-!
# Async Operations Examples

Demonstrates non-blocking Redis operations:
- Non-blocking connections
- Polling for data availability
- Non-blocking read/write
- Building responsive applications

These patterns are useful for building event-driven applications
or when you need to handle multiple connections without blocking.
-/

/-- Example: Non-blocking connection -/
def exNonBlockingConnect : IO Unit := do
  Log.info "Example: Non-blocking connection"

  let result ← (FFI.connectNonBlock "127.0.0.1" 6379).toBaseIO
  match result with
  | .ok ctx =>
    Log.info "  Non-blocking connection initiated"

    -- Wait for connection to be writable (connected)
    let writable ← (FFI.canWrite ctx 5000).toBaseIO
    match writable with
    | .ok true =>
      Log.info "  Connection ready for writing"

      -- Now we can use the connection
      let pingResult ← (FFI.ping ctx "async".toUTF8).toBaseIO
      match pingResult with
      | .ok _ => Log.info "  PING successful"
      | .error e => Log.error s!"  PING failed: {e}"

    | .ok false =>
      Log.error "  Connection not ready within timeout"

    | .error e =>
      Log.error s!"  Error checking writability: {e}"

    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.error s!"  Non-blocking connect failed: {e}"

/-- Example: Polling for data -/
def exPollingForData (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Polling for data availability"

  -- Send a command
  FFI.appendCommand ctx "SET poll:key poll:value"
  FFI.appendCommand ctx "GET poll:key"
  FFI.flushPipeline ctx

  -- Poll for response with timeout
  Log.EIO.info "  Polling for first reply..."
  let readable1 ← FFI.canRead ctx 1000
  if readable1 then
    let reply1 ← FFI.getReply ctx
    Log.EIO.info s!"  SET reply: {String.fromUTF8! reply1}"
  else
    Log.EIO.info "  No data available within 1s"

  Log.EIO.info "  Polling for second reply..."
  let readable2 ← FFI.canRead ctx 1000
  if readable2 then
    let reply2 ← FFI.getReply ctx
    Log.EIO.info s!"  GET reply: {String.fromUTF8! reply2}"
  else
    Log.EIO.info "  No data available within 1s"

  -- Cleanup
  FFI.appendCommand ctx "DEL poll:key"
  FFI.flushPipeline ctx
  let _ ← FFI.getReply ctx

/-- Example: Non-blocking reply with pollReply -/
def exPollReply (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Non-blocking reply with pollReply"

  -- Send command
  FFI.appendCommand ctx "SET pollreply:key pollreply:value"
  FFI.flushPipeline ctx

  -- Use pollReply for convenient non-blocking read
  let reply ← FFI.pollReply ctx 2000
  match reply with
  | some data => Log.EIO.info s!"  Got reply: {String.fromUTF8! data}"
  | none => Log.EIO.info "  No reply within 2s timeout"

  -- Cleanup
  FFI.appendCommand ctx "DEL pollreply:key"
  FFI.flushPipeline ctx
  let _ ← FFI.getReply ctx

/-- Example: Manual buffer control -/
def exManualBufferControl (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Manual buffer control"

  -- Append command to output buffer
  FFI.appendCommand ctx "PING hello"
  Log.EIO.info "  Command appended to output buffer"

  -- Manually flush output buffer
  let done ← FFI.bufferWrite ctx
  Log.EIO.info s!"  Buffer write done: {done}"

  -- Wait for response
  let readable ← FFI.canRead ctx 1000
  if readable then
    -- Read into input buffer
    FFI.bufferRead ctx
    Log.EIO.info "  Data read into input buffer"

    -- Get reply from buffer (non-blocking)
    let replyOpt ← FFI.getReplyNonBlock ctx
    match replyOpt with
    | some data => Log.EIO.info s!"  Reply: {String.fromUTF8! data}"
    | none => Log.EIO.info "  Reply not yet complete"
  else
    Log.EIO.info "  No data available"

/-- Example: Timeout handling pattern -/
def exTimeoutHandling (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Timeout handling pattern"

  -- Send a command
  FFI.appendCommand ctx "SET timeout:key timeout:value"
  FFI.flushPipeline ctx

  -- Try to get reply with different timeouts
  Log.EIO.info "  Trying with 0ms timeout (immediate check)..."
  let instant ← FFI.pollReply ctx 0
  Log.EIO.info s!"  Immediate result: {instant.isSome}"

  Log.EIO.info "  Trying with 100ms timeout..."
  let short ← FFI.pollReply ctx 100
  Log.EIO.info s!"  100ms result: {short.isSome}"

  -- If we still need the reply, wait longer
  if short.isNone then
    Log.EIO.info "  Trying with 1000ms timeout..."
    let longer ← FFI.pollReply ctx 1000
    match longer with
    | some data => Log.EIO.info s!"  Got reply: {String.fromUTF8! data}"
    | none => Log.EIO.info "  Still no reply"

  -- Cleanup
  FFI.appendCommand ctx "DEL timeout:key"
  FFI.flushPipeline ctx
  let _ ← FFI.getReply ctx

/-- Simple async task runner for Redis operations -/
structure AsyncTask where
  command : String
  callback : ByteArray → IO Unit

/-- Example: Simple async task queue pattern -/
def exAsyncTaskQueue (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Async task queue pattern"

  -- Queue of commands to execute
  let tasks : Array String := #[
    "SET task:1 result1",
    "SET task:2 result2",
    "SET task:3 result3",
    "GET task:1",
    "GET task:2",
    "GET task:3"
  ]

  -- Send all commands (non-blocking enqueue)
  for task in tasks do
    FFI.appendCommand ctx task

  -- Flush all at once
  FFI.flushPipeline ctx
  Log.EIO.info s!"  Queued {tasks.size} commands"

  -- Process replies as they become available
  let mut processedCount := 0
  for i in [:tasks.size] do
    let readable ← FFI.canRead ctx 1000
    if readable then
      FFI.bufferRead ctx
      let replyOpt ← FFI.getReplyNonBlock ctx
      match replyOpt with
      | some data =>
        processedCount := processedCount + 1
        Log.EIO.info s!"  Task {i}: {String.fromUTF8! data}"
      | none =>
        -- Might need more data, try blocking read
        let reply ← FFI.getReply ctx
        processedCount := processedCount + 1
        Log.EIO.info s!"  Task {i}: {String.fromUTF8! reply}"

  Log.EIO.info s!"  Processed {processedCount} tasks"

  -- Cleanup
  FFI.appendCommand ctx "DEL task:1 task:2 task:3"
  FFI.flushPipeline ctx
  let _ ← FFI.getReply ctx

/-- Example: Interleaved operations (simulating concurrent work) -/
def exInterleavedOperations (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Interleaved operations"

  -- Start first operation
  FFI.appendCommand ctx "SET interleave:a value_a"
  FFI.flushPipeline ctx
  Log.EIO.info "  Sent SET command A"

  -- Do some other work while waiting
  Log.EIO.info "  (Simulating other work...)"

  -- Check if reply is ready (non-blocking)
  let ready1 ← FFI.canRead ctx 0
  Log.EIO.info s!"  Reply A ready: {ready1}"

  -- Start second operation
  FFI.appendCommand ctx "SET interleave:b value_b"
  FFI.flushPipeline ctx
  Log.EIO.info "  Sent SET command B"

  -- Now collect both replies
  Log.EIO.info "  Collecting replies..."
  let reply1 ← FFI.pollReply ctx 1000
  let reply2 ← FFI.pollReply ctx 1000

  Log.EIO.info s!"  Reply A: {reply1.map String.fromUTF8!}"
  Log.EIO.info s!"  Reply B: {reply2.map String.fromUTF8!}"

  -- Cleanup
  FFI.appendCommand ctx "DEL interleave:a interleave:b"
  FFI.flushPipeline ctx
  let _ ← FFI.getReply ctx

/-- Run all async operations examples -/
def runAsyncOperationsExamples : IO Unit := do
  let logOk ← Log.initZlog "config/zlog.conf" "async-examples"
  if !logOk then
    IO.eprintln "Warning: Failed to initialize zlog"

  Log.info "=== Redis Async Operations Examples ==="

  exNonBlockingConnect

  -- For other examples, use a regular connection
  let result ← (FFI.connectPlain "127.0.0.1" 6379).toBaseIO
  match result with
  | .ok ctx =>
    FFI.toIO <| exPollingForData ctx
    FFI.toIO <| exPollReply ctx
    FFI.toIO <| exManualBufferControl ctx
    FFI.toIO <| exTimeoutHandling ctx
    FFI.toIO <| exAsyncTaskQueue ctx
    FFI.toIO <| exInterleavedOperations ctx
    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.error s!"Connection failed: {e}"

  Log.info "=== Async Operations Examples Complete ==="
  Log.finiZlog

end FeaturesAsyncOperationsExample
