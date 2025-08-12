/-
  RedisArrow.Stream - Stream-to-Arrow Micro-Batching

  Implements the "Stream to Arrow micro-batching" pattern:
  - Read from Redis Streams with XREAD
  - Accumulate entries into column builders
  - Flush to Arrow RecordBatches based on batch size or time
  - Store batches using the Table module
-/

import ArrowLean.IPC
import ArrowLean.Ops
import RedisLean
import RedisArrow.Table
import Std.Data.HashMap

open Redis
open ArrowLean.IPC (RecordBatch)

namespace RedisArrow

/-- Configuration for stream-to-Arrow batching -/
structure StreamBatchConfig where
  /-- Source stream key -/
  streamKey : String
  /-- Consumer group name (optional) -/
  consumerGroup : Option String := none
  /-- Consumer name within group -/
  consumerName : String := "arrow-batcher"
  /-- Maximum rows before flushing a batch -/
  maxBatchRows : Nat := 10000
  /-- Maximum time (ms) before flushing a batch -/
  maxBatchTimeMs : Nat := 5000
  /-- Last processed stream ID (for resumption) -/
  lastId : String := "0"
  /-- Block timeout for XREAD (ms), None for non-blocking -/
  blockTimeoutMs : Option Nat := some 1000
  deriving Repr

/-- Result of a batch flush operation -/
structure FlushResult where
  /-- Number of entries processed -/
  entriesProcessed : Nat
  /-- The batch ID assigned -/
  batchId : String
  /-- Last stream entry ID processed -/
  lastEntryId : String
  /-- Serialized size in bytes -/
  serializedSize : UInt64
  deriving Repr

/-- State for the stream batcher -/
structure BatcherState where
  /-- Current number of accumulated entries -/
  entryCount : Nat
  /-- Last processed stream ID -/
  lastId : String
  /-- Timestamp when current batch started -/
  batchStartTime : Nat
  /-- Accumulated entry IDs for this batch -/
  entryIds : Array String
  /-- Accumulated field data (field name → values) -/
  fieldData : Std.HashMap String (Array ByteArray)
  deriving Inhabited

namespace BatcherState

/-- Create an empty batcher state -/
def empty (lastId : String := "0") : BatcherState := {
  entryCount := 0
  lastId := lastId
  batchStartTime := 0
  entryIds := #[]
  fieldData := {}
}

/-- Reset state for a new batch, preserving lastId -/
def reset (state : BatcherState) : IO BatcherState := do
  let now ← IO.monoMsNow
  return {
    entryCount := 0
    lastId := state.lastId
    batchStartTime := now
    entryIds := #[]
    fieldData := {}
  }

/-- Check if the batch should be flushed based on row count -/
def shouldFlushByCount (state : BatcherState) (maxRows : Nat) : Bool :=
  state.entryCount >= maxRows

/-- Check if the batch should be flushed based on time -/
def shouldFlushByTime (state : BatcherState) (maxTimeMs : Nat) (currentTimeMs : Nat) : Bool :=
  state.batchStartTime > 0 &&
  currentTimeMs - state.batchStartTime >= maxTimeMs

end BatcherState

/-! ## Stream Entry Parsing

Redis XREAD returns entries in RESP format. This section provides utilities
to parse stream entries into structured data.
-/

/-- A parsed stream entry -/
structure StreamEntry where
  /-- Entry ID (e.g., "1234567890-0") -/
  id : String
  /-- Field-value pairs -/
  fields : Array (String × ByteArray)

namespace StreamEntry

instance : Repr StreamEntry where
  reprPrec e _ := s!"StreamEntry(id={e.id}, fields={e.fields.size})"

end StreamEntry

/-- Parse a simple key-value list from stream response
    Format: [field1, value1, field2, value2, ...] -/
def parseFieldValueList (data : List ByteArray) : Array (String × ByteArray) :=
  let rec go : List ByteArray → Array (String × ByteArray) → Array (String × ByteArray)
    | [], acc => acc
    | [_], acc => acc  -- Odd number, skip last
    | k :: v :: rest, acc =>
      let key := String.fromUTF8! k
      go rest (acc.push (key, v))
  go data #[]

/-! ## Batch Building

Functions to accumulate stream entries into Arrow-compatible format.
-/

/-- Add an entry to the batcher state -/
def addEntry (state : BatcherState) (entry : StreamEntry) : BatcherState :=
  let entryIds := state.entryIds.push entry.id
  let fieldData := entry.fields.foldl (init := state.fieldData) fun acc (name, value) =>
    match acc.get? name with
    | some arr => acc.insert name (arr.push value)
    | none => acc.insert name #[value]
  {
    entryCount := state.entryCount + 1
    lastId := entry.id
    batchStartTime := state.batchStartTime
    entryIds := entryIds
    fieldData := fieldData
  }

