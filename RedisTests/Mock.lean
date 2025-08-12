import Std.Data.HashMap
import RedisLean.Codec
import RedisLean.Error
import RedisLean.Monad
import RedisLean.Metrics

namespace Redis

/-- In-memory Redis mock for testing without a live Redis server.
    Simulates basic Redis data structures and operations. -/
structure MockRedis where
  /-- String/ByteArray values (GET/SET) -/
  data : IO.Ref (Std.HashMap String ByteArray)
  /-- List values (LPUSH/RPUSH/etc) -/
  lists : IO.Ref (Std.HashMap String (Array ByteArray))
  /-- Set values (SADD/SREM/etc) -/
  sets : IO.Ref (Std.HashMap String (Array ByteArray))
  /-- Hash values (HSET/HGET/etc) -/
  hashes : IO.Ref (Std.HashMap String (Std.HashMap String ByteArray))
  /-- Key expiry times in nanoseconds (0 = no expiry) -/
  expiry : IO.Ref (Std.HashMap String Nat)

namespace MockRedis

/-- Create a new empty MockRedis instance -/
def create : IO MockRedis := do
  let data ← IO.mkRef (Std.HashMap.emptyWithCapacity 64)
  let lists ← IO.mkRef (Std.HashMap.emptyWithCapacity 32)
  let sets ← IO.mkRef (Std.HashMap.emptyWithCapacity 32)
  let hashes ← IO.mkRef (Std.HashMap.emptyWithCapacity 32)
  let expiry ← IO.mkRef (Std.HashMap.emptyWithCapacity 64)
  return { data, lists, sets, hashes, expiry }

/-- Check if a key has expired -/
private def isExpired (m : MockRedis) (key : String) : IO Bool := do
  let exp ← m.expiry.get
  match exp.get? key with
  | none => return false
  | some 0 => return false
  | some expiryTime =>
    let now ← IO.monoNanosNow
    return now > expiryTime

/-- Remove expired key from all stores -/
private def removeExpiredKey (m : MockRedis) (key : String) : IO Unit := do
  m.data.modify (·.erase key)
  m.lists.modify (·.erase key)
  m.sets.modify (·.erase key)
  m.hashes.modify (·.erase key)
  m.expiry.modify (·.erase key)

/-- Check expiry and remove if expired, returns true if key was valid -/
private def checkExpiry (m : MockRedis) (key : String) : IO Bool := do
  let expired ← isExpired m key
  if expired then
    removeExpiredKey m key
    return false
  return true

-- String operations

/-- SET operation -/
def set (m : MockRedis) (key : String) (value : ByteArray) : IO Unit := do
  m.data.modify (·.insert key value)

/-- GET operation -/
def get (m : MockRedis) (key : String) : IO (Option ByteArray) := do
  let valid ← checkExpiry m key
  if !valid then return none
  let d ← m.data.get
  return d.get? key

/-- SETEX operation - set with expiration in seconds -/
def setex (m : MockRedis) (key : String) (value : ByteArray) (seconds : Nat) : IO Unit := do
  m.data.modify (·.insert key value)
  let now ← IO.monoNanosNow
  let expiryTime := now + seconds * 1000000000
  m.expiry.modify (·.insert key expiryTime)

/-- DEL operation - returns count of deleted keys -/
def del (m : MockRedis) (keyList : List String) : IO Nat := do
  let mut count := 0
  for key in keyList do
    let d ← m.data.get
    if d.contains key then count := count + 1
    m.data.modify (·.erase key)
    m.lists.modify (·.erase key)
    m.sets.modify (·.erase key)
    m.hashes.modify (·.erase key)
    m.expiry.modify (·.erase key)
  return count

/-- EXISTS operation -/
def keyExists (m : MockRedis) (key : String) : IO Bool := do
  let valid ← checkExpiry m key
  if !valid then return false
  let d ← m.data.get
  let l ← m.lists.get
  let s ← m.sets.get
  let h ← m.hashes.get
  return d.contains key || l.contains key || s.contains key || h.contains key

/-- KEYS operation - returns keys matching pattern (simple * glob support) -/
def keys (m : MockRedis) (pattern : String) : IO (List String) := do
  let d ← m.data.get
  let l ← m.lists.get
  let s ← m.sets.get
  let h ← m.hashes.get
  let allKeys := d.toList.map Prod.fst ++
                 l.toList.map Prod.fst ++
                 s.toList.map Prod.fst ++
                 h.toList.map Prod.fst
  let uniqueKeys := allKeys.eraseDups
  -- Simple pattern matching (supports * as wildcard)
  let matched := uniqueKeys.filter (matchPattern pattern)
  -- Filter out expired keys
  let mut result := []
  for key in matched do
    let valid ← checkExpiry m key
    if valid then result := key :: result
  return result.reverse
