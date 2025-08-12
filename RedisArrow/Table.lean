/-
  RedisArrow.Table - Arrow Table Storage in Redis

  Implements the "Keys of type Arrow" pattern for storing Arrow data in Redis:
  - Schema stored once per table
  - RecordBatches stored as individual keys
  - Manifest (sorted set) tracks batch order

  Key pattern:
    arrow:schema:<table>              → serialized schema
    arrow:batch:<table>:<batch_id>    → serialized RecordBatch
    arrow:manifest:<table>            → sorted set of batch_ids (score = timestamp)
    arrow:head:<table>                → latest batch_id (optional)
-/

import ArrowLean.IPC
import ArrowLean.Ops
import RedisLean

open Redis
open ArrowLean.IPC (RecordBatch serializeSchema deserializeSchema serialize deserialize)

namespace RedisArrow

/-- Configuration for an Arrow table stored in Redis -/
structure TableConfig where
  /-- Table name (used in key prefixes) -/
  name : String
  /-- Key for storing the schema -/
  schemaKey : String := s!"arrow:schema:{name}"
  /-- Prefix for batch keys -/
  batchKeyPrefix : String := s!"arrow:batch:{name}:"
  /-- Key for the manifest (sorted set of batch IDs) -/
  manifestKey : String := s!"arrow:manifest:{name}"
  /-- Key for the head pointer (latest batch) -/
  headKey : String := s!"arrow:head:{name}"
  deriving Repr

namespace TableConfig

/-- Create a TableConfig with default key patterns -/
def create (name : String) : TableConfig :=
  { name := name }

/-- Get the full key for a specific batch -/
def batchKey (cfg : TableConfig) (batchId : String) : String :=
  cfg.batchKeyPrefix ++ batchId

end TableConfig

/-- Result of storing a batch -/
structure StoreBatchResult where
  batchId : String
  serializedSize : UInt64
  deriving Repr

/-- Metadata about a stored table -/
structure TableMetadata where
  name : String
  schemaFormat : Option String
  batchCount : Nat
  deriving Repr

/-! ## Table Operations -/

/-- Store a schema for a table (call once when creating table) -/
def storeSchema (cfg : TableConfig) (schema : ArrowSchema) : RedisM Unit := do
  let data ← serializeSchema schema
  set cfg.schemaKey data

/-- Retrieve the schema for a table -/
def getSchema (cfg : TableConfig) : RedisM (Option ArrowSchema) := do
  let data ← get cfg.schemaKey
  if data.size == 0 then
    return none
  else
    deserializeSchema data

/-- Generate a batch ID based on timestamp -/
def generateBatchId : IO String := do
  let now ← IO.monoNanosNow
  return s!"{now}"

/-- Store a RecordBatch and add to manifest -/
def storeBatch (cfg : TableConfig) (batch : RecordBatch) (batchId : Option String := none) : RedisM StoreBatchResult := do
  -- Generate batch ID if not provided
  let id ← match batchId with
    | some id => pure id
    | none => generateBatchId

  -- Serialize the batch
  let data ← serialize batch
  let size := data.size.toUInt64

  -- Store the batch
  let key := cfg.batchKey id
  set key data

  -- Add to manifest with timestamp score
  let now ← IO.monoMsNow
  let score := now.toFloat
  let _ ← zadd cfg.manifestKey score id

  -- Update head pointer
  set cfg.headKey id

  return { batchId := id, serializedSize := size }

/-- Store schema and array as a batch -/
def storeSchemaAndArray (cfg : TableConfig) (schema : ArrowSchema) (array : ArrowArray)
    (batchId : Option String := none) : RedisM StoreBatchResult := do
  let batch : RecordBatch := { schema := schema, array := array }
  storeBatch cfg batch batchId

/-- Retrieve a specific batch by ID -/
def getBatch (cfg : TableConfig) (batchId : String) : RedisM (Option RecordBatch) := do
  let key := cfg.batchKey batchId
  let data ← get key
  if data.size == 0 then
    return none
  else
    deserialize data

