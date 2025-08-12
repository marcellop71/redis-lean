import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesKeyOperationsExample

open Redis

/-!
# Redis Key Operations Examples

Demonstrates fundamental key operations:
- Key existence and type checking
- TTL and expiration
- Key renaming and copying
- Scanning and pattern matching
-/

/-- Example: Key existence and types -/
def exKeyExistenceTypes : RedisM Unit := do
  Log.info "Example: Key existence and types"

  -- Create keys of different types
  set "key:string" "hello"
  let _ ← lpush "key:list" ["a", "b", "c"]
  let _ ← sadd "key:set" "member1"
  let _ ← zadd "key:zset" 1.0 "member1"
  let _ ← hset "key:hash" "field1" "value1"

  -- Check existence
  let exists1 ← existsKey "key:string"
  let exists2 ← existsKey "key:nonexistent"
  Log.info s!"key:string exists: {exists1}"
  Log.info s!"key:nonexistent exists: {exists2}"

  -- Check types
  let type1 ← typeKey "key:string"
  let type2 ← typeKey "key:list"
  let type3 ← typeKey "key:set"
  let type4 ← typeKey "key:zset"
  let type5 ← typeKey "key:hash"

  Log.info "Key types:"
  Log.info s!"  key:string: {repr type1}"
  Log.info s!"  key:list: {repr type2}"
  Log.info s!"  key:set: {repr type3}"
  Log.info s!"  key:zset: {repr type4}"
  Log.info s!"  key:hash: {repr type5}"

  -- Cleanup
  let _ ← del ["key:string", "key:list", "key:set", "key:zset", "key:hash"]

/-- Example: TTL and expiration -/
def exTtlExpiration : RedisM Unit := do
  Log.info "Example: TTL and expiration"

  let key := "key:expiring"

  -- Set key with expiration (using SETEX)
  setex key "temporary value" 60  -- 60 seconds

  -- Check TTL
  let ttlSec ← ttl key
  Log.info s!"TTL in seconds: {ttlSec}"

  let ttlMs ← pttl key
  Log.info s!"TTL in milliseconds: {ttlMs}"

  -- Set expiration on existing key
  let key2 := "key:expire-later"
  set key2 "value"

  let _ ← expire key2 30  -- Expire in 30 seconds
  let ttl2 ← ttl key2
  Log.info s!"Key with EXPIRE: TTL = {ttl2}s"

  -- Remove expiration (persist)
  let _ ← persist key2
  let ttl3 ← ttl key2
  Log.info s!"After PERSIST: TTL = {ttl3} (-1 = no expiration)"

  -- Cleanup
  let _ ← del [key, key2]

/-- Example: Key deletion -/
def exKeyDeletion : RedisM Unit := do
  Log.info "Example: Key deletion"

  -- Create multiple keys
  set "del:1" "value1"
  set "del:2" "value2"
  set "del:3" "value3"
  set "del:4" "value4"

  -- Delete single key
  let deleted1 ← del ["del:1"]
  Log.info s!"Deleted {deleted1} key(s)"

  -- Delete multiple keys
  let deleted2 ← del ["del:2", "del:3", "del:nonexistent"]
  Log.info s!"Deleted {deleted2} key(s) (requested 3, one didn't exist)"

  -- UNLINK (async delete - better for large keys)
  let unlinked ← unlink ["del:4"]
  Log.info s!"Unlinked {unlinked} key(s)"

/-- Example: Key renaming -/
def exKeyRenaming : RedisM Unit := do
  Log.info "Example: Key renaming"

  set "rename:original" "some value"

  -- Rename key
  rename "rename:original" "rename:newname"
  Log.info "Renamed key"

  let exists1 ← existsKey "rename:original"
  let exists2 ← existsKey "rename:newname"
  Log.info s!"Original exists: {exists1}"
  Log.info s!"New name exists: {exists2}"

  -- RENAMENX - rename only if target doesn't exist
  set "rename:another" "another value"

  let success ← renamenx "rename:newname" "rename:another"  -- Should fail
  Log.info s!"RENAMENX to existing key: {success} (false = target exists)"

  let success2 ← renamenx "rename:newname" "rename:fresh"
  Log.info s!"RENAMENX to new key: {success2} (true = renamed)"

  -- Cleanup
  let _ ← del ["rename:another", "rename:fresh"]

/-- Example: Key copying -/
def exKeyCopying : RedisM Unit := do
  Log.info "Example: Key copying"

  set "copy:source" "original value"

  -- Copy key
  let success1 ← copy "copy:source" "copy:dest" false
  Log.info s!"Copied key: {success1}"

  let srcValue ← getAs String "copy:source"
  let dstValue ← getAs String "copy:dest"
  Log.info s!"Source: {srcValue}"
  Log.info s!"Destination: {dstValue}"

  -- Copy with REPLACE option
  set "copy:existing" "will be overwritten"
  let success2 ← copy "copy:source" "copy:existing" true
  Log.info s!"Copy with REPLACE: {success2}"

  -- Cleanup
  let _ ← del ["copy:source", "copy:dest", "copy:existing"]

