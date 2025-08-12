import LSpec
import RedisTests.Mock

open Redis LSpec

namespace RedisTests.MockTests

/-!
# MockRedis Tests

Tests for the in-memory MockRedis implementation to ensure it behaves
correctly before using it to test other components.
-/

-- Helper to run IO tests in LSpec
unsafe def unsafeRunIO (action : IO Bool) : Bool :=
  match unsafeBaseIO action.toBaseIO with
  | .ok b => b
  | .error _ => false

@[implemented_by unsafeRunIO]
def ioTest (_action : IO Bool) : Bool := false

-- String Operations Tests

def testSetGet : IO Bool := do
  let mock ← MockRedis.create
  mock.set "key1" "value1".toUTF8
  let result ← mock.get "key1"
  return result == some "value1".toUTF8

def testGetNonExistent : IO Bool := do
  let mock ← MockRedis.create
  let result ← mock.get "nonexistent"
  return result.isNone

def testSetOverwrite : IO Bool := do
  let mock ← MockRedis.create
  mock.set "key" "value1".toUTF8
  mock.set "key" "value2".toUTF8
  let result ← mock.get "key"
  return result == some "value2".toUTF8

def testSetex : IO Bool := do
  let mock ← MockRedis.create
  mock.setex "expiring" "value".toUTF8 3600
  let result ← mock.get "expiring"
  return result == some "value".toUTF8

def testDel : IO Bool := do
  let mock ← MockRedis.create
  mock.set "key1" "value1".toUTF8
  mock.set "key2" "value2".toUTF8
  let deleted ← mock.del ["key1", "key2", "nonexistent"]
  let exists1 ← mock.keyExists "key1"
  let exists2 ← mock.keyExists "key2"
  return deleted == 2 && !exists1 && !exists2

def testKeyExists : IO Bool := do
  let mock ← MockRedis.create
  mock.set "exists" "value".toUTF8
  let e1 ← mock.keyExists "exists"
  let e2 ← mock.keyExists "notexists"
  return e1 && !e2

def testIncr : IO Bool := do
  let mock ← MockRedis.create
  let v1 ← mock.incr "counter"
  let v2 ← mock.incr "counter"
  let v3 ← mock.incr "counter"
  return v1 == 1 && v2 == 2 && v3 == 3

def testDecr : IO Bool := do
  let mock ← MockRedis.create
  mock.set "counter" "10".toUTF8
  let v1 ← mock.decr "counter"
  let v2 ← mock.decr "counter"
  return v1 == 9 && v2 == 8

def testIncrOnNonNumeric : IO Bool := do
  let mock ← MockRedis.create
  mock.set "notnum" "abc".toUTF8
  let v ← mock.incr "notnum"
  return v == 1  -- Treats invalid as 0

def stringOperationTests : TestSeq :=
  test "SET and GET" (ioTest testSetGet) $
  test "GET non-existent key" (ioTest testGetNonExistent) $
  test "SET overwrites existing key" (ioTest testSetOverwrite) $
  test "SETEX sets value" (ioTest testSetex) $
  test "DEL deletes keys" (ioTest testDel) $
  test "EXISTS checks key existence" (ioTest testKeyExists) $
  test "INCR increments counter" (ioTest testIncr) $
  test "DECR decrements counter" (ioTest testDecr) $
  test "INCR on non-numeric treats as 0" (ioTest testIncrOnNonNumeric)

-- List Operations Tests

def testLpush : IO Bool := do
  let mock ← MockRedis.create
  let len ← mock.lpush "list" ["a".toUTF8, "b".toUTF8, "c".toUTF8]
  let items ← mock.lrange "list" 0 (-1)
  return len == 3 && items.length == 3

def testRpush : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.rpush "list" ["a".toUTF8, "b".toUTF8]
  let _ ← mock.rpush "list" ["c".toUTF8]
  let len ← mock.llen "list"
  return len == 3

def testLpop : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.rpush "list" ["first".toUTF8, "second".toUTF8, "third".toUTF8]
  let popped ← mock.lpop "list"
  let remaining ← mock.llen "list"
  return popped == some "first".toUTF8 && remaining == 2

def testRpop : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.rpush "list" ["first".toUTF8, "second".toUTF8, "third".toUTF8]
  let popped ← mock.rpop "list"
  let remaining ← mock.llen "list"
  return popped == some "third".toUTF8 && remaining == 2

def testLrange : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.rpush "list" ["a".toUTF8, "b".toUTF8, "c".toUTF8, "d".toUTF8, "e".toUTF8]
  let middle ← mock.lrange "list" 1 3
  return middle.length == 3 && middle[0]! == "b".toUTF8

def testLrangeNegativeIndex : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.rpush "list" ["a".toUTF8, "b".toUTF8, "c".toUTF8]
  let last2 ← mock.lrange "list" (-2) (-1)
  return last2.length == 2

