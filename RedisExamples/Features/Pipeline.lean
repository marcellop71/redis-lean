import RedisLean.FFI
import RedisLean.Log

namespace FeaturesPipelineExample

open Redis

/-!
# Pipeline Examples

Demonstrates true Redis pipelining for batching commands and reducing
network round-trips. Pipelining sends multiple commands in a single
network request and receives all responses together.

Benefits:
- Dramatically reduced latency for bulk operations
- Lower network overhead
- Better throughput for batch processing
-/

/-- Example: Basic pipeline with PipelineBuilder -/
def exBasicPipeline (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Basic Pipeline with PipelineBuilder"

  -- Build a pipeline with multiple commands
  let pb := FFI.PipelineBuilder.empty
    |>.set "pipeline:key1" "value1"
    |>.set "pipeline:key2" "value2"
    |>.set "pipeline:key3" "value3"
    |>.get "pipeline:key1"
    |>.get "pipeline:key2"
    |>.get "pipeline:key3"

  Log.EIO.info s!"  Pipeline contains {pb.size} commands"

  -- Execute all commands in a single network round-trip
  let replies ← FFI.executePipeline ctx pb
  Log.EIO.info s!"  Received {replies.size} replies"

  for h : i in [:replies.size] do
    let reply := replies[i]
    let replyStr := String.fromUTF8! reply
    Log.EIO.info s!"  Reply {i}: {replyStr}"

  -- Cleanup
  FFI.appendCommand ctx "DEL pipeline:key1 pipeline:key2 pipeline:key3"
  FFI.flushPipeline ctx
  let _ ← FFI.getReply ctx

/-- Example: Using withPipeline for cleaner syntax -/
def exWithPipeline (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Pipeline with builder function"

  let replies ← FFI.withPipeline ctx fun pb =>
    pb.set "wp:counter" "0"
      |>.incr "wp:counter"
      |>.incr "wp:counter"
      |>.incr "wp:counter"
      |>.get "wp:counter"

  Log.EIO.info s!"  Final counter value: {String.fromUTF8! replies[4]!}"

  -- Cleanup
  FFI.appendCommand ctx "DEL wp:counter"
  FFI.flushPipeline ctx
  let _ ← FFI.getReply ctx

/-- Example: Manual pipeline control for complex scenarios -/
def exManualPipeline (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Manual pipeline control"

  -- Queue commands manually
  FFI.appendCommand ctx "SET manual:a hello"
  FFI.appendCommand ctx "SET manual:b world"
  FFI.appendCommand ctx "APPEND manual:a _suffix"
  FFI.appendCommand ctx "GET manual:a"
  FFI.appendCommand ctx "GET manual:b"

  Log.EIO.info "  Queued 5 commands"

  -- Flush to send all at once
  FFI.flushPipeline ctx
  Log.EIO.info "  Flushed pipeline"

  -- Collect replies
  let reply1 ← FFI.getReply ctx
  let reply2 ← FFI.getReply ctx
  let reply3 ← FFI.getReply ctx
  let reply4 ← FFI.getReply ctx
  let reply5 ← FFI.getReply ctx

  Log.EIO.info s!"  SET manual:a -> {String.fromUTF8! reply1}"
  Log.EIO.info s!"  SET manual:b -> {String.fromUTF8! reply2}"
  Log.EIO.info s!"  APPEND result -> {String.fromUTF8! reply3}"
  Log.EIO.info s!"  GET manual:a -> {String.fromUTF8! reply4}"
  Log.EIO.info s!"  GET manual:b -> {String.fromUTF8! reply5}"

  -- Cleanup
  FFI.appendCommand ctx "DEL manual:a manual:b"
  FFI.flushPipeline ctx
  let _ ← FFI.getReply ctx

/-- Example: Hash operations in pipeline -/
def exHashPipeline (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Hash operations in pipeline"

  let replies ← FFI.withPipeline ctx fun pb =>
    pb.hset "user:1000" "name" "Alice"
      |>.hset "user:1000" "email" "alice@example.com"
      |>.hset "user:1000" "age" "30"
      |>.hget "user:1000" "name"
      |>.hget "user:1000" "email"

  Log.EIO.info s!"  Created user with 3 fields"
  Log.EIO.info s!"  Name: {String.fromUTF8! replies[3]!}"
  Log.EIO.info s!"  Email: {String.fromUTF8! replies[4]!}"

  -- Cleanup
  FFI.appendCommand ctx "DEL user:1000"
  FFI.flushPipeline ctx
  let _ ← FFI.getReply ctx

/-- Example: Bulk insert with pipeline -/
def exBulkInsert (ctx : FFI.Ctx) : EIO Error Unit := do
  Log.EIO.info "Example: Bulk insert (100 keys)"

  -- Build pipeline with 100 SET commands
  let mut pb := FFI.PipelineBuilder.empty
  for i in [:100] do
    pb := pb.add s!"SET bulk:{i} value_{i}"

  Log.EIO.info s!"  Built pipeline with {pb.size} commands"

  -- Execute all at once
  let start ← IO.monoMsNow
  let _ ← FFI.executePipeline ctx pb
  let elapsed ← IO.monoMsNow
  Log.EIO.info s!"  Inserted 100 keys in {elapsed - start}ms"

  -- Cleanup with pipeline
  let mut cleanupPb := FFI.PipelineBuilder.empty
  for i in [:100] do
    cleanupPb := cleanupPb.del s!"bulk:{i}"
  let _ ← FFI.executePipeline ctx cleanupPb
  Log.EIO.info "  Cleanup complete"

/-- Run all pipeline examples -/
def runPipelineExamples : IO Unit := do
  let logOk ← Log.initZlog "config/zlog.conf" "pipeline-examples"
  if !logOk then
    IO.eprintln "Warning: Failed to initialize zlog"

  Log.info "=== Redis Pipeline Examples ==="

  -- Connect
  let ctx ← FFI.toIO <| FFI.connectPlain "127.0.0.1" 6379

  -- Run examples
  FFI.toIO <| exBasicPipeline ctx
  FFI.toIO <| exWithPipeline ctx
  FFI.toIO <| exManualPipeline ctx
  FFI.toIO <| exHashPipeline ctx
  FFI.toIO <| exBulkInsert ctx

  -- Disconnect
  FFI.toIO <| FFI.free ctx

  Log.info "=== Pipeline Examples Complete ==="
  Log.finiZlog

end FeaturesPipelineExample