/-- Example: Scanning keys -/
def exScanKeys : RedisM Unit := do
  Log.info "Example: Scanning keys"

  -- Create test keys
  for i in List.range 15 do
    set s!"scan:user:{i}" s!"user_{i}"
  for i in List.range 10 do
    set s!"scan:order:{i}" s!"order_{i}"

  Log.info "Created 25 keys (15 users, 10 orders)"

  -- Scan all keys with pattern
  let (cursor1, keys1) ← scan (α := String) 0 (some "scan:user:*".toUTF8) (some 5)
  Log.info s!"First scan (user keys, count 5):"
  Log.info s!"  Returned cursor: {cursor1}"
  Log.info s!"  Keys found: {keys1.length}"

  -- Continue scanning if needed
  if cursor1 != 0 then
    let (cursor2, keys2) ← scan (α := String) cursor1 (some "scan:user:*".toUTF8) (some 10)
    Log.info s!"Second scan:"
    Log.info s!"  Returned cursor: {cursor2}"
    Log.info s!"  Keys found: {keys2.length}"

  -- Use KEYS for pattern matching (use carefully in production!)
  let allUserKeys ← keys (α := String) "scan:user:*".toUTF8
  Log.info s!"KEYS 'scan:user:*': {allUserKeys.length} keys"

  -- Cleanup
  let userKeys := (List.range 15).map (s!"scan:user:{·}")
  let orderKeys := (List.range 10).map (s!"scan:order:{·}")
  let _ ← del (userKeys ++ orderKeys)

/-- Example: Touch and object idle time -/
def exTouchKeys : RedisM Unit := do
  Log.info "Example: Touch keys"

  set "touch:key1" "value1"
  set "touch:key2" "value2"
  set "touch:key3" "value3"

  -- Touch updates the last access time
  let touched ← touch ["touch:key1", "touch:key2", "touch:nonexistent"]
  Log.info s!"Touched {touched} keys (requested 3)"

  -- Cleanup
  let _ ← del ["touch:key1", "touch:key2", "touch:key3"]

/-- Example: Atomic increment/decrement -/
def exAtomicCounters : RedisM Unit := do
  Log.info "Example: Atomic increment/decrement"

  let counterKey := "counter:visits"

  -- Set initial value
  set counterKey (0 : Int)

  -- Increment
  let val1 ← incr counterKey
  Log.info s!"After INCR: {val1}"

  let val2 ← incrBy counterKey 10
  Log.info s!"After INCRBY 10: {val2}"

  -- Decrement
  let val3 ← decr counterKey
  Log.info s!"After DECR: {val3}"

  let val4 ← decrBy counterKey 5
  Log.info s!"After DECRBY 5: {val4}"

  -- Float increment
  let floatKey := "counter:score"
  set floatKey (0.0 : Float)

  let score1 ← incrByFloat floatKey 1.5
  Log.info s!"Float after +1.5: {score1}"

  let score2 ← incrByFloat floatKey (-0.3)
  Log.info s!"Float after -0.3: {score2}"

  -- Cleanup
  let _ ← del [counterKey, floatKey]

/-- Example: String operations -/
def exStringOperations : RedisM Unit := do
  Log.info "Example: String operations"

  let key := "string:ops"

  set key "Hello"

  -- Append
  let newLen ← append key ", World!"
  Log.info s!"After APPEND: length = {newLen}"

  -- Get value
  let value ← getAs String key
  Log.info s!"Value: {value}"

  -- Get length
  let strLen ← strlen key
  Log.info s!"STRLEN: {strLen}"

  -- Get range (substring)
  let substr ← getrange key 0 4
  Log.info s!"GETRANGE 0-4: {String.fromUTF8! substr}"

  -- GETDEL - get and delete
  let deleted ← getdel key
  Log.info s!"GETDEL: {String.fromUTF8! deleted}"

  let keyExists ← existsKey key
  Log.info s!"Key exists after GETDEL: {keyExists}"

/-- Run all key operations examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Redis Key Operations Examples ==="
  exKeyExistenceTypes
  exTtlExpiration
  exKeyDeletion
  exKeyRenaming
  exKeyCopying
  exScanKeys
  exTouchKeys
  exAtomicCounters
  exStringOperations
  Log.info "=== Redis Key Operations Examples Complete ==="

end FeaturesKeyOperationsExample