where
  matchPattern (pattern : String) (key : String) : Bool :=
    if pattern == "*" then true
    else if pattern.endsWith "*" then
      let patternPrefix := (pattern.dropEnd 1).toString
      key.startsWith patternPrefix
    else if pattern.startsWith "*" then
      let suffix := pattern.drop 1
      key.endsWith suffix
    else
      pattern == key

/-- EXPIRE operation -/
def expire (m : MockRedis) (key : String) (seconds : Nat) : IO Bool := do
  let keyExist ← m.keyExists key
  if keyExist then
    let now ← IO.monoNanosNow
    let expiryTime := now + seconds * 1000000000
    m.expiry.modify (·.insert key expiryTime)
    return true
  return false

/-- TTL operation - returns seconds until expiry, 0 if no expiry -/
def ttl (m : MockRedis) (key : String) : IO Nat := do
  let exp ← m.expiry.get
  match exp.get? key with
  | none => return 0
  | some 0 => return 0
  | some expiryTime =>
    let now ← IO.monoNanosNow
    if now >= expiryTime then return 0
    return (expiryTime - now) / 1000000000

/-- INCR operation -/
def incr (m : MockRedis) (key : String) : IO Int := do
  let val ← get m key
  let current := match val with
    | some bs => match String.fromUTF8? bs >>= String.toInt? with
      | some n => n
      | none => 0
    | none => 0
  let newVal := current + 1
  set m key (String.toUTF8 (toString newVal))
  return newVal

/-- DECR operation -/
def decr (m : MockRedis) (key : String) : IO Int := do
  let val ← get m key
  let current := match val with
    | some bs => match String.fromUTF8? bs >>= String.toInt? with
      | some n => n
      | none => 0
    | none => 0
  let newVal := current - 1
  set m key (String.toUTF8 (toString newVal))
  return newVal

-- List operations

