import RedisLean.Codec
import RedisLean.FFI
import RedisLean.Enums
import RedisLean.Monad

namespace Redis

-- Redis operations collected in a single capability interface (typeclass)
-- [should describe: algebra of capabilities, i.e. the properties of these operations, including composition and pipelines]
-- [possibly separate publish from the other capabilities]
-- α is the type of the keys (implementing Codec)
-- β is the type of bytearray-based values (implemented via Codec)
-- RedisValue is the type of Redis values (as returned by typeKey)
class Ops (α: Type) [Codec α] (m : Type → Type) where
  -- operations on strings (general bytearray-based values in Redis terminology)
  set {β : Type} [Codec β] : α → β → m Unit
  setnx {β : Type} [Codec β] : α → β → m Unit
  setxx {β : Type} [Codec β] : α → β → m Unit
  setex {β : Type} [Codec β] : α → β → Nat → m Unit
  setexnx {β : Type} [Codec β] : α → β → Nat → m Unit
  setexxx {β : Type} [Codec β] : α → β → Nat → m Unit
  get : α → m ByteArray
  getAs (β : Type) [Codec β] : α → m β
  append {β : Type} [Codec β] : α → β → m Nat
  getdel : α → m ByteArray
  getrange : α → Int → Int → m ByteArray
  strlen : α → m Nat
  incrByFloat : α → Float → m Float

  -- operations on keys
  del : List α → m Nat
  existsKey : α → m Bool
  typeKey : α → m RedisValue
  keys : ByteArray → m (List ByteArray)
  scan : Nat → Option ByteArray → Option Nat → m (Nat × List ByteArray)
  expire : α → Nat → m Bool
  expireAt : α → Nat → m Bool
  pexpire : α → Nat → m Bool
  pexpireAt : α → Nat → m Bool
  persist : α → m Bool
  rename : α → α → m Unit
  renamenx : α → α → m Bool
  copy : α → α → Bool → m Bool
  unlink : List α → m Nat
  touch : List α → m Nat

  -- operations on strings that can be parsed as integers
  incr : α → m Int
  incrBy : α → Int → m Int
  decr : α → m Int
  decrBy : α → Int → m Int

  -- operations on sets
  sismember {β : Type} [Codec β] : α → β → m Bool
  scard : α → m Nat
  sadd {β : Type} [Codec β] : α → β → m Nat
  smembers : α → m (List ByteArray)
  srem {β : Type} [Codec β] : α → List β → m Nat
  spop : α → Option Nat → m (List ByteArray)
  srandmember : α → Option Nat → m (List ByteArray)
  smove {β : Type} [Codec β] : α → α → β → m Bool
  sdiff : List α → m (List ByteArray)
  sdiffstore : α → List α → m Nat
  sinter : List α → m (List ByteArray)
  sinterstore : α → List α → m Nat
  sunion : List α → m (List ByteArray)
  sunionstore : α → List α → m Nat
  sscan : α → Nat → Option ByteArray → Option Nat → m (Nat × List ByteArray)

  -- operations on lists
  lpush {β : Type} [Codec β] : α → List β → m Nat
  rpush {β : Type} [Codec β] : α → List β → m Nat
  lpushx {β : Type} [Codec β] : α → List β → m Nat
  rpushx {β : Type} [Codec β] : α → List β → m Nat
  lpop : α → Option Nat → m (List ByteArray)
  rpop : α → Option Nat → m (List ByteArray)
  lrange : α → Int → Int → m (List ByteArray)
  lindex : α → Int → m ByteArray
  llen : α → m Nat
  lset {β : Type} [Codec β] : α → Int → β → m Unit
  linsertBefore {β γ : Type} [Codec β] [Codec γ] : α → β → γ → m Int
  linsertAfter {β γ : Type} [Codec β] [Codec γ] : α → β → γ → m Int
  ltrim : α → Int → Int → m Unit
  lrem {β : Type} [Codec β] : α → Int → β → m Nat

  -- operations on hashes
  hset {β γ : Type} [Codec β] [Codec γ] : α → β → γ → m Nat
  hget {β : Type} [Codec β] : α → β → m ByteArray
  hgetAs (β γ : Type) [Codec β] [Codec γ] : α → β → m γ
  hgetall : α → m (List ByteArray)
  hdel {β : Type} [Codec β] : α → β → m Nat
  hexists {β : Type} [Codec β] : α → β → m Bool
  hincrby {β : Type} [Codec β] : α → β → Int → m Nat
  hkeys : α → m (List ByteArray)
  hlen : α → m Nat
  hvals : α → m (List ByteArray)
  hsetnx {β γ : Type} [Codec β] [Codec γ] : α → β → γ → m Bool
  hmget {β : Type} [Codec β] : α → List β → m (List (Option ByteArray))
  hincrbyfloat {β : Type} [Codec β] : α → β → Float → m Float
  hscan {β : Type} [Codec β] : α → Nat → Option ByteArray → Option Nat → m (Nat × List ByteArray)

  -- operations on sorted sets
  zadd {β : Type} [Codec β] : α → Float → β → m Nat
  zcard : α → m Nat
  zrange : α → Int → Int → m (List ByteArray)
  zscore {β : Type} [Codec β] : α → β → m (Option Float)
  zrank {β : Type} [Codec β] : α → β → m (Option Nat)
  zrevrank {β : Type} [Codec β] : α → β → m (Option Nat)
  zcount : α → String → String → m Nat
  zincrby {β : Type} [Codec β] : α → Float → β → m Float
  zrem {β : Type} [Codec β] : α → List β → m Nat
  zrangebyscore : α → String → String → m (List ByteArray)
  zrevrange : α → Int → Int → m (List ByteArray)
  zrevrangebyscore : α → String → String → m (List ByteArray)
  zremrangebyrank : α → Int → Int → m Nat
  zremrangebyscore : α → String → String → m Nat
  zpopmin : α → Option Nat → m (List ByteArray)
  zpopmax : α → Option Nat → m (List ByteArray)
  zscan : α → Nat → Option ByteArray → Option Nat → m (Nat × List ByteArray)

  -- HyperLogLog operations
  pfadd {β : Type} [Codec β] : α → List β → m Bool
  pfcount : List α → m Nat
  pfmerge : α → List α → m Unit

  -- Bitmap operations
  setbit : α → Nat → Bool → m Bool
  getbit : α → Nat → m Bool
  bitcount : α → Option Int → Option Int → m Nat

  -- Pub/Sub operations
  publish {β: Type} [Codec β] : String → β → m Nat
  subscribe : String → m Bool

  -- Authentication and protocol operations
  auth : String → m Bool
  hello : Nat → m ByteArray

  -- TTL operations
  ttl : α → m Nat
  pttl : α → m Nat

  -- Redis Streams operations
  xadd {β : Type} [Codec β] : α → String → List (α × β) → m String
  xread : List (α × String) → Option Nat → Option Nat → m ByteArray
  xrange : α → String → String → Option Nat → m ByteArray
  xlen : α → m Nat
  xdel : α → List String → m Nat
  xtrim : α → String → Nat → m Nat

  -- Connection operations
  ping : α → m Bool
  selectDb : Nat → m Unit
  echoMsg : ByteArray → m ByteArray

  -- Server operations
  dbsize : m Nat
  flushall : String → m Bool