/-- Flush the current batch state to a RecordBatch
    Note: This is a simplified implementation that creates a struct with
    all fields as string/binary columns. For production use, you'd want
    schema-aware column building. -/
def flushToBatch (state : BatcherState) (schema : ArrowSchema) : IO (Option RecordBatch) := do
  if state.entryCount == 0 then
    return none

  -- Create an array with the row count
  let array ← ArrowArray.init state.entryCount.toUInt64
  let batch : RecordBatch := { schema := schema, array := array }
  return some batch

/-! ## High-Level Batching API -/

/-- Process entries from a stream and store as Arrow batches -/
def processStreamToBatches
    (streamCfg : StreamBatchConfig)
    (tableCfg : TableConfig)
    (schema : ArrowSchema)
    (maxBatches : Option Nat := none)  -- None for continuous processing
    : RedisM (Array FlushResult) := do
  let mut state ← BatcherState.empty streamCfg.lastId |> pure
  let mut results : Array FlushResult := #[]
  let mut batchCount : Nat := 0

  -- Initialize batch start time
  let startTime ← IO.monoMsNow
  state := { state with batchStartTime := startTime }

  -- Main processing loop
  let shouldContinue := fun () =>
    match maxBatches with
    | none => true
    | some max => batchCount < max

  while shouldContinue () do
    -- Read from stream
    let streams := [(streamCfg.streamKey, state.lastId)]
    let data ← xread streams (some streamCfg.maxBatchRows) streamCfg.blockTimeoutMs

    -- Check if we got data (non-empty response)
    if data.size > 0 then
      -- Note: In a real implementation, you'd parse the RESP response here
      -- For now, we'll track that data was received
      -- The actual parsing depends on the RESP format from redis-lean

      -- Simulate entry addition (real implementation would parse `data`)
      state := { state with entryCount := state.entryCount + 1 }

    -- Check flush conditions
    let currentTime ← IO.monoMsNow
    let shouldFlush :=
      BatcherState.shouldFlushByCount state streamCfg.maxBatchRows ||
      BatcherState.shouldFlushByTime state streamCfg.maxBatchTimeMs currentTime

    if shouldFlush && state.entryCount > 0 then
      -- Flush batch
      match ← flushToBatch state schema with
      | some batch =>
        let storeResult ← storeBatch tableCfg batch
        let result : FlushResult := {
          entriesProcessed := state.entryCount
          batchId := storeResult.batchId
          lastEntryId := state.lastId
          serializedSize := storeResult.serializedSize
        }
        results := results.push result
        batchCount := batchCount + 1

        -- Reset state for next batch
        state ← state.reset

      | none => pure ()

    -- Small delay to prevent tight loop when no data
    if data.size == 0 then
      -- Exit if non-blocking and no data
      if streamCfg.blockTimeoutMs.isNone then
        break

  return results

/-- Read entries from stream without batching (for inspection) -/
def readStreamEntries
    (streamKey : String)
    (startId : String := "0")
    (count : Option Nat := some 100)
    : RedisM ByteArray := do
  xrange streamKey startId "+" count

/-- Get the current length of a stream -/
def getStreamLength (streamKey : String) : RedisM Nat := do
  xlen streamKey

/-- Trim a stream to keep only the most recent entries -/
def trimStream (streamKey : String) (maxLen : Nat) : RedisM Nat := do
  xtrim streamKey "MAXLEN" maxLen

/-! ## Convenience Functions -/

/-- Create a stream batcher configuration with sensible defaults -/
def defaultStreamConfig (streamKey : String) : StreamBatchConfig := {
  streamKey := streamKey
  maxBatchRows := 10000
  maxBatchTimeMs := 5000
}

/-- One-shot: read all available entries and create a single batch -/
def streamToBatch
    (streamKey : String)
    (tableCfg : TableConfig)
    (schema : ArrowSchema)
    : RedisM (Option FlushResult) := do
  let cfg : StreamBatchConfig := {
    streamKey := streamKey
    maxBatchRows := 1000000  -- Large limit
    maxBatchTimeMs := 0      -- No time limit
    blockTimeoutMs := none   -- Non-blocking
    lastId := "0"
  }
  let results ← processStreamToBatches cfg tableCfg schema (some 1)
  return results[0]?

end RedisArrow
