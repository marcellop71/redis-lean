import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesHashesExample

open Redis

/-!
# Redis Hashes Examples

Demonstrates Redis hash operations for implementing:
- Object/entity storage
- User profiles
- Configuration management
- Counters and statistics
-/

/-- Example: Basic hash operations -/
def exBasicHash : RedisM Unit := do
  Log.info "Example: Basic hash operations"

  let key := "hash:basic"

  -- Set individual fields
  let _ ← hset key "name" "Alice"
  let _ ← hset key "age" (25 : Nat)
  let _ ← hset key "city" "New York"
  Log.info "Set hash fields: name, age, city"

  -- Get individual field
  let name ← hget key "name"
  Log.info s!"Name: {String.fromUTF8! name}"

  -- Get typed field (decode ByteArray to Nat)
  let ageBytes ← hget key "age"
  let ageStr := String.fromUTF8! ageBytes
  Log.info s!"Age: {ageStr}"

  -- Check field existence
  let hasEmail ← hexists key "email"
  let hasName ← hexists key "name"
  Log.info s!"Has email: {hasEmail}, Has name: {hasName}"

  -- Get number of fields
  let fieldCount ← hlen key
  Log.info s!"Total fields: {fieldCount}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Get all hash data -/
def exGetAllHash : RedisM Unit := do
  Log.info "Example: Get all hash data"

  let key := "hash:user:123"

  -- Set multiple fields
  let _ ← hset key "username" "johndoe"
  let _ ← hset key "email" "john@example.com"
  let _ ← hset key "role" "admin"
  let _ ← hset key "created_at" "2024-01-01"

  -- Get all field-value pairs (returned as flat list: [field1, value1, field2, value2, ...])
  let all ← hgetall key
  Log.info "All hash data (field, value pairs):"
  -- Process pairs manually since toChunks doesn't exist
  let rec processPairs (lst : List ByteArray) : RedisM Unit :=
    match lst with
    | [] => pure ()
    | [_] => pure ()  -- Odd element, ignore
    | field :: value :: rest => do
      Log.info s!"  {String.fromUTF8! field}: {String.fromUTF8! value}"
      processPairs rest
  processPairs all

  -- Get all keys
  let keys ← hkeys key
  Log.info s!"All fields: {keys.map String.fromUTF8!}"

  -- Get all values
  let vals ← hvals key
  Log.info s!"All values: {vals.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [key]

/-- Example: User profile storage -/
def exUserProfile : RedisM Unit := do
  Log.info "Example: User profile storage"

  let userKey := "user:profile:456"

  -- Store user profile
  let _ ← hset userKey "first_name" "Jane"
  let _ ← hset userKey "last_name" "Doe"
  let _ ← hset userKey "email" "jane@example.com"
  let _ ← hset userKey "login_count" (0 : Nat)
  let _ ← hset userKey "is_active" true

  Log.info "Created user profile"

  -- Increment login count
  let newCount ← hincrby userKey "login_count" 1
  Log.info s!"Login count after increment: {newCount}"

  -- Get specific fields (multi-get)
  let fields ← hmget userKey ["first_name", "last_name", "email"]
  Log.info "Retrieved fields:"
  for (fieldName, value) in ["first_name", "last_name", "email"].zip fields do
    match value with
    | some v => Log.info s!"  {fieldName}: {String.fromUTF8! v}"
    | none => Log.info s!"  {fieldName}: (not found)"

  -- Cleanup
  let _ ← del [userKey]

/-- Example: Conditional set -/
def exConditionalSet : RedisM Unit := do
  Log.info "Example: Conditional set (HSETNX)"

  let key := "hash:conditional"

  -- HSETNX - only set if field doesn't exist
  let result1 ← hsetnx key "status" "pending"
  Log.info s!"First HSETNX result: {result1} (true = field was set)"

  -- Try to set again - should fail
  let result2 ← hsetnx key "status" "completed"
  Log.info s!"Second HSETNX result: {result2} (false = field already exists)"

  -- Check value (should still be "pending")
  let status ← hget key "status"
  Log.info s!"Status value: {String.fromUTF8! status}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Hash counters -/