def testLlenEmpty : IO Bool := do
  let mock ← MockRedis.create
  let len ← mock.llen "nonexistent"
  return len == 0

def testLpopEmpty : IO Bool := do
  let mock ← MockRedis.create
  let result ← mock.lpop "empty"
  return result.isNone

def listOperationTests : TestSeq :=
  test "LPUSH adds to list" (ioTest testLpush) $
  test "RPUSH adds to end of list" (ioTest testRpush) $
  test "LPOP removes from front" (ioTest testLpop) $
  test "RPOP removes from end" (ioTest testRpop) $
  test "LRANGE returns range" (ioTest testLrange) $
  test "LRANGE with negative indices" (ioTest testLrangeNegativeIndex) $
  test "LLEN on empty/nonexistent list" (ioTest testLlenEmpty) $
  test "LPOP on empty list returns None" (ioTest testLpopEmpty)

-- Set Operations Tests

def testSadd : IO Bool := do
  let mock ← MockRedis.create
  let added1 ← mock.sadd "set" "member1".toUTF8
  let added2 ← mock.sadd "set" "member2".toUTF8
  let addedDup ← mock.sadd "set" "member1".toUTF8
  return added1 == 1 && added2 == 1 && addedDup == 0

def testSismember : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.sadd "set" "exists".toUTF8
  let isMember ← mock.sismember "set" "exists".toUTF8
  let notMember ← mock.sismember "set" "notexists".toUTF8
  return isMember && !notMember

def testSmembers : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.sadd "set" "a".toUTF8
  let _ ← mock.sadd "set" "b".toUTF8
  let _ ← mock.sadd "set" "c".toUTF8
  let members ← mock.smembers "set"
  return members.length == 3

def testSrem : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.sadd "set" "a".toUTF8
  let _ ← mock.sadd "set" "b".toUTF8
  let removed ← mock.srem "set" ["a".toUTF8, "nonexistent".toUTF8]
  let card ← mock.scard "set"
  return removed == 1 && card == 1

def testScard : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.sadd "set" "a".toUTF8
  let _ ← mock.sadd "set" "b".toUTF8
  let _ ← mock.sadd "set" "c".toUTF8
  let card ← mock.scard "set"
  return card == 3

def testScardEmpty : IO Bool := do
  let mock ← MockRedis.create
  let card ← mock.scard "nonexistent"
  return card == 0

def setOperationTests : TestSeq :=
  test "SADD adds member, returns 0 for duplicate" (ioTest testSadd) $
  test "SISMEMBER checks membership" (ioTest testSismember) $
  test "SMEMBERS returns all members" (ioTest testSmembers) $
  test "SREM removes members" (ioTest testSrem) $
  test "SCARD returns cardinality" (ioTest testScard) $
  test "SCARD on empty set returns 0" (ioTest testScardEmpty)

-- Hash Operations Tests

def testHsetHget : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.hset "hash" "field1" "value1".toUTF8
  let result ← mock.hget "hash" "field1"
  return result == some "value1".toUTF8

def testHgetNonExistent : IO Bool := do
  let mock ← MockRedis.create
  let result ← mock.hget "hash" "nonexistent"
  return result.isNone

def testHsetNewField : IO Bool := do
  let mock ← MockRedis.create
  let isNew1 ← mock.hset "hash" "field1" "value1".toUTF8
  let isNew2 ← mock.hset "hash" "field1" "value2".toUTF8
  return isNew1 == 1 && isNew2 == 0

def testHdel : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.hset "hash" "field1" "value1".toUTF8
  let deleted ← mock.hdel "hash" "field1"
  let exists_ ← mock.hexists "hash" "field1"
  return deleted == 1 && !exists_

def testHgetall : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.hset "hash" "f1" "v1".toUTF8
  let _ ← mock.hset "hash" "f2" "v2".toUTF8
  let all ← mock.hgetall "hash"
  return all.length == 2

def testHexists : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.hset "hash" "exists" "value".toUTF8
  let e1 ← mock.hexists "hash" "exists"
  let e2 ← mock.hexists "hash" "notexists"
  let e3 ← mock.hexists "nohash" "field"
  return e1 && !e2 && !e3

def testHlen : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.hset "hash" "f1" "v1".toUTF8
  let _ ← mock.hset "hash" "f2" "v2".toUTF8
  let _ ← mock.hset "hash" "f3" "v3".toUTF8
  let len ← mock.hlen "hash"
  return len == 3

def testHkeys : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.hset "hash" "a" "1".toUTF8
  let _ ← mock.hset "hash" "b" "2".toUTF8
  let keys ← mock.hkeys "hash"
  return keys.length == 2