/-- Get the latest batch (head) -/
def getHeadBatch (cfg : TableConfig) : RedisM (Option RecordBatch) := do
  let headIdBytes ← get cfg.headKey
  if headIdBytes.size == 0 then
    return none
  else
    let headId := String.fromUTF8! headIdBytes
    getBatch cfg headId

/-- Get all batch IDs in order (oldest first) -/
def getManifest (cfg : TableConfig) : RedisM (Array String) := do
  let ids ← zrange cfg.manifestKey 0 (-1)
  return ids.map String.fromUTF8! |>.toArray

/-- Get batch IDs in reverse order (newest first) -/
def getManifestReverse (cfg : TableConfig) : RedisM (Array String) := do
  let ids ← getManifest cfg
  return ids.reverse

/-- Get the count of batches in the table -/
def getBatchCount (cfg : TableConfig) : RedisM Nat := do
  zcard cfg.manifestKey

/-- Iterate over all batches in order -/
def forEachBatch (cfg : TableConfig) (f : RecordBatch → IO Unit) : RedisM Unit := do
  let batchIds ← getManifest cfg
  for id in batchIds do
    match ← getBatch cfg id with
    | some batch => f batch
    | none => pure () -- Skip missing batches

/-- Iterate over all batches with their IDs -/
def forEachBatchWithId (cfg : TableConfig) (f : String → RecordBatch → IO Unit) : RedisM Unit := do
  let batchIds ← getManifest cfg
  for id in batchIds do
    match ← getBatch cfg id with
    | some batch => f id batch
    | none => pure ()

/-- Collect all batches into an array -/
def getAllBatches (cfg : TableConfig) : RedisM (Array RecordBatch) := do
  let batchIds ← getManifest cfg
  let mut batches : Array RecordBatch := #[]
  for id in batchIds do
    match ← getBatch cfg id with
    | some batch => batches := batches.push batch
    | none => pure ()
  return batches

/-- Get table metadata -/
def getTableMetadata (cfg : TableConfig) : RedisM TableMetadata := do
  let schemaOpt ← getSchema cfg
  let count ← getBatchCount cfg
  return {
    name := cfg.name
    schemaFormat := schemaOpt.map (·.format)
    batchCount := count
  }

/-- Delete a specific batch -/
def deleteBatch (cfg : TableConfig) (batchId : String) : RedisM Unit := do
  let key := cfg.batchKey batchId
  let _ ← del [key]
  -- Remove from manifest
  -- Note: Would need ZREM which may not be in redis-lean yet
  pure ()

/-- Delete entire table (schema, all batches, manifest) -/
def deleteTable (cfg : TableConfig) : RedisM Unit := do
  -- Get all batch IDs first
  let batchIds ← getManifest cfg

  -- Collect all keys to delete
  let mut keys : List String := [cfg.schemaKey, cfg.manifestKey, cfg.headKey]
  for id in batchIds do
    keys := keys ++ [cfg.batchKey id]

  -- Delete all keys
  let _ ← del keys
  pure ()

/-! ## Batch Window Operations -/

/-- Get the N most recent batches -/
def getRecentBatches (cfg : TableConfig) (n : Nat) : RedisM (Array RecordBatch) := do
  let allIds ← getManifestReverse cfg
  let recentIds := allIds.toList.take n |>.toArray
  let mut batches : Array RecordBatch := #[]
  for id in recentIds do
    match ← getBatch cfg id with
    | some batch => batches := batches.push batch
    | none => pure ()
  return batches

/-- Compact old batches: keep only N most recent -/
def compactToRecent (cfg : TableConfig) (keepCount : Nat) : RedisM Nat := do
  let allIds ← getManifest cfg
  if allIds.size <= keepCount then
    return 0

  let toDelete := allIds.toList.take (allIds.size - keepCount) |>.toArray
  for id in toDelete do
    let key := cfg.batchKey id
    let _ ← del [key]

  return toDelete.size

end RedisArrow