def exHashCounters : RedisM Unit := do
  Log.info "Example: Hash counters"

  let key := "stats:page:home"

  -- Initialize counters
  let _ ← hset key "views" (0 : Nat)
  let _ ← hset key "clicks" (0 : Nat)
  let _ ← hset key "time_spent" (0.0 : Float)

  -- Increment integer counter
  let views ← hincrby key "views" 10
  Log.info s!"Views after +10: {views}"

  let moreViews ← hincrby key "views" 5
  Log.info s!"Views after +5: {moreViews}"

  -- Increment float counter
  let time1 ← hincrbyfloat key "time_spent" 2.5
  Log.info s!"Time spent after +2.5: {time1}s"

  let time2 ← hincrbyfloat key "time_spent" 1.7
  Log.info s!"Time spent after +1.7: {time2}s"

  -- Cleanup
  let _ ← del [key]

/-- Example: Delete hash fields -/
def exDeleteFields : RedisM Unit := do
  Log.info "Example: Delete hash fields"

  let key := "hash:delete"

  -- Set multiple fields
  let _ ← hset key "keep1" "value1"
  let _ ← hset key "keep2" "value2"
  let _ ← hset key "remove1" "value3"
  let _ ← hset key "remove2" "value4"

  let before ← hlen key
  Log.info s!"Fields before deletion: {before}"

  -- Delete specific fields
  let deleted ← hdel key "remove1"
  Log.info s!"Deleted 'remove1': {deleted} fields removed"

  let deleted2 ← hdel key "remove2"
  Log.info s!"Deleted 'remove2': {deleted2} fields removed"

  let after ← hlen key
  Log.info s!"Fields after deletion: {after}"

  -- List remaining fields
  let remaining ← hkeys key
  Log.info s!"Remaining fields: {remaining.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Configuration storage -/
def exConfiguration : RedisM Unit := do
  Log.info "Example: Configuration storage"

  let configKey := "config:app"

  -- Store configuration
  let _ ← hset configKey "debug_mode" false
  let _ ← hset configKey "max_connections" (100 : Nat)
  let _ ← hset configKey "timeout_seconds" (30 : Nat)
  let _ ← hset configKey "cache_ttl" (3600 : Nat)
  let _ ← hset configKey "api_version" "v2"

  Log.info "Configuration stored"

  -- Read configuration values (using raw hget and converting)
  let debugBytes ← hget configKey "debug_mode"
  let maxConnBytes ← hget configKey "max_connections"
  let timeoutBytes ← hget configKey "timeout_seconds"
  let apiVerBytes ← hget configKey "api_version"

  Log.info "Configuration values:"
  Log.info s!"  debug_mode: {String.fromUTF8! debugBytes}"
  Log.info s!"  max_connections: {String.fromUTF8! maxConnBytes}"
  Log.info s!"  timeout_seconds: {String.fromUTF8! timeoutBytes}"
  Log.info s!"  api_version: {String.fromUTF8! apiVerBytes}"

  -- Cleanup
  let _ ← del [configKey]

/-- Example: Scanning large hashes -/
def exScanHash : RedisM Unit := do
  Log.info "Example: Scanning large hashes"

  let key := "hash:large"

  -- Create hash with many fields
  for i in List.range 20 do
    let _ ← hset key s!"field_{i}" s!"value_{i}"

  Log.info "Created hash with 20 fields"

  -- Scan with cursor
  let (cursor1, batch1) ← hscan key 0 none (some 5)
  Log.info s!"First scan (cursor 0, count 5):"
  Log.info s!"  Returned cursor: {cursor1}"
  Log.info s!"  Batch size: {batch1.length / 2} fields"

  -- Continue scanning
  if cursor1 != 0 then
    let (cursor2, batch2) ← hscan key cursor1 none (some 5)
    Log.info s!"Second scan (cursor {cursor1}):"
    Log.info s!"  Returned cursor: {cursor2}"
    Log.info s!"  Batch size: {batch2.length / 2} fields"

  -- Cleanup
  let _ ← del [key]

/-- Run all hash examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Redis Hashes Examples ==="
  exBasicHash
  exGetAllHash
  exUserProfile
  exConditionalSet
  exHashCounters
  exDeleteFields
  exConfiguration
  exScanHash
  Log.info "=== Redis Hashes Examples Complete ==="

end FeaturesHashesExample