def testHvals : IO Bool := do
  let mock ← MockRedis.create
  let _ ← mock.hset "hash" "a" "1".toUTF8
  let _ ← mock.hset "hash" "b" "2".toUTF8
  let vals ← mock.hvals "hash"
  return vals.length == 2

def hashOperationTests : TestSeq :=
  test "HSET and HGET" (ioTest testHsetHget) $
  test "HGET non-existent field" (ioTest testHgetNonExistent) $
  test "HSET returns 1 for new, 0 for existing" (ioTest testHsetNewField) $
  test "HDEL deletes field" (ioTest testHdel) $
  test "HGETALL returns all pairs" (ioTest testHgetall) $
  test "HEXISTS checks field existence" (ioTest testHexists) $
  test "HLEN returns field count" (ioTest testHlen) $
  test "HKEYS returns all field names" (ioTest testHkeys) $
  test "HVALS returns all values" (ioTest testHvals)

-- Key Pattern and Utility Tests

def testKeys : IO Bool := do
  let mock ← MockRedis.create
  mock.set "user:1" "a".toUTF8
  mock.set "user:2" "b".toUTF8
  mock.set "order:1" "c".toUTF8
  let userKeys ← mock.keys "user:*"
  let allKeys ← mock.keys "*"
  return userKeys.length == 2 && allKeys.length == 3

def testKeysSuffix : IO Bool := do
  let mock ← MockRedis.create
  mock.set "file.txt" "a".toUTF8
  mock.set "file.pdf" "b".toUTF8
  mock.set "other.txt" "c".toUTF8
  let txtFiles ← mock.keys "*.txt"
  return txtFiles.length == 2

def testExpire : IO Bool := do
  let mock ← MockRedis.create
  mock.set "key" "value".toUTF8
  let ok ← mock.expire "key" 3600
  let fail ← mock.expire "nonexistent" 3600
  return ok && !fail

def testTtl : IO Bool := do
  let mock ← MockRedis.create
  mock.setex "key" "value".toUTF8 3600
  let ttlVal ← mock.ttl "key"
  return ttlVal > 0 && ttlVal <= 3600

def testFlushall : IO Bool := do
  let mock ← MockRedis.create
  mock.set "key1" "value1".toUTF8
  let _ ← mock.lpush "list" ["a".toUTF8]
  let _ ← mock.sadd "set" "member".toUTF8
  let _ ← mock.hset "hash" "field" "value".toUTF8
  mock.flushall
  let size ← mock.dbsize
  return size == 0

def testDbsize : IO Bool := do
  let mock ← MockRedis.create
  mock.set "k1" "v1".toUTF8
  mock.set "k2" "v2".toUTF8
  let _ ← mock.lpush "list" ["a".toUTF8]
  let size ← mock.dbsize
  return size == 3

def utilityOperationTests : TestSeq :=
  test "KEYS with prefix pattern" (ioTest testKeys) $
  test "KEYS with suffix pattern" (ioTest testKeysSuffix) $
  test "EXPIRE sets expiration" (ioTest testExpire) $
  test "TTL returns time-to-live" (ioTest testTtl) $
  test "FLUSHALL clears all data" (ioTest testFlushall) $
  test "DBSIZE returns key count" (ioTest testDbsize)

-- Cross-Type Isolation Tests

def testTypeIsolation : IO Bool := do
  let mock ← MockRedis.create
  -- Same key name, different data types should be isolated
  mock.set "key" "string".toUTF8
  let _ ← mock.lpush "listkey" ["item".toUTF8]
  let _ ← mock.sadd "setkey" "member".toUTF8
  let _ ← mock.hset "hashkey" "field" "value".toUTF8
  -- Verify each type is separate
  let strVal ← mock.get "key"
  let listVal ← mock.lrange "listkey" 0 (-1)
  let setVal ← mock.smembers "setkey"
  let hashVal ← mock.hget "hashkey" "field"
  return strVal.isSome && listVal.length == 1 && setVal.length == 1 && hashVal.isSome

def testDelAcrossTypes : IO Bool := do
  let mock ← MockRedis.create
  mock.set "key" "string".toUTF8
  let _ ← mock.lpush "key" ["item".toUTF8]  -- Different internal storage
  let _ ← mock.del ["key"]
  let strGone ← mock.get "key"
  let listGone ← mock.llen "key"
  return strGone.isNone && listGone == 0

def typeIsolationTests : TestSeq :=
  test "Different types are isolated" (ioTest testTypeIsolation) $
  test "DEL removes from all type stores" (ioTest testDelAcrossTypes)

-- All Mock Tests
def allMockTests : TestSeq :=
  group "String Operations" stringOperationTests $
  group "List Operations" listOperationTests $
  group "Set Operations" setOperationTests $
  group "Hash Operations" hashOperationTests $
  group "Utility Operations" utilityOperationTests $
  group "Type Isolation" typeIsolationTests

end RedisTests.MockTests