/-- LPUSH operation -/
def lpush (m : MockRedis) (key : String) (values : List ByteArray) : IO Nat := do
  let _ ← checkExpiry m key
  m.lists.modify fun h =>
    let current := h.getD key #[]
    let newList := values.toArray.reverse ++ current
    h.insert key newList
  let l ← m.lists.get
  return (l.getD key #[]).size

/-- RPUSH operation -/
def rpush (m : MockRedis) (key : String) (values : List ByteArray) : IO Nat := do
  let _ ← checkExpiry m key
  m.lists.modify fun h =>
    let current := h.getD key #[]
    let newList := current ++ values.toArray
    h.insert key newList
  let l ← m.lists.get
  return (l.getD key #[]).size

/-- LPOP operation -/
def lpop (m : MockRedis) (key : String) : IO (Option ByteArray) := do
  let valid ← checkExpiry m key
  if !valid then return none
  let l ← m.lists.get
  match l.get? key with
  | none => return none
  | some arr =>
    if arr.size == 0 then return none
    let val := arr[0]!
    m.lists.modify (·.insert key (arr.extract 1 arr.size))
    return some val

/-- RPOP operation -/
def rpop (m : MockRedis) (key : String) : IO (Option ByteArray) := do
  let valid ← checkExpiry m key
  if !valid then return none
  let l ← m.lists.get
  match l.get? key with
  | none => return none
  | some arr =>
    if arr.size == 0 then return none
    let val := arr[arr.size - 1]!
    m.lists.modify (·.insert key (arr.extract 0 (arr.size - 1)))
    return some val

/-- LRANGE operation -/
def lrange (m : MockRedis) (key : String) (start stop : Int) : IO (List ByteArray) := do
  let valid ← checkExpiry m key
  if !valid then return []
  let l ← m.lists.get
  match l.get? key with
  | none => return []
  | some arr =>
    let len := arr.size
    let s := if start < 0 then Int.toNat (Int.ofNat len + start) else start.toNat
    let e := if stop < 0 then Int.toNat (Int.ofNat len + stop) else stop.toNat
    let s' := min s len
    let e' := min (e + 1) len
    return (arr.extract s' e').toList

/-- LLEN operation -/
def llen (m : MockRedis) (key : String) : IO Nat := do
  let valid ← checkExpiry m key
  if !valid then return 0
  let l ← m.lists.get
  return (l.getD key #[]).size

-- Set operations

/-- SADD operation -/
def sadd (m : MockRedis) (key : String) (member : ByteArray) : IO Nat := do
  let _ ← checkExpiry m key
  let s ← m.sets.get
  let current := s.getD key #[]
  if current.contains member then return 0
  m.sets.modify (·.insert key (current.push member))
  return 1

/-- SREM operation -/
def srem (m : MockRedis) (key : String) (members : List ByteArray) : IO Nat := do
  let valid ← checkExpiry m key
  if !valid then return 0
  let s ← m.sets.get
  match s.get? key with
  | none => return 0
  | some arr =>
    let mut removed := 0
    let mut newArr := arr
    for member in members do
      if newArr.contains member then
        newArr := newArr.filter (· != member)
        removed := removed + 1
    m.sets.modify (·.insert key newArr)
    return removed

/-- SMEMBERS operation -/
def smembers (m : MockRedis) (key : String) : IO (List ByteArray) := do
  let valid ← checkExpiry m key
  if !valid then return []
  let s ← m.sets.get
  return (s.getD key #[]).toList

/-- SISMEMBER operation -/
def sismember (m : MockRedis) (key : String) (member : ByteArray) : IO Bool := do
  let valid ← checkExpiry m key
  if !valid then return false
  let s ← m.sets.get
  return (s.getD key #[]).contains member

/-- SCARD operation -/
def scard (m : MockRedis) (key : String) : IO Nat := do
  let valid ← checkExpiry m key
  if !valid then return 0
  let s ← m.sets.get
  return (s.getD key #[]).size

-- Hash operations

/-- HSET operation -/
def hset (m : MockRedis) (key field : String) (value : ByteArray) : IO Nat := do
  let _ ← checkExpiry m key
  let h ← m.hashes.get
  let current := h.getD key (Std.HashMap.emptyWithCapacity 8)
  let isNew := !current.contains field
  m.hashes.modify (·.insert key (current.insert field value))
  return if isNew then 1 else 0

/-- HGET operation -/
def hget (m : MockRedis) (key field : String) : IO (Option ByteArray) := do
  let valid ← checkExpiry m key
  if !valid then return none
  let h ← m.hashes.get
  match h.get? key with
  | none => return none
  | some fields => return fields.get? field

/-- HDEL operation -/
def hdel (m : MockRedis) (key field : String) : IO Nat := do
  let valid ← checkExpiry m key
  if !valid then return 0
  let h ← m.hashes.get
  match h.get? key with
  | none => return 0
  | some fields =>
    if fields.contains field then
      m.hashes.modify (·.insert key (fields.erase field))
      return 1
    return 0

/-- HGETALL operation -/
def hgetall (m : MockRedis) (key : String) : IO (List (String × ByteArray)) := do
  let valid ← checkExpiry m key
  if !valid then return []
  let h ← m.hashes.get
  match h.get? key with
  | none => return []
  | some fields => return fields.toList

/-- HEXISTS operation -/
def hexists (m : MockRedis) (key field : String) : IO Bool := do
  let valid ← checkExpiry m key
  if !valid then return false
  let h ← m.hashes.get
  match h.get? key with
  | none => return false
  | some fields => return fields.contains field

/-- HLEN operation -/
def hlen (m : MockRedis) (key : String) : IO Nat := do
  let valid ← checkExpiry m key
  if !valid then return 0
  let h ← m.hashes.get
  match h.get? key with
  | none => return 0
  | some fields => return fields.size

/-- HKEYS operation -/
def hkeys (m : MockRedis) (key : String) : IO (List String) := do
  let valid ← checkExpiry m key
  if !valid then return []
  let h ← m.hashes.get
  match h.get? key with
  | none => return []
  | some fields => return fields.toList.map Prod.fst

/-- HVALS operation -/
def hvals (m : MockRedis) (key : String) : IO (List ByteArray) := do
  let valid ← checkExpiry m key
  if !valid then return []
  let h ← m.hashes.get
  match h.get? key with
  | none => return []
  | some fields => return fields.toList.map Prod.snd

-- Utility operations

/-- Clear all data in the mock -/
def flushall (m : MockRedis) : IO Unit := do
  m.data.set (Std.HashMap.emptyWithCapacity 64)
  m.lists.set (Std.HashMap.emptyWithCapacity 32)
  m.sets.set (Std.HashMap.emptyWithCapacity 32)
  m.hashes.set (Std.HashMap.emptyWithCapacity 32)
  m.expiry.set (Std.HashMap.emptyWithCapacity 64)

/-- DBSIZE operation - returns total key count -/
def dbsize (m : MockRedis) : IO Nat := do
  let d ← m.data.get
  let l ← m.lists.get
  let s ← m.sets.get
  let h ← m.hashes.get
  let allKeys := d.toList.map Prod.fst ++
                 l.toList.map Prod.fst ++
                 s.toList.map Prod.fst ++
                 h.toList.map Prod.fst
  return allKeys.eraseDups.length

end MockRedis

/-- Run a RedisM action against a mock Redis instance.
    This creates a mock state and executes the action without a real Redis connection.

    Note: This is a placeholder API. For actual testing, use MockRedis methods directly
    since RedisM actions use FFI calls that cannot be intercepted. -/
def runMock (_mock : MockRedis) (_action : RedisM α) : IO (Except Error α) := do
  -- We can't actually run the real RedisM actions against a mock,
  -- so this returns an error explaining the limitation.
  -- Users should use MockRedis methods directly for testing.
  return .error (.otherError "MockRedis requires direct method calls, not RedisM actions. Use MockRedis methods directly for testing.")

end Redis