-- implementation for the RedisM monad using FFI.hiredis
instance [Codec α] : Ops α RedisM where
  -- String operations
  set := fun k v => liftRedisEIO RedisCmd.SET (fun ctx => FFI.Internal.set ctx (Codec.enc k) (Codec.enc v) FFI.SetExistsOption.none.toUInt8)
  setnx := fun k v => liftRedisEIO RedisCmd.SET (fun ctx => FFI.Internal.set ctx (Codec.enc k) (Codec.enc v) FFI.SetExistsOption.nx.toUInt8)
  setxx := fun k v => liftRedisEIO RedisCmd.SET (fun ctx => FFI.Internal.set ctx (Codec.enc k) (Codec.enc v) FFI.SetExistsOption.xx.toUInt8)
  setex := fun k v msec => liftRedisEIO RedisCmd.SETEX (fun ctx => FFI.Internal.setex ctx (Codec.enc k) (Codec.enc v) (UInt64.ofNat msec) FFI.SetExistsOption.none.toUInt8)
  setexnx := fun k v msec => liftRedisEIO RedisCmd.SETEX (fun ctx => FFI.Internal.setex ctx (Codec.enc k) (Codec.enc v) (UInt64.ofNat msec) FFI.SetExistsOption.nx.toUInt8)
  setexxx := fun k v msec => liftRedisEIO RedisCmd.SETEX (fun ctx => FFI.Internal.setex ctx (Codec.enc k) (Codec.enc v) (UInt64.ofNat msec) FFI.SetExistsOption.xx.toUInt8)
  get := fun k => do
    let tmp ← liftRedisEIO RedisCmd.GET (fun ctx => FFI.Internal.get ctx (Codec.enc k))
    return tmp
  getAs := fun β [Codec β] k => do
    let tmp ← liftRedisEIO RedisCmd.GET (fun ctx => FFI.Internal.get ctx (Codec.enc k))
    match Codec.dec tmp with
    | .ok value => return value
    | .error msg => throw (Error.otherError s!"Codec decoding failed: {msg}")
  append := fun k v => do
    let result ← liftRedisEIO RedisCmd.APPEND (fun ctx => FFI.Internal.append ctx (Codec.enc k) (Codec.enc v))
    return result.toNat
  getdel := fun k => liftRedisEIO RedisCmd.GETDEL (fun ctx => FFI.Internal.getdel ctx (Codec.enc k))
  getrange := fun k start end_ => liftRedisEIO RedisCmd.GETRANGE (fun ctx => FFI.Internal.getrange ctx (Codec.enc k) (Int64.ofInt start) (Int64.ofInt end_))
  strlen := fun k => do
    let result ← liftRedisEIO RedisCmd.STRLEN (fun ctx => FFI.Internal.strlen ctx (Codec.enc k))
    return result.toNat
  incrByFloat := fun k increment => liftRedisEIO RedisCmd.INCRBYFLOAT (fun ctx => FFI.Internal.incrbyfloat ctx (Codec.enc k) increment)

  -- Key operations
  del := fun ks => do
    let result ← liftRedisEIO RedisCmd.DEL (fun ctx => FFI.Internal.del ctx (ks.map Codec.enc))
    return result.toNat
  existsKey := fun k => liftRedisEIO RedisCmd.EXISTS (fun ctx => FFI.Internal.existsKey ctx (Codec.enc k))
  typeKey := fun k => do
    let typeString ← liftRedisEIO RedisCmd.TYPE (fun ctx => FFI.Internal.typeKey ctx (Codec.enc k))
    return RedisValue.fromString typeString
  keys := fun pattern => liftRedisEIO RedisCmd.KEYS (fun ctx => FFI.Internal.keys ctx pattern)
  scan := fun cursor pattern count => do
    let count_u64 := count.map UInt64.ofNat
    let result ← liftRedisEIO RedisCmd.SCAN (fun ctx => FFI.Internal.scan ctx (UInt64.ofNat cursor) pattern count_u64 none)
    return (result.1.toNat, result.2)
  expire := fun k seconds => liftRedisEIO RedisCmd.EXPIRE (fun ctx => FFI.Internal.expire ctx (Codec.enc k) (UInt64.ofNat seconds))
  expireAt := fun k timestamp => liftRedisEIO RedisCmd.EXPIREAT (fun ctx => FFI.Internal.expireat ctx (Codec.enc k) (UInt64.ofNat timestamp))
  pexpire := fun k milliseconds => liftRedisEIO RedisCmd.PEXPIRE (fun ctx => FFI.Internal.pexpire ctx (Codec.enc k) (UInt64.ofNat milliseconds))
  pexpireAt := fun k timestamp => liftRedisEIO RedisCmd.PEXPIREAT (fun ctx => FFI.Internal.pexpireat ctx (Codec.enc k) (UInt64.ofNat timestamp))
  persist := fun k => liftRedisEIO RedisCmd.PERSIST (fun ctx => FFI.Internal.persistKey ctx (Codec.enc k))
  rename := fun k newkey => liftRedisEIO RedisCmd.RENAME (fun ctx => FFI.Internal.renameKey ctx (Codec.enc k) (Codec.enc newkey))
  renamenx := fun k newkey => liftRedisEIO RedisCmd.RENAMENX (fun ctx => FFI.Internal.renamenx ctx (Codec.enc k) (Codec.enc newkey))
  copy := fun src dst replace => liftRedisEIO RedisCmd.COPY (fun ctx => FFI.Internal.copyKey ctx (Codec.enc src) (Codec.enc dst) (if replace then 1 else 0))
  unlink := fun ks => do
    let result ← liftRedisEIO RedisCmd.UNLINK (fun ctx => FFI.Internal.unlink ctx (ks.map Codec.enc))
    return result.toNat
  touch := fun ks => do
    let result ← liftRedisEIO RedisCmd.TOUCH (fun ctx => FFI.Internal.touch ctx (ks.map Codec.enc))
    return result.toNat

  -- Numeric string operations
  incr := fun k => do
    let result ← liftRedisEIO RedisCmd.INCR (fun ctx => FFI.Internal.incr ctx (Codec.enc k))
    return Int.ofNat result.toNat
  incrBy := fun k n => do
    let result ← liftRedisEIO RedisCmd.INCRBY (fun ctx => FFI.Internal.incrby ctx (Codec.enc k) (Int64.ofInt n))
    return Int.ofNat result.toNat
  decr := fun k => do
    let result ← liftRedisEIO RedisCmd.DECR (fun ctx => FFI.Internal.decr ctx (Codec.enc k))
    return Int.ofNat result.toNat
  decrBy := fun k decrement => do
    let result ← liftRedisEIO RedisCmd.DECRBY (fun ctx => FFI.Internal.decrby ctx (Codec.enc k) (Int64.ofInt decrement))
    return Int.ofNat result.toNat

  -- Set operations
  sismember := fun k member => liftRedisEIO RedisCmd.SISMEMBER (fun ctx => FFI.Internal.sismember ctx (Codec.enc k) (Codec.enc member))
  scard := fun k => do
    let result ← liftRedisEIO RedisCmd.SCARD (fun ctx => FFI.Internal.scard ctx (Codec.enc k))
    return result.toNat
  sadd := fun k member => do
    let result ← liftRedisEIO RedisCmd.SADD (fun ctx => FFI.Internal.sadd ctx (Codec.enc k) (Codec.enc member))
    return result.toNat
  smembers := fun k => liftRedisEIO RedisCmd.SMEMBERS (fun ctx => FFI.Internal.smembers ctx (Codec.enc k))
  srem := fun k members => do
    let result ← liftRedisEIO RedisCmd.SREM (fun ctx => FFI.Internal.srem ctx (Codec.enc k) (members.map Codec.enc))
    return result.toNat
  spop := fun k count => liftRedisEIO RedisCmd.SPOP (fun ctx => FFI.Internal.spop ctx (Codec.enc k) (count.map UInt64.ofNat))
  srandmember := fun k count => liftRedisEIO RedisCmd.SRANDMEMBER (fun ctx => FFI.Internal.srandmember ctx (Codec.enc k) (count.map UInt64.ofNat))
  smove := fun src dst member => liftRedisEIO RedisCmd.SMOVE (fun ctx => FFI.Internal.smove ctx (Codec.enc src) (Codec.enc dst) (Codec.enc member))
  sdiff := fun keys => liftRedisEIO RedisCmd.SDIFF (fun ctx => FFI.Internal.sdiff ctx (keys.map Codec.enc))
  sdiffstore := fun dst keys => do
    let result ← liftRedisEIO RedisCmd.SDIFFSTORE (fun ctx => FFI.Internal.sdiffstore ctx (Codec.enc dst) (keys.map Codec.enc))
    return result.toNat
  sinter := fun keys => liftRedisEIO RedisCmd.SINTER (fun ctx => FFI.Internal.sinter ctx (keys.map Codec.enc))
  sinterstore := fun dst keys => do
    let result ← liftRedisEIO RedisCmd.SINTERSTORE (fun ctx => FFI.Internal.sinterstore ctx (Codec.enc dst) (keys.map Codec.enc))
    return result.toNat
  sunion := fun keys => liftRedisEIO RedisCmd.SUNION (fun ctx => FFI.Internal.sunion ctx (keys.map Codec.enc))
  sunionstore := fun dst keys => do
    let result ← liftRedisEIO RedisCmd.SUNIONSTORE (fun ctx => FFI.Internal.sunionstore ctx (Codec.enc dst) (keys.map Codec.enc))
    return result.toNat
  sscan := fun k cursor pattern count => do
    let count_u64 := count.map UInt64.ofNat
    let result ← liftRedisEIO RedisCmd.SSCAN (fun ctx => FFI.Internal.sscan ctx (Codec.enc k) (UInt64.ofNat cursor) pattern count_u64)
    return (result.1.toNat, result.2)

  -- List operations
  lpush := fun k values => do
    let result ← liftRedisEIO RedisCmd.LPUSH (fun ctx => FFI.Internal.lpush ctx (Codec.enc k) (values.map Codec.enc))
    return result.toNat
  rpush := fun k values => do
    let result ← liftRedisEIO RedisCmd.RPUSH (fun ctx => FFI.Internal.rpush ctx (Codec.enc k) (values.map Codec.enc))
    return result.toNat
  lpushx := fun k values => do
    let result ← liftRedisEIO RedisCmd.LPUSHX (fun ctx => FFI.Internal.lpushx ctx (Codec.enc k) (values.map Codec.enc))
    return result.toNat
  rpushx := fun k values => do
    let result ← liftRedisEIO RedisCmd.RPUSHX (fun ctx => FFI.Internal.rpushx ctx (Codec.enc k) (values.map Codec.enc))
    return result.toNat
  lpop := fun k count => liftRedisEIO RedisCmd.LPOP (fun ctx => FFI.Internal.lpop ctx (Codec.enc k) (count.map UInt64.ofNat))
  rpop := fun k count => liftRedisEIO RedisCmd.RPOP (fun ctx => FFI.Internal.rpop ctx (Codec.enc k) (count.map UInt64.ofNat))
  lrange := fun k start stop => liftRedisEIO RedisCmd.LRANGE (fun ctx => FFI.Internal.lrange ctx (Codec.enc k) (Int64.ofInt start) (Int64.ofInt stop))
  lindex := fun k index => liftRedisEIO RedisCmd.LINDEX (fun ctx => FFI.Internal.lindex ctx (Codec.enc k) (Int64.ofInt index))
  llen := fun k => do
    let result ← liftRedisEIO RedisCmd.LLEN (fun ctx => FFI.Internal.llen ctx (Codec.enc k))
    return result.toNat
  lset := fun k index value => liftRedisEIO RedisCmd.LSET (fun ctx => FFI.Internal.lset ctx (Codec.enc k) (Int64.ofInt index) (Codec.enc value))
  linsertBefore := fun k pivot value => do
    let result ← liftRedisEIO RedisCmd.LINSERT (fun ctx => FFI.Internal.linsert ctx (Codec.enc k) 0 (Codec.enc pivot) (Codec.enc value))
    return result.toInt
  linsertAfter := fun k pivot value => do
    let result ← liftRedisEIO RedisCmd.LINSERT (fun ctx => FFI.Internal.linsert ctx (Codec.enc k) 1 (Codec.enc pivot) (Codec.enc value))
    return result.toInt
  ltrim := fun k start stop => liftRedisEIO RedisCmd.LTRIM (fun ctx => FFI.Internal.ltrim ctx (Codec.enc k) (Int64.ofInt start) (Int64.ofInt stop))
  lrem := fun k count element => do
    let result ← liftRedisEIO RedisCmd.LREM (fun ctx => FFI.Internal.lrem ctx (Codec.enc k) (Int64.ofInt count) (Codec.enc element))
    return result.toNat

  -- Hash operations
  hset := fun {β γ} [Codec β] [Codec γ] k field value => do
    let result ← liftRedisEIO RedisCmd.HSET (fun ctx => FFI.Internal.hset ctx (Codec.enc k) (Codec.enc field) (Codec.enc value))
    return result.toNat
  hget := fun {β} [Codec β] k field => liftRedisEIO RedisCmd.HGET (fun ctx => FFI.Internal.hget ctx (Codec.enc k) (Codec.enc field))
  hgetAs := fun β γ [Codec β] [Codec γ] k field => do
    let tmp ← liftRedisEIO RedisCmd.HGET (fun ctx => FFI.Internal.hget ctx (Codec.enc k) (Codec.enc field))
    match Codec.dec tmp with
    | .ok value => return value
    | .error msg => throw (Error.otherError s!"Codec decoding failed: {msg}")
  hgetall := fun k => liftRedisEIO RedisCmd.HGETALL (fun ctx => FFI.Internal.hgetall ctx (Codec.enc k))
  hdel := fun {β} [Codec β] k field => do
    let result ← liftRedisEIO RedisCmd.HDEL (fun ctx => FFI.Internal.hdel ctx (Codec.enc k) (Codec.enc field))
    return result.toNat
  hexists := fun {β} [Codec β] k field => liftRedisEIO RedisCmd.HEXISTS (fun ctx => FFI.Internal.hexists ctx (Codec.enc k) (Codec.enc field))
  hincrby := fun {β} [Codec β] k field increment => do
    let result ← liftRedisEIO RedisCmd.HINCRBY (fun ctx => FFI.Internal.hincrby ctx (Codec.enc k) (Codec.enc field) (Int64.ofInt increment))
    return result.toNat
  hkeys := fun k => liftRedisEIO RedisCmd.HKEYS (fun ctx => FFI.Internal.hkeys ctx (Codec.enc k))
  hlen := fun k => do
    let result ← liftRedisEIO RedisCmd.HLEN (fun ctx => FFI.Internal.hlen ctx (Codec.enc k))
    return result.toNat
  hvals := fun k => liftRedisEIO RedisCmd.HVALS (fun ctx => FFI.Internal.hvals ctx (Codec.enc k))
  hsetnx := fun {β γ} [Codec β] [Codec γ] k field value => liftRedisEIO RedisCmd.HSETNX (fun ctx => FFI.Internal.hsetnx ctx (Codec.enc k) (Codec.enc field) (Codec.enc value))
  hmget := fun {β} [Codec β] k fields => liftRedisEIO RedisCmd.HMGET (fun ctx => FFI.Internal.hmget ctx (Codec.enc k) (fields.map Codec.enc))
  hincrbyfloat := fun {β} [Codec β] k field increment => liftRedisEIO RedisCmd.HINCRBYFLOAT (fun ctx => FFI.hincrByFloat ctx (Codec.enc k) (Codec.enc field) increment)
  hscan := fun {β} [Codec β] k cursor pattern count => do
    let count_u64 := count.map UInt64.ofNat
    let result ← liftRedisEIO RedisCmd.HSCAN (fun ctx => FFI.Internal.hscan ctx (Codec.enc k) (UInt64.ofNat cursor) pattern count_u64)
    return (result.1.toNat, result.2)

  -- Sorted set operations
  zadd := fun {β} [Codec β] k score member => do
    let result ← liftRedisEIO RedisCmd.ZADD (fun ctx => FFI.Internal.zadd ctx (Codec.enc k) score (Codec.enc member))
    return result.toNat
  zcard := fun k => do
    let result ← liftRedisEIO RedisCmd.ZCARD (fun ctx => FFI.Internal.zcard ctx (Codec.enc k))
    return result.toNat
  zrange := fun k start stop => liftRedisEIO RedisCmd.ZRANGE (fun ctx => FFI.Internal.zrange ctx (Codec.enc k) (Int64.ofInt start) (Int64.ofInt stop))
  zscore := fun {β} [Codec β] k member => liftRedisEIO RedisCmd.ZSCORE (fun ctx => FFI.Internal.zscore ctx (Codec.enc k) (Codec.enc member))
  zrank := fun {β} [Codec β] k member => do
    let result ← liftRedisEIO RedisCmd.ZRANK (fun ctx => FFI.Internal.zrank ctx (Codec.enc k) (Codec.enc member))
    return result.map UInt64.toNat
  zrevrank := fun {β} [Codec β] k member => do
    let result ← liftRedisEIO RedisCmd.ZREVRANK (fun ctx => FFI.Internal.zrevrank ctx (Codec.enc k) (Codec.enc member))
    return result.map UInt64.toNat
  zcount := fun k min max => do
    let result ← liftRedisEIO RedisCmd.ZCOUNT (fun ctx => FFI.Internal.zcount ctx (Codec.enc k) (String.toUTF8 min) (String.toUTF8 max))
    return result.toNat
  zincrby := fun {β} [Codec β] k increment member => liftRedisEIO RedisCmd.ZINCRBY (fun ctx => FFI.Internal.zincrby ctx (Codec.enc k) increment (Codec.enc member))
  zrem := fun {β} [Codec β] k members => do
    let result ← liftRedisEIO RedisCmd.ZREM (fun ctx => FFI.Internal.zrem ctx (Codec.enc k) (members.map Codec.enc))
    return result.toNat
  zrangebyscore := fun k min max => liftRedisEIO RedisCmd.ZRANGEBYSCORE (fun ctx => FFI.zrangebyscore ctx (Codec.enc k) (String.toUTF8 min) (String.toUTF8 max))
  zrevrange := fun k start stop => liftRedisEIO RedisCmd.ZREVRANGE (fun ctx => FFI.zrevrange ctx (Codec.enc k) (Int64.ofInt start) (Int64.ofInt stop))
  zrevrangebyscore := fun k max min => liftRedisEIO RedisCmd.ZREVRANGEBYSCORE (fun ctx => FFI.zrevrangebyscore ctx (Codec.enc k) (String.toUTF8 max) (String.toUTF8 min))
  zremrangebyrank := fun k start stop => do
    let result ← liftRedisEIO RedisCmd.ZREMRANGEBYRANK (fun ctx => FFI.Internal.zremrangebyrank ctx (Codec.enc k) (Int64.ofInt start) (Int64.ofInt stop))
    return result.toNat
  zremrangebyscore := fun k min max => do
    let result ← liftRedisEIO RedisCmd.ZREMRANGEBYSCORE (fun ctx => FFI.Internal.zremrangebyscore ctx (Codec.enc k) (String.toUTF8 min) (String.toUTF8 max))
    return result.toNat
  zpopmin := fun k count => liftRedisEIO RedisCmd.ZPOPMIN (fun ctx => FFI.Internal.zpopmin ctx (Codec.enc k) (count.map UInt64.ofNat))
  zpopmax := fun k count => liftRedisEIO RedisCmd.ZPOPMAX (fun ctx => FFI.Internal.zpopmax ctx (Codec.enc k) (count.map UInt64.ofNat))
  zscan := fun k cursor pattern count => do
    let count_u64 := count.map UInt64.ofNat
    let result ← liftRedisEIO RedisCmd.ZSCAN (fun ctx => FFI.Internal.zscan ctx (Codec.enc k) (UInt64.ofNat cursor) pattern count_u64)
    return (result.1.toNat, result.2)

  -- HyperLogLog operations
  pfadd := fun k elements => liftRedisEIO RedisCmd.PFADD (fun ctx => FFI.Internal.pfadd ctx (Codec.enc k) (elements.map Codec.enc))
  pfcount := fun keys => do
    let result ← liftRedisEIO RedisCmd.PFCOUNT (fun ctx => FFI.Internal.pfcount ctx (keys.map Codec.enc))
    return result.toNat
  pfmerge := fun destkey sourcekeys => liftRedisEIO RedisCmd.PFMERGE (fun ctx => FFI.Internal.pfmerge ctx (Codec.enc destkey) (sourcekeys.map Codec.enc))

  -- Bitmap operations
  setbit := fun k offset value => liftRedisEIO RedisCmd.SETBIT (fun ctx => FFI.setbit' ctx (Codec.enc k) (UInt64.ofNat offset) value)
  getbit := fun k offset => liftRedisEIO RedisCmd.GETBIT (fun ctx => FFI.getbit' ctx (Codec.enc k) (UInt64.ofNat offset))
  bitcount := fun k start end_ => do
    let start_i64 := start.map Int64.ofInt
    let end_i64 := end_.map Int64.ofInt
    let result ← liftRedisEIO RedisCmd.BITCOUNT (fun ctx => FFI.Internal.bitcount ctx (Codec.enc k) start_i64 end_i64)
    return result.toNat

  -- Pub/Sub operations
  publish := fun {β} [Codec β] channel message => do
    let result ← liftRedisEIO RedisCmd.PUBLISH (fun ctx => FFI.Internal.publish ctx channel (Codec.enc message))
    return result.toNat
  subscribe := fun channel => liftRedisEIO RedisCmd.SUBSCRIBE (fun ctx => FFI.Internal.subscribe ctx channel)

  -- Authentication and protocol operations
  auth := fun password => liftRedisEIO RedisCmd.AUTH (fun ctx => FFI.Internal.auth ctx password)
  hello := fun protocol_version => liftRedisEIO RedisCmd.HELLO (fun ctx => FFI.Internal.hello ctx (UInt64.ofNat protocol_version))

  -- TTL operations
  ttl := fun k => do
    let result ← liftRedisEIO RedisCmd.TTL (fun ctx => FFI.Internal.ttl ctx (Codec.enc k))
    return result.toNat
  pttl := fun k => do
    let result ← liftRedisEIO RedisCmd.PTTL (fun ctx => FFI.Internal.pttl ctx (Codec.enc k))
    return result.toNat

  -- Redis Streams operations
  xadd := fun {β} [Codec β] k stream_id field_values => do
    let encoded_fv := field_values.map (fun (f, v) => (Codec.enc f, Codec.enc v))
    let result ← liftRedisEIO RedisCmd.XADD (fun ctx => FFI.Internal.xadd ctx (Codec.enc k) (String.toUTF8 stream_id) encoded_fv)
    match String.fromUTF8? result with
    | some str => return str
    | none => throw (Error.otherError "Invalid UTF-8 in XADD response")
  xread := fun streams count_opt block_opt => do
    let encoded_streams := streams.map (fun (stream, id) => (Codec.enc stream, String.toUTF8 id))
    let count_u64 := count_opt.map (fun n => UInt64.ofNat n)
    let block_u64 := block_opt.map (fun n => UInt64.ofNat n)
    liftRedisEIO RedisCmd.XREAD (fun ctx => FFI.Internal.xread ctx encoded_streams count_u64 block_u64)
  xrange := fun k start_id end_id count_opt => do
    let count_u64 := count_opt.map (fun n => UInt64.ofNat n)
    liftRedisEIO RedisCmd.XRANGE (fun ctx => FFI.Internal.xrange ctx (Codec.enc k) (String.toUTF8 start_id) (String.toUTF8 end_id) count_u64)
  xlen := fun k => do
    let result ← liftRedisEIO RedisCmd.XLEN (fun ctx => FFI.Internal.xlen ctx (Codec.enc k))
    return result.toNat
  xdel := fun k entry_ids => do
    let encoded_ids := entry_ids.map String.toUTF8
    let result ← liftRedisEIO RedisCmd.XDEL (fun ctx => FFI.Internal.xdel ctx (Codec.enc k) encoded_ids)
    return result.toNat
  xtrim := fun k strategy max_len => do
    let result ← liftRedisEIO RedisCmd.XTRIM (fun ctx => FFI.Internal.xtrim ctx (Codec.enc k) (String.toUTF8 strategy) (UInt64.ofNat max_len))
    return result.toNat

  -- Connection operations
  ping := fun msg => liftRedisEIO RedisCmd.PING (fun ctx => FFI.Internal.ping ctx (Codec.enc msg))
  selectDb := fun db => liftRedisEIO RedisCmd.SELECT (fun ctx => FFI.Internal.selectDb ctx (UInt64.ofNat db))
  echoMsg := fun msg => liftRedisEIO RedisCmd.ECHO (fun ctx => FFI.Internal.echo ctx msg)

  -- Server operations
  dbsize := do
    let result ← liftRedisEIO RedisCmd.DBSIZE (fun ctx => FFI.Internal.dbsize ctx)
    return result.toNat
  flushall := fun mode => liftRedisEIO RedisCmd.FLUSHALL (fun ctx => FFI.Internal.flushall ctx mode)

-- Redis command operations

variable {α β : Type} [Codec α] [Codec β] [Ops α m]

-- String operations
def set (k : α) (v : β) : m Unit := Ops.set k v
def setnx (k : α) (v : β) : m Unit := Ops.setnx k v
def setxx (k : α) (v : β) : m Unit := Ops.setxx k v
def setex (k : α) (v : β) (msec : Nat) : m Unit := Ops.setex k v msec
def setexnx (k : α) (v : β) (msec : Nat) : m Unit := Ops.setexnx k v msec
def setexxx (k : α) (v : β) (msec : Nat) : m Unit := Ops.setexxx k v msec
def get (k : α) : m ByteArray := Ops.get k
def getAs (β : Type) [Codec β] (k : α) : m β := Ops.getAs β k
def append (k : α) (v : β) : m Nat := Ops.append k v
def getdel (k : α) : m ByteArray := Ops.getdel k
def getrange (k : α) (start end_ : Int) : m ByteArray := Ops.getrange k start end_
def strlen (k : α) : m Nat := Ops.strlen k
def incrByFloat (k : α) (increment : Float) : m Float := Ops.incrByFloat k increment

-- Key operations
def del (ks : List α) : m Nat := Ops.del ks
def existsKey (k : α) : m Bool := Ops.existsKey k
def typeKey (k : α) : m RedisValue := Ops.typeKey k
def keys [inst : Ops α m] (pattern : ByteArray) : m (List ByteArray) := inst.keys pattern
def scan [inst : Ops α m] (cursor : Nat) (pattern : Option ByteArray := none) (count : Option Nat := none) : m (Nat × List ByteArray) := inst.scan cursor pattern count
def expire (k : α) (seconds : Nat) : m Bool := Ops.expire k seconds
def expireAt (k : α) (timestamp : Nat) : m Bool := Ops.expireAt k timestamp
def pexpire (k : α) (milliseconds : Nat) : m Bool := Ops.pexpire k milliseconds
def pexpireAt (k : α) (timestamp : Nat) : m Bool := Ops.pexpireAt k timestamp
def persist (k : α) : m Bool := Ops.persist k
def rename (k : α) (newkey : α) : m Unit := Ops.rename k newkey
def renamenx (k : α) (newkey : α) : m Bool := Ops.renamenx k newkey
def copy (src : α) (dst : α) (replace : Bool := false) : m Bool := Ops.copy src dst replace
def unlink (ks : List α) : m Nat := Ops.unlink ks
def touch (ks : List α) : m Nat := Ops.touch ks

-- Numeric string operations
def incr (k : α) : m Int := Ops.incr k
def incrBy (k : α) (n : Int) : m Int := Ops.incrBy k n
def decr (k : α) : m Int := Ops.decr k
def decrBy (k : α) (n : Int) : m Int := Ops.decrBy k n

-- Set operations
def sismember (k : α) (member : α) : m Bool := Ops.sismember k member
def scard (k : α) : m Nat := Ops.scard k
def sadd (k : α) (member : α) : m Nat := Ops.sadd k member
def smembers (k : α) : m (List ByteArray) := Ops.smembers k
def srem (k : α) (members : List α) : m Nat := Ops.srem k members
def spop (k : α) (count : Option Nat := none) : m (List ByteArray) := Ops.spop k count
def srandmember (k : α) (count : Option Nat := none) : m (List ByteArray) := Ops.srandmember k count
def smove (src : α) (dst : α) (member : α) : m Bool := Ops.smove src dst member
def sdiff (ks : List α) : m (List ByteArray) := Ops.sdiff ks
def sdiffstore (dst : α) (ks : List α) : m Nat := Ops.sdiffstore dst ks
def sinter (ks : List α) : m (List ByteArray) := Ops.sinter ks
def sinterstore (dst : α) (ks : List α) : m Nat := Ops.sinterstore dst ks
def sunion (ks : List α) : m (List ByteArray) := Ops.sunion ks
def sunionstore (dst : α) (ks : List α) : m Nat := Ops.sunionstore dst ks
def sscan (k : α) (cursor : Nat) (pattern : Option ByteArray := none) (count : Option Nat := none) : m (Nat × List ByteArray) := Ops.sscan k cursor pattern count

-- List operations
def lpush (k : α) (values : List α) : m Nat := Ops.lpush k values
def rpush (k : α) (values : List α) : m Nat := Ops.rpush k values
def lpushx (k : α) (values : List α) : m Nat := Ops.lpushx k values
def rpushx (k : α) (values : List α) : m Nat := Ops.rpushx k values
def lpop (k : α) (count : Option Nat := none) : m (List ByteArray) := Ops.lpop k count
def rpop (k : α) (count : Option Nat := none) : m (List ByteArray) := Ops.rpop k count
def lrange (k : α) (start stop : Int) : m (List ByteArray) := Ops.lrange k start stop
def lindex (k : α) (index : Int) : m ByteArray := Ops.lindex k index
def llen (k : α) : m Nat := Ops.llen k
def lset (k : α) (index : Int) (value : α) : m Unit := Ops.lset k index value
def linsertBefore {γ : Type} [Codec γ] (k : α) (pivot : α) (value : γ) : m Int := Ops.linsertBefore k pivot value
def linsertAfter {γ : Type} [Codec γ] (k : α) (pivot : α) (value : γ) : m Int := Ops.linsertAfter k pivot value
def ltrim (k : α) (start stop : Int) : m Unit := Ops.ltrim k start stop
def lrem (k : α) (count : Int) (element : α) : m Nat := Ops.lrem k count element

-- Hash operations
def hset {γ : Type} [Codec γ] (k : α) (field : α) (value : γ) : m Nat := Ops.hset k field value
def hget (k : α) (field : α) : m ByteArray := Ops.hget k field
def hgetAs (γ : Type) [Codec γ] (k : α) (field : α) : m γ := Ops.hgetAs α γ k field
def hgetall (k : α) : m (List ByteArray) := Ops.hgetall k
def hdel (k : α) (field : α) : m Nat := Ops.hdel k field
def hexists (k : α) (field : α) : m Bool := Ops.hexists k field
def hincrby (k : α) (field : α) (increment : Int) : m Nat := Ops.hincrby k field increment
def hkeys (k : α) : m (List ByteArray) := Ops.hkeys k
def hlen (k : α) : m Nat := Ops.hlen k
def hvals (k : α) : m (List ByteArray) := Ops.hvals k
def hsetnx {γ : Type} [Codec γ] (k : α) (field : α) (value : γ) : m Bool := Ops.hsetnx k field value
def hmget (k : α) (fields : List α) : m (List (Option ByteArray)) := Ops.hmget k fields
def hincrbyfloat (k : α) (field : α) (increment : Float) : m Float := Ops.hincrbyfloat k field increment
def hscan (k : α) (cursor : Nat) (pattern : Option ByteArray := none) (count : Option Nat := none) : m (Nat × List ByteArray) := @Ops.hscan α _ m _ α _ k cursor pattern count

-- Sorted set operations
def zadd (k : α) (score : Float) (member : α) : m Nat := Ops.zadd k score member
def zcard (k : α) : m Nat := Ops.zcard k
def zrange (k : α) (start stop : Int) : m (List ByteArray) := Ops.zrange k start stop
def zscore (k : α) (member : α) : m (Option Float) := Ops.zscore k member
def zrank (k : α) (member : α) : m (Option Nat) := Ops.zrank k member
def zrevrank (k : α) (member : α) : m (Option Nat) := Ops.zrevrank k member
def zcount (k : α) (min max : String) : m Nat := Ops.zcount k min max
def zincrby (k : α) (increment : Float) (member : α) : m Float := Ops.zincrby k increment member
def zrem (k : α) (members : List α) : m Nat := Ops.zrem k members
def zrangebyscore (k : α) (min max : String) : m (List ByteArray) := Ops.zrangebyscore k min max
def zrevrange (k : α) (start stop : Int) : m (List ByteArray) := Ops.zrevrange k start stop
def zrevrangebyscore (k : α) (max min : String) : m (List ByteArray) := Ops.zrevrangebyscore k max min
def zremrangebyrank (k : α) (start stop : Int) : m Nat := Ops.zremrangebyrank k start stop
def zremrangebyscore (k : α) (min max : String) : m Nat := Ops.zremrangebyscore k min max
def zpopmin (k : α) (count : Option Nat := none) : m (List ByteArray) := Ops.zpopmin k count
def zpopmax (k : α) (count : Option Nat := none) : m (List ByteArray) := Ops.zpopmax k count
def zscan (k : α) (cursor : Nat) (pattern : Option ByteArray := none) (count : Option Nat := none) : m (Nat × List ByteArray) := Ops.zscan k cursor pattern count

-- HyperLogLog operations
def pfadd (k : α) (elements : List α) : m Bool := Ops.pfadd k elements
def pfcount (ks : List α) : m Nat := Ops.pfcount ks
def pfmerge (destkey : α) (sourcekeys : List α) : m Unit := Ops.pfmerge destkey sourcekeys

-- Bitmap operations
def setbit (k : α) (offset : Nat) (value : Bool) : m Bool := Ops.setbit k offset value
def getbit (k : α) (offset : Nat) : m Bool := Ops.getbit k offset
def bitcount (k : α) (start : Option Int := none) (end_ : Option Int := none) : m Nat := Ops.bitcount k start end_

-- Pub/Sub operations
def publish [inst : Ops α m] [Codec β] (channel : String) (message : β) : m Nat :=
  inst.publish channel message
def subscribe [inst : Ops α m] (channel : String) : m Bool :=
  inst.subscribe channel

-- Authentication and protocol operations
def auth [inst : Ops α m] (password : String) : m Bool :=
  inst.auth password
def hello [inst : Ops α m] (protocol_version : Nat := 3) : m ByteArray :=
  inst.hello protocol_version

-- TTL operations
def ttl (k : α) : m Nat := Ops.ttl k
def pttl (k : α) : m Nat := Ops.pttl k

-- Redis Streams operations
def xadd [Codec β] (k : α) (stream_id : String) (field_values : List (α × β)) : m String :=
  Ops.xadd k stream_id field_values
def xread (streams : List (α × String)) (count_opt : Option Nat := none) (block_opt : Option Nat := none) : m ByteArray :=
  Ops.xread streams count_opt block_opt
def xrange (k : α) (start_id end_id : String) (count_opt : Option Nat := none) : m ByteArray :=
  Ops.xrange k start_id end_id count_opt
def xlen (k : α) : m Nat := Ops.xlen k
def xdel (k : α) (entry_ids : List String) : m Nat := Ops.xdel k entry_ids
def xtrim (k : α) (strategy : String) (max_len : Nat) : m Nat := Ops.xtrim k strategy max_len

-- Connection operations
def ping (msg : α) : m Bool := Ops.ping msg
def selectDb [inst : Ops α m] (db : Nat) : m Unit := inst.selectDb db
def echoMsg [inst : Ops α m] (msg : ByteArray) : m ByteArray := inst.echoMsg msg

-- Server operations
def dbsize [inst : Ops α m] : m Nat := inst.dbsize
def flushall [inst : Ops α m] (mode : String := "SYNC") : m Bool := inst.flushall mode

-- Pipeline operations (for future extension)

/-- Redis pipeline for batching commands -/
structure Pipeline where
  commands : List (RedisM Unit)

/-- Create an empty pipeline -/
def emptyPipeline : Pipeline := ⟨[]⟩

/-- Add a command to a pipeline -/
def Pipeline.add (pipeline : Pipeline) (cmd : RedisM Unit) : Pipeline :=
  ⟨cmd :: pipeline.commands⟩

/-- Execute a pipeline of commands -/
def executePipeline (pipeline : Pipeline) : RedisM Unit := do
  for cmd in pipeline.commands.reverse do
    cmd

-- Utility functions

/-- Multi-get operation -/
def mget [Codec α] [Codec β] (ks : List α) : RedisM (List β) := do
  let results ← ks.mapM (getAs β)
  return results

/-- Multi-set operation -/
def mset [Codec α] [Codec β] (pairs : List (α × β)) : RedisM Unit := do
  pairs.forM (fun (k, v) => set k v)

-- DSL-style combinators

-- Operator for chaining Redis operations
infixl:55 " >>= " => bind

/-- Operator for sequencing Redis operations -/
infixl:50 " >> " => fun m n => m >>= fun _ => n

/-- When combinator for conditional execution -/
def whenM (condition : RedisM Bool) (action : RedisM Unit) : RedisM Unit := do
  let cond ← condition
  if cond then action else return ()

/-- Unless combinator for conditional execution -/
def unlessM (condition : RedisM Bool) (action : RedisM Unit) : RedisM Unit := do
  let cond ← condition
  if not cond then action else return ()

end Redis
