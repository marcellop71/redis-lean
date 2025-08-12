-- FFI layer wrapping the hiredis C library
import RedisLean.Error
import RedisLean.Config

namespace Redis

namespace FFI

/-- Redis context type -/
abbrev Ctx := UInt64

/-- SET command existence options -/
inductive SetExistsOption where
  | none : SetExistsOption  -- No additional option (standard SET)
  | nx   : SetExistsOption  -- Set only if key doesn't exist
  | xx   : SetExistsOption  -- Set only if key exists
deriving Repr, BEq

/-- Convert SetExistsOption to UInt8 for FFI declarations -/
def SetExistsOption.toUInt8 : SetExistsOption → UInt8
  | .none => 0
  | .nx   => 1
  | .xx   => 2

/-!
## Internal FFI Declarations

**WARNING**: The `Internal` namespace contains raw FFI bindings to Internal.
These are unsafe and should NOT be used directly. Instead, use the public
API functions defined below (e.g., `withRedis`, `connect`, `get`, `set`).

The internal functions:
- Do not prevent use-after-free (though C-side validation helps catch it)
- Require manual resource management
- May change without notice

The public API provides:
- Automatic resource cleanup via `withRedis`/`withRedisSSL`
- Proper error handling via `EIO Error`
- Stable interface
-/
namespace Internal

@[extern "l_hiredis_connect"]
opaque connect (host : @& String) (port : @& UInt32) : EIO Error Ctx

@[extern "l_hiredis_connect_ssl"]
opaque connectSSL
  (host : @& String)
  (port : @& UInt32)
  (cacertPath : @& Option String)
  (caPath : @& Option String)
  (certPath : @& Option String)
  (keyPath : @& Option String)
  (serverName : @& Option String)
  (verifyMode : @& UInt8)
  : EIO Error Ctx

@[extern "l_hiredis_free"]
opaque free (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_ping"]
opaque ping (ctx : @& Ctx) (msg : @& ByteArray) : EIO Error Bool

@[extern "l_hiredis_auth"]
opaque auth (ctx : @& Ctx) (password : @& String) : EIO Error Bool

@[extern "l_hiredis_hello"]
opaque hello (ctx : @& Ctx) (protocol_version : @& UInt64) : EIO Error ByteArray

@[extern "l_hiredis_set"]
opaque set (ctx : @& Ctx) (k : @& ByteArray) (v : @& ByteArray) (existsOption : @& UInt8) : EIO Error Unit

@[extern "l_hiredis_setex"]
opaque setex (ctx : @& Ctx) (k : @& ByteArray) (v : @& ByteArray) (msec : @& UInt64) (existsOption : @& UInt8) : EIO Error Unit

@[extern "l_hiredis_get"]
opaque get (ctx : @& Ctx) (k : @& ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_del"]
opaque del (ctx : @& Ctx) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_exists"]
opaque existsKey (ctx : @& Ctx) (key : @& ByteArray) : EIO Error Bool

@[extern "l_hiredis_type"]
opaque typeKey (ctx : @& Ctx) (key : @& ByteArray) : EIO Error String

@[extern "l_hiredis_incr"]
opaque incr (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_incrby"]
opaque incrby (ctx : @& Ctx) (key : @& ByteArray) (increment : @& Int64) : EIO Error UInt64

@[extern "l_hiredis_decr"]
opaque decr (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_decrby"]
opaque decrby (ctx : @& Ctx) (key : @& ByteArray) (decrement : @& Int64) : EIO Error UInt64

@[extern "l_hiredis_sismember"]
opaque sismember (ctx : @& Ctx) (key : @& ByteArray) (member : @& ByteArray) : EIO Error Bool

@[extern "l_hiredis_scard"]
opaque scard (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_sadd"]
opaque sadd (ctx : @& Ctx) (key : @& ByteArray) (member : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_smembers"]
opaque smembers (ctx : @& Ctx) (key : @& ByteArray) : EIO Error (List ByteArray)

@[extern "l_hiredis_flushall"]
opaque flushall (ctx : @& Ctx) (mode : @& String) : EIO Error Bool

@[extern "l_hiredis_publish"]
opaque publish (ctx : @& Ctx) (channel : @& String) (message : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_subscribe"]
opaque subscribe (ctx : @& Ctx) (channel : @& String) : EIO Error Bool

@[extern "l_hiredis_command"]
opaque command (ctx : @& Ctx) (command_str : @& String) : EIO Error ByteArray

@[extern "l_hiredis_ttl"]
opaque ttl (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_pttl"]
opaque pttl (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_keys"]
opaque keys (ctx : @& Ctx) (pattern : @& ByteArray) : EIO Error (List ByteArray)

@[extern "l_hiredis_hset"]
opaque hset (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) (value : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_hget"]
opaque hget (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_hgetall"]
opaque hgetall (ctx : @& Ctx) (key : @& ByteArray) : EIO Error (List ByteArray)

@[extern "l_hiredis_hdel"]
opaque hdel (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_hexists"]
opaque hexists (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) : EIO Error Bool

@[extern "l_hiredis_hincrby"]
opaque hincrby (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) (increment : @& Int64) : EIO Error UInt64

@[extern "l_hiredis_hkeys"]
opaque hkeys (ctx : @& Ctx) (key : @& ByteArray) : EIO Error (List ByteArray)

@[extern "l_hiredis_zadd"]
opaque zadd (ctx : @& Ctx) (key : @& ByteArray) (score : @& Float) (member : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zcard"]
opaque zcard (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zrange"]
opaque zrange (ctx : @& Ctx) (key : @& ByteArray) (start : @& Int64) (stop : @& Int64) : EIO Error (List ByteArray)

@[extern "l_hiredis_zscore"]
opaque zscore (ctx : @& Ctx) (key : @& ByteArray) (member : @& ByteArray) : EIO Error (Option Float)

@[extern "l_hiredis_zrank"]
opaque zrank (ctx : @& Ctx) (key : @& ByteArray) (member : @& ByteArray) : EIO Error (Option UInt64)

@[extern "l_hiredis_zrevrank"]
opaque zrevrank (ctx : @& Ctx) (key : @& ByteArray) (member : @& ByteArray) : EIO Error (Option UInt64)

@[extern "l_hiredis_zcount"]
opaque zcount (ctx : @& Ctx) (key : @& ByteArray) (min : @& ByteArray) (max : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zincrby"]
opaque zincrby (ctx : @& Ctx) (key : @& ByteArray) (increment : @& Float) (member : @& ByteArray) : EIO Error Float

@[extern "l_hiredis_zrem"]
opaque zrem (ctx : @& Ctx) (key : @& ByteArray) (members : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zlexcount"]
opaque zlexcount (ctx : @& Ctx) (key : @& ByteArray) (min : @& ByteArray) (max : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zmscore"]
opaque zmscore (ctx : @& Ctx) (key : @& ByteArray) (members : @& List ByteArray) : EIO Error (List (Option Float))

@[extern "l_hiredis_zrandmember"]
opaque zrandmember (ctx : @& Ctx) (key : @& ByteArray) (count : @& Option Int64) (withscores : @& UInt8) : EIO Error (List ByteArray)

@[extern "l_hiredis_zscan"]
opaque zscan (ctx : @& Ctx) (key : @& ByteArray) (cursor : @& UInt64) (pattern : @& Option ByteArray) (count : @& Option UInt64) : EIO Error (UInt64 × List ByteArray)

@[extern "l_hiredis_zrangebyscore"]
opaque zrangebyscore (ctx : @& Ctx) (key : @& ByteArray) (min : @& ByteArray) (max : @& ByteArray) (withscores : @& UInt8) (offset : @& Option UInt64) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_zrevrange"]
opaque zrevrange (ctx : @& Ctx) (key : @& ByteArray) (start : @& Int64) (stop : @& Int64) (withscores : @& UInt8) : EIO Error (List ByteArray)

@[extern "l_hiredis_zrevrangebyscore"]
opaque zrevrangebyscore (ctx : @& Ctx) (key : @& ByteArray) (max : @& ByteArray) (min : @& ByteArray) (withscores : @& UInt8) (offset : @& Option UInt64) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_zrangebylex"]
opaque zrangebylex (ctx : @& Ctx) (key : @& ByteArray) (min : @& ByteArray) (max : @& ByteArray) (offset : @& Option UInt64) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_zrevrangebylex"]
opaque zrevrangebylex (ctx : @& Ctx) (key : @& ByteArray) (max : @& ByteArray) (min : @& ByteArray) (offset : @& Option UInt64) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_zremrangebyrank"]
opaque zremrangebyrank (ctx : @& Ctx) (key : @& ByteArray) (start : @& Int64) (stop : @& Int64) : EIO Error UInt64

@[extern "l_hiredis_zremrangebyscore"]
opaque zremrangebyscore (ctx : @& Ctx) (key : @& ByteArray) (min : @& ByteArray) (max : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zremrangebylex"]
opaque zremrangebylex (ctx : @& Ctx) (key : @& ByteArray) (min : @& ByteArray) (max : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zpopmin"]
opaque zpopmin (ctx : @& Ctx) (key : @& ByteArray) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_zpopmax"]
opaque zpopmax (ctx : @& Ctx) (key : @& ByteArray) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_bzpopmin"]
opaque bzpopmin (ctx : @& Ctx) (keys : @& List ByteArray) (timeout : @& Float) : EIO Error (Option (ByteArray × ByteArray × ByteArray))

@[extern "l_hiredis_bzpopmax"]
opaque bzpopmax (ctx : @& Ctx) (keys : @& List ByteArray) (timeout : @& Float) : EIO Error (Option (ByteArray × ByteArray × ByteArray))

@[extern "l_hiredis_zunionstore"]
opaque zunionstore (ctx : @& Ctx) (dest : @& ByteArray) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zinterstore"]
opaque zinterstore (ctx : @& Ctx) (dest : @& ByteArray) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zdiffstore"]
opaque zdiffstore (ctx : @& Ctx) (dest : @& ByteArray) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_zunion"]
opaque zunion (ctx : @& Ctx) (keys : @& List ByteArray) (withscores : @& UInt8) : EIO Error (List ByteArray)

@[extern "l_hiredis_zinter"]
opaque zinter (ctx : @& Ctx) (keys : @& List ByteArray) (withscores : @& UInt8) : EIO Error (List ByteArray)

@[extern "l_hiredis_zdiff"]
opaque zdiff (ctx : @& Ctx) (keys : @& List ByteArray) (withscores : @& UInt8) : EIO Error (List ByteArray)

@[extern "l_hiredis_zintercard"]
opaque zintercard (ctx : @& Ctx) (keys : @& List ByteArray) (limit : @& Option UInt64) : EIO Error UInt64

@[extern "l_hiredis_zrangestore"]
opaque zrangestore (ctx : @& Ctx) (dst : @& ByteArray) (src : @& ByteArray) (min : @& ByteArray) (max : @& ByteArray) (rangeType : @& ByteArray) (rev : @& UInt8) : EIO Error UInt64

-- HyperLogLog commands
@[extern "l_hiredis_pfadd"]
opaque pfadd (ctx : @& Ctx) (key : @& ByteArray) (elements : @& List ByteArray) : EIO Error Bool

@[extern "l_hiredis_pfcount"]
opaque pfcount (ctx : @& Ctx) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_pfmerge"]
opaque pfmerge (ctx : @& Ctx) (dest : @& ByteArray) (sources : @& List ByteArray) : EIO Error Unit

-- Geospatial commands
@[extern "l_hiredis_geoadd"]
opaque geoadd (ctx : @& Ctx) (key : @& ByteArray) (items : @& List (Float × Float × ByteArray)) : EIO Error UInt64

@[extern "l_hiredis_geodist"]
opaque geodist (ctx : @& Ctx) (key : @& ByteArray) (member1 : @& ByteArray) (member2 : @& ByteArray) (unit : @& Option ByteArray) : EIO Error (Option Float)

@[extern "l_hiredis_geohash"]
opaque geohash (ctx : @& Ctx) (key : @& ByteArray) (members : @& List ByteArray) : EIO Error (List (Option ByteArray))

@[extern "l_hiredis_geopos"]
opaque geopos (ctx : @& Ctx) (key : @& ByteArray) (members : @& List ByteArray) : EIO Error (List (Option (Float × Float)))

@[extern "l_hiredis_geosearch"]
opaque geosearch (ctx : @& Ctx) (key : @& ByteArray) (fromType : @& ByteArray) (fromValue : @& ByteArray) (byType : @& ByteArray) (radius : @& Float) (unit : @& ByteArray) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_geosearchstore"]
opaque geosearchstore (ctx : @& Ctx) (dest : @& ByteArray) (src : @& ByteArray) (fromType : @& ByteArray) (fromValue : @& ByteArray) (byType : @& ByteArray) (radius : @& Float) (unit : @& ByteArray) (count : @& Option UInt64) (storedist : @& UInt8) : EIO Error UInt64

-- Bitmap commands
@[extern "l_hiredis_setbit"]
opaque setbit (ctx : @& Ctx) (key : @& ByteArray) (offset : @& UInt64) (value : @& UInt8) : EIO Error UInt8

@[extern "l_hiredis_getbit"]
opaque getbit (ctx : @& Ctx) (key : @& ByteArray) (offset : @& UInt64) : EIO Error UInt8

@[extern "l_hiredis_bitcount"]
opaque bitcount (ctx : @& Ctx) (key : @& ByteArray) (start : @& Option Int64) (stop : @& Option Int64) : EIO Error UInt64

@[extern "l_hiredis_bitop"]
opaque bitop (ctx : @& Ctx) (operation : @& ByteArray) (destkey : @& ByteArray) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_bitpos"]
opaque bitpos (ctx : @& Ctx) (key : @& ByteArray) (bit : @& UInt8) (start : @& Option Int64) (stop : @& Option Int64) : EIO Error Int64

-- Transaction commands
@[extern "l_hiredis_multi"]
opaque multi (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_exec"]
opaque exec (ctx : @& Ctx) : EIO Error (Option (List ByteArray))

@[extern "l_hiredis_discard"]
opaque discard (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_watch"]
opaque watch (ctx : @& Ctx) (keys : @& List ByteArray) : EIO Error Unit

@[extern "l_hiredis_unwatch"]
opaque unwatch (ctx : @& Ctx) : EIO Error Unit

-- Scripting commands
@[extern "l_hiredis_eval"]
opaque eval (ctx : @& Ctx) (script : @& ByteArray) (keys : @& List ByteArray) (args : @& List ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_evalsha"]
opaque evalsha (ctx : @& Ctx) (sha1 : @& ByteArray) (keys : @& List ByteArray) (args : @& List ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_scriptload"]
opaque scriptload (ctx : @& Ctx) (script : @& ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_scriptexists"]
opaque scriptexists (ctx : @& Ctx) (sha1s : @& List ByteArray) : EIO Error (List Bool)

@[extern "l_hiredis_scriptflush"]
opaque scriptflush (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_scriptkill"]
opaque scriptkill (ctx : @& Ctx) : EIO Error Unit

-- Connection commands
@[extern "l_hiredis_clientid"]
opaque clientid (ctx : @& Ctx) : EIO Error UInt64

@[extern "l_hiredis_clientgetname"]
opaque clientgetname (ctx : @& Ctx) : EIO Error (Option ByteArray)

@[extern "l_hiredis_clientsetname"]
opaque clientsetname (ctx : @& Ctx) (name : @& ByteArray) : EIO Error Unit

@[extern "l_hiredis_clientlist"]
opaque clientlist (ctx : @& Ctx) : EIO Error ByteArray

@[extern "l_hiredis_clientinfo"]
opaque clientinfo (ctx : @& Ctx) : EIO Error ByteArray

@[extern "l_hiredis_clientkill"]
opaque clientkill (ctx : @& Ctx) (filterType : @& ByteArray) (filterValue : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_clientpause"]
opaque clientpause (ctx : @& Ctx) (timeout : @& UInt64) : EIO Error Unit

@[extern "l_hiredis_clientunpause"]
opaque clientunpause (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_select"]
opaque selectDb (ctx : @& Ctx) (index : @& UInt64) : EIO Error Unit

@[extern "l_hiredis_echo"]
opaque echo (ctx : @& Ctx) (message : @& ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_quit"]
opaque quit (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_reset"]
opaque reset (ctx : @& Ctx) : EIO Error Unit

-- Server commands
@[extern "l_hiredis_info"]
opaque info (ctx : @& Ctx) (infoSection : @& Option ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_dbsize"]
opaque dbsize (ctx : @& Ctx) : EIO Error UInt64

@[extern "l_hiredis_lastsave"]
opaque lastsave (ctx : @& Ctx) : EIO Error UInt64

@[extern "l_hiredis_bgsave"]
opaque bgsave (ctx : @& Ctx) : EIO Error ByteArray

@[extern "l_hiredis_bgrewriteaof"]
opaque bgrewriteaof (ctx : @& Ctx) : EIO Error ByteArray

@[extern "l_hiredis_time"]
opaque time (ctx : @& Ctx) : EIO Error (UInt64 × UInt64)

@[extern "l_hiredis_configget"]
opaque configget (ctx : @& Ctx) (parameter : @& ByteArray) : EIO Error (List ByteArray)

@[extern "l_hiredis_configset"]
opaque configset (ctx : @& Ctx) (parameter : @& ByteArray) (value : @& ByteArray) : EIO Error Unit

@[extern "l_hiredis_configrewrite"]
opaque configrewrite (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_configresetstat"]
opaque configresetstat (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_memoryusage"]
opaque memoryusage (ctx : @& Ctx) (key : @& ByteArray) : EIO Error (Option UInt64)

@[extern "l_hiredis_objectencoding"]
opaque objectencoding (ctx : @& Ctx) (key : @& ByteArray) : EIO Error (Option ByteArray)

@[extern "l_hiredis_objectidletime"]
opaque objectidletime (ctx : @& Ctx) (key : @& ByteArray) : EIO Error (Option UInt64)

@[extern "l_hiredis_objectfreq"]
opaque objectfreq (ctx : @& Ctx) (key : @& ByteArray) : EIO Error (Option UInt64)

@[extern "l_hiredis_slowlogget"]
opaque slowlogget (ctx : @& Ctx) (count : @& Option UInt64) : EIO Error ByteArray

@[extern "l_hiredis_slowloglen"]
opaque slowloglen (ctx : @& Ctx) : EIO Error UInt64

@[extern "l_hiredis_slowlogreset"]
opaque slowlogreset (ctx : @& Ctx) : EIO Error Unit

-- Redis Streams commands
@[extern "l_hiredis_xadd"]
opaque xadd (ctx : @& Ctx) (key : @& ByteArray) (stream_id : @& ByteArray) (field_values : @& List (ByteArray × ByteArray)) : EIO Error ByteArray

@[extern "l_hiredis_xread"]
opaque xread (ctx : @& Ctx) (streams : @& List (ByteArray × ByteArray)) (count_opt : @& Option UInt64) (block_opt : @& Option UInt64) : EIO Error ByteArray

@[extern "l_hiredis_xrange"]
opaque xrange (ctx : @& Ctx) (key : @& ByteArray) (start_id : @& ByteArray) (end_id : @& ByteArray) (count_opt : @& Option UInt64) : EIO Error ByteArray

@[extern "l_hiredis_xlen"]
opaque xlen (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_xdel"]
opaque xdel (ctx : @& Ctx) (key : @& ByteArray) (entry_ids : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_xtrim"]
opaque xtrim (ctx : @& Ctx) (key : @& ByteArray) (strategy : @& ByteArray) (max_len : @& UInt64) : EIO Error UInt64

-- Consumer group commands
@[extern "l_hiredis_xreadgroup"]
opaque xreadgroup (ctx : @& Ctx) (group : @& String) (consumer : @& String) (stream : @& String) (count : UInt64) : EIO Error ByteArray

@[extern "l_hiredis_xack"]
opaque xack (ctx : @& Ctx) (stream : @& String) (group : @& String) (msgid : @& String) : EIO Error UInt64

@[extern "l_hiredis_xgroup_create"]
opaque xgroup_create (ctx : @& Ctx) (stream : @& String) (group : @& String) (start_id : @& String) : EIO Error Unit

-- List commands
@[extern "l_hiredis_lpush"]
opaque lpush (ctx : @& Ctx) (key : @& ByteArray) (elements : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_rpush"]
opaque rpush (ctx : @& Ctx) (key : @& ByteArray) (elements : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_lpushx"]
opaque lpushx (ctx : @& Ctx) (key : @& ByteArray) (elements : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_rpushx"]
opaque rpushx (ctx : @& Ctx) (key : @& ByteArray) (elements : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_lpop"]
opaque lpop (ctx : @& Ctx) (key : @& ByteArray) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_rpop"]
opaque rpop (ctx : @& Ctx) (key : @& ByteArray) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_lrange"]
opaque lrange (ctx : @& Ctx) (key : @& ByteArray) (start : @& Int64) (stop : @& Int64) : EIO Error (List ByteArray)

@[extern "l_hiredis_lindex"]
opaque lindex (ctx : @& Ctx) (key : @& ByteArray) (index : @& Int64) : EIO Error ByteArray

@[extern "l_hiredis_llen"]
opaque llen (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_lset"]
opaque lset (ctx : @& Ctx) (key : @& ByteArray) (index : @& Int64) (value : @& ByteArray) : EIO Error Unit

@[extern "l_hiredis_linsert"]
opaque linsert (ctx : @& Ctx) (key : @& ByteArray) (position : @& UInt8) (pivot : @& ByteArray) (value : @& ByteArray) : EIO Error Int64

@[extern "l_hiredis_ltrim"]
opaque ltrim (ctx : @& Ctx) (key : @& ByteArray) (start : @& Int64) (stop : @& Int64) : EIO Error Unit

@[extern "l_hiredis_lrem"]
opaque lrem (ctx : @& Ctx) (key : @& ByteArray) (count : @& Int64) (value : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_lpos"]
opaque lpos (ctx : @& Ctx) (key : @& ByteArray) (element : @& ByteArray) (rank : @& Option UInt64) (count : @& Option UInt64) : EIO Error (Option UInt64)

@[extern "l_hiredis_lmove"]
opaque lmove (ctx : @& Ctx) (src : @& ByteArray) (dst : @& ByteArray) (srcDir : @& UInt8) (dstDir : @& UInt8) : EIO Error ByteArray

@[extern "l_hiredis_lmpop"]
opaque lmpop (ctx : @& Ctx) (keys : @& List ByteArray) (direction : @& UInt8) (count : @& Option UInt64) : EIO Error (Option (ByteArray × List ByteArray))

@[extern "l_hiredis_blpop"]
opaque blpop (ctx : @& Ctx) (keys : @& List ByteArray) (timeout : @& Float) : EIO Error (Option (ByteArray × ByteArray))

@[extern "l_hiredis_brpop"]
opaque brpop (ctx : @& Ctx) (keys : @& List ByteArray) (timeout : @& Float) : EIO Error (Option (ByteArray × ByteArray))

@[extern "l_hiredis_blmove"]
opaque blmove (ctx : @& Ctx) (src : @& ByteArray) (dst : @& ByteArray) (srcDir : @& UInt8) (dstDir : @& UInt8) (timeout : @& Float) : EIO Error (Option ByteArray)

@[extern "l_hiredis_blmpop"]
opaque blmpop (ctx : @& Ctx) (timeout : @& Float) (keys : @& List ByteArray) (direction : @& UInt8) (count : @& Option UInt64) : EIO Error (Option (ByteArray × List ByteArray))

@[extern "l_hiredis_rpoplpush"]
opaque rpoplpush (ctx : @& Ctx) (src : @& ByteArray) (dst : @& ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_brpoplpush"]
opaque brpoplpush (ctx : @& Ctx) (src : @& ByteArray) (dst : @& ByteArray) (timeout : @& Float) : EIO Error (Option ByteArray)

-- String commands (additional)
@[extern "l_hiredis_append"]
opaque append (ctx : @& Ctx) (key : @& ByteArray) (value : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_getdel"]
opaque getdel (ctx : @& Ctx) (key : @& ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_getex"]
opaque getex (ctx : @& Ctx) (key : @& ByteArray) (exSeconds : @& Option UInt64) (pxMillis : @& Option UInt64) (persist : @& UInt8) : EIO Error ByteArray

@[extern "l_hiredis_getrange"]
opaque getrange (ctx : @& Ctx) (key : @& ByteArray) (start : @& Int64) (stop : @& Int64) : EIO Error ByteArray

@[extern "l_hiredis_getset"]
opaque getset (ctx : @& Ctx) (key : @& ByteArray) (value : @& ByteArray) : EIO Error ByteArray

@[extern "l_hiredis_incrbyfloat"]
opaque incrbyfloat (ctx : @& Ctx) (key : @& ByteArray) (increment : @& Float) : EIO Error Float

@[extern "l_hiredis_mget"]
opaque mget (ctx : @& Ctx) (keys : @& List ByteArray) : EIO Error (List (Option ByteArray))

@[extern "l_hiredis_mset"]
opaque mset (ctx : @& Ctx) (pairs : @& List (ByteArray × ByteArray)) : EIO Error Unit

@[extern "l_hiredis_msetnx"]
opaque msetnx (ctx : @& Ctx) (pairs : @& List (ByteArray × ByteArray)) : EIO Error Bool

@[extern "l_hiredis_setnx"]
opaque setnx (ctx : @& Ctx) (key : @& ByteArray) (value : @& ByteArray) : EIO Error Bool

@[extern "l_hiredis_setrange"]
opaque setrange (ctx : @& Ctx) (key : @& ByteArray) (offset : @& UInt64) (value : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_strlen"]
opaque strlen (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_psetex"]
opaque psetex (ctx : @& Ctx) (key : @& ByteArray) (millis : @& UInt64) (value : @& ByteArray) : EIO Error Unit

@[extern "l_hiredis_lcs"]
opaque lcs (ctx : @& Ctx) (key1 : @& ByteArray) (key2 : @& ByteArray) (getLen : @& UInt8) (getIdx : @& UInt8) : EIO Error ByteArray

-- Set commands (additional)
@[extern "l_hiredis_srem"]
opaque srem (ctx : @& Ctx) (key : @& ByteArray) (members : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_spop"]
opaque spop (ctx : @& Ctx) (key : @& ByteArray) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_srandmember"]
opaque srandmember (ctx : @& Ctx) (key : @& ByteArray) (count : @& Option UInt64) : EIO Error (List ByteArray)

@[extern "l_hiredis_smove"]
opaque smove (ctx : @& Ctx) (src : @& ByteArray) (dst : @& ByteArray) (member : @& ByteArray) : EIO Error Bool

@[extern "l_hiredis_smismember"]
opaque smismember (ctx : @& Ctx) (key : @& ByteArray) (members : @& List ByteArray) : EIO Error (List Bool)

@[extern "l_hiredis_sdiff"]
opaque sdiff (ctx : @& Ctx) (keys : @& List ByteArray) : EIO Error (List ByteArray)

@[extern "l_hiredis_sdiffstore"]
opaque sdiffstore (ctx : @& Ctx) (dst : @& ByteArray) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_sinter"]
opaque sinter (ctx : @& Ctx) (keys : @& List ByteArray) : EIO Error (List ByteArray)

@[extern "l_hiredis_sinterstore"]
opaque sinterstore (ctx : @& Ctx) (dst : @& ByteArray) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_sintercard"]
opaque sintercard (ctx : @& Ctx) (keys : @& List ByteArray) (limit : @& Option UInt64) : EIO Error UInt64

@[extern "l_hiredis_sunion"]
opaque sunion (ctx : @& Ctx) (keys : @& List ByteArray) : EIO Error (List ByteArray)

@[extern "l_hiredis_sunionstore"]
opaque sunionstore (ctx : @& Ctx) (dst : @& ByteArray) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_sscan"]
opaque sscan (ctx : @& Ctx) (key : @& ByteArray) (cursor : @& UInt64) (pattern : @& Option ByteArray) (count : @& Option UInt64) : EIO Error (UInt64 × List ByteArray)

-- Key management commands
@[extern "l_hiredis_scan"]
opaque scan (ctx : @& Ctx) (cursor : @& UInt64) (pattern : @& Option ByteArray) (count : @& Option UInt64) (keyType : @& Option ByteArray) : EIO Error (UInt64 × List ByteArray)

@[extern "l_hiredis_expire"]
opaque expire (ctx : @& Ctx) (key : @& ByteArray) (seconds : @& UInt64) : EIO Error Bool

@[extern "l_hiredis_expireat"]
opaque expireat (ctx : @& Ctx) (key : @& ByteArray) (timestamp : @& UInt64) : EIO Error Bool

@[extern "l_hiredis_pexpire"]
opaque pexpire (ctx : @& Ctx) (key : @& ByteArray) (millis : @& UInt64) : EIO Error Bool

@[extern "l_hiredis_pexpireat"]
opaque pexpireat (ctx : @& Ctx) (key : @& ByteArray) (timestamp : @& UInt64) : EIO Error Bool

@[extern "l_hiredis_persist"]
opaque persistKey (ctx : @& Ctx) (key : @& ByteArray) : EIO Error Bool

@[extern "l_hiredis_rename"]
opaque renameKey (ctx : @& Ctx) (key : @& ByteArray) (newkey : @& ByteArray) : EIO Error Unit

@[extern "l_hiredis_renamenx"]
opaque renamenx (ctx : @& Ctx) (key : @& ByteArray) (newkey : @& ByteArray) : EIO Error Bool

@[extern "l_hiredis_copy"]
opaque copyKey (ctx : @& Ctx) (src : @& ByteArray) (dst : @& ByteArray) (replace : @& UInt8) : EIO Error Bool

@[extern "l_hiredis_unlink"]
opaque unlink (ctx : @& Ctx) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_touch"]
opaque touch (ctx : @& Ctx) (keys : @& List ByteArray) : EIO Error UInt64

@[extern "l_hiredis_expiretime"]
opaque expiretime (ctx : @& Ctx) (key : @& ByteArray) : EIO Error Int64

@[extern "l_hiredis_randomkey"]
opaque randomkey (ctx : @& Ctx) : EIO Error (Option ByteArray)

-- Hash commands (additional)
@[extern "l_hiredis_hlen"]
opaque hlen (ctx : @& Ctx) (key : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_hvals"]
opaque hvals (ctx : @& Ctx) (key : @& ByteArray) : EIO Error (List ByteArray)

@[extern "l_hiredis_hsetnx"]
opaque hsetnx (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) (value : @& ByteArray) : EIO Error Bool

@[extern "l_hiredis_hmget"]
opaque hmget (ctx : @& Ctx) (key : @& ByteArray) (fields : @& List ByteArray) : EIO Error (List (Option ByteArray))

@[extern "l_hiredis_hmset"]
opaque hmset (ctx : @& Ctx) (key : @& ByteArray) (pairs : @& List (ByteArray × ByteArray)) : EIO Error Unit

@[extern "l_hiredis_hincrbyfloat"]
opaque hincrbyfloat (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) (increment : @& Float) : EIO Error Float

@[extern "l_hiredis_hstrlen"]
opaque hstrlen (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) : EIO Error UInt64

@[extern "l_hiredis_hrandfield"]
opaque hrandfield (ctx : @& Ctx) (key : @& ByteArray) (count : @& Option UInt64) (withvalues : @& UInt8) : EIO Error (List ByteArray)

@[extern "l_hiredis_hscan"]
opaque hscan (ctx : @& Ctx) (key : @& ByteArray) (cursor : @& UInt64) (pattern : @& Option ByteArray) (count : @& Option UInt64) : EIO Error (UInt64 × List ByteArray)

-- Connection management: timeouts
@[extern "l_hiredis_connect_with_timeout"]
opaque connectWithTimeout (host : @& String) (port : @& UInt32) (timeoutMs : @& UInt64) : EIO Error Ctx

@[extern "l_hiredis_set_timeout"]
opaque setTimeout (ctx : @& Ctx) (timeoutMs : @& UInt64) : EIO Error Unit

@[extern "l_hiredis_enable_keepalive"]
opaque enableKeepAlive (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_set_keepalive_interval"]
opaque setKeepAliveInterval (ctx : @& Ctx) (intervalSec : @& Int32) : EIO Error Unit

-- Connection management: Unix sockets
@[extern "l_hiredis_connect_unix"]
opaque connectUnix (path : @& String) : EIO Error Ctx

@[extern "l_hiredis_connect_unix_with_timeout"]
opaque connectUnixWithTimeout (path : @& String) (timeoutMs : @& UInt64) : EIO Error Ctx

@[extern "l_hiredis_connect_unix_nonblock"]
opaque connectUnixNonBlock (path : @& String) : EIO Error Ctx

-- Connection management: reconnection
@[extern "l_hiredis_reconnect"]
opaque reconnect (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_is_connected"]
opaque isConnected (ctx : @& Ctx) : EIO Error Bool

@[extern "l_hiredis_get_fd"]
opaque getFd (ctx : @& Ctx) : EIO Error UInt32

@[extern "l_hiredis_get_error"]
opaque getError (ctx : @& Ctx) : EIO Error (Option String)

@[extern "l_hiredis_clear_error"]
opaque clearError (ctx : @& Ctx) : EIO Error Unit

-- Pipeline support
@[extern "l_hiredis_append_command"]
opaque appendCommand (ctx : @& Ctx) (command : @& String) : EIO Error Unit

@[extern "l_hiredis_append_command_argv"]
opaque appendCommandArgv (ctx : @& Ctx) (args : @& List ByteArray) : EIO Error Unit

@[extern "l_hiredis_get_reply"]
opaque getReply (ctx : @& Ctx) : EIO Error ByteArray

@[extern "l_hiredis_flush_pipeline"]
opaque flushPipeline (ctx : @& Ctx) : EIO Error Unit

-- Async support
@[extern "l_hiredis_connect_nonblock"]
opaque connectNonBlock (host : @& String) (port : @& UInt32) : EIO Error Ctx

@[extern "l_hiredis_can_read"]
opaque canRead (ctx : @& Ctx) (timeoutMs : @& UInt64) : EIO Error Bool

@[extern "l_hiredis_can_write"]
opaque canWrite (ctx : @& Ctx) (timeoutMs : @& UInt64) : EIO Error Bool

@[extern "l_hiredis_buffer_write"]
opaque bufferWrite (ctx : @& Ctx) : EIO Error Bool

@[extern "l_hiredis_buffer_read"]
opaque bufferRead (ctx : @& Ctx) : EIO Error Unit

@[extern "l_hiredis_get_reply_nonblock"]
opaque getReplyNonBlock (ctx : @& Ctx) : EIO Error (Option ByteArray)

end Internal

-- ByteArray-based helpers (direct FFI interface)

/-- Connect to Redis without SSL -/
def connectPlain (host := "127.0.0.1") (port : UInt32 := 6379) : EIO Error Ctx :=
  Internal.connect host port

/-- Connect to Redis with optional SSL configuration -/
def connect (host := "127.0.0.1") (port : UInt32 := 6379) (ssl : Option SSLConfig := none) : EIO Error Ctx :=
  match ssl with
  | none => Internal.connect host port
  | some sslConfig =>
    let verifyMode : UInt8 := match sslConfig.verifyMode with
      | .none => 0
      | .peer => 1
    Internal.connectSSL host port
      sslConfig.cacertPath
      sslConfig.caPath
      sslConfig.certPath
      sslConfig.keyPath
      sslConfig.serverName
      verifyMode

def free (ctx : Ctx) : EIO Error Unit := Internal.free ctx

def ping (ctx : Ctx) (msg : ByteArray) : EIO Error Bool := Internal.ping ctx msg

def auth (ctx : Ctx) (password : String) : EIO Error Bool := Internal.auth ctx password

def hello (ctx : Ctx) (protocol_version : UInt64 := 3) : EIO Error ByteArray := Internal.hello ctx protocol_version

def set (ctx : Ctx) (k v : ByteArray) (existsOption : SetExistsOption := .none) : EIO Error Unit :=
  Internal.set ctx k v existsOption.toUInt8

def setex (ctx : Ctx) (k v : ByteArray) (msec : UInt64) (existsOption : SetExistsOption := .none) : EIO Error Unit :=
  Internal.setex ctx k v msec existsOption.toUInt8

def get (ctx : Ctx) (k : ByteArray) : EIO Error ByteArray := Internal.get ctx k

def del (ctx : Ctx) (keys : List ByteArray) : EIO Error UInt64 := Internal.del ctx keys

def existsKey (ctx : Ctx) (key : ByteArray) : EIO Error Bool := Internal.existsKey ctx key

def typeKey (ctx : Ctx) (key : ByteArray) : EIO Error String := Internal.typeKey ctx key

def incr (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 := Internal.incr ctx key

def incrBy (ctx : Ctx) (key : ByteArray) (increment : Int64) : EIO Error UInt64 := Internal.incrby ctx key increment

def decr (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 := Internal.decr ctx key

def decrBy (ctx : Ctx) (key : ByteArray) (decrement : Int64) : EIO Error UInt64 := Internal.decrby ctx key decrement

def sismember (ctx : Ctx) (key member : ByteArray) : EIO Error Bool := Internal.sismember ctx key member

def scard (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 := Internal.scard ctx key

def sadd (ctx : Ctx) (key member : ByteArray) : EIO Error UInt64 := Internal.sadd ctx key member

def smembers (ctx : Ctx) (key : ByteArray) : EIO Error (List ByteArray) := Internal.smembers ctx key

def flushall (ctx : Ctx) (mode : String := "SYNC") : EIO Error Bool := Internal.flushall ctx mode

def publish (ctx : Ctx) (channel : String) (message : ByteArray) : EIO Error UInt64 := Internal.publish ctx channel message

def subscribe (ctx : Ctx) (channel : String) : EIO Error Bool := Internal.subscribe ctx channel

def command (ctx : Ctx) (command_str : String) : EIO Error ByteArray := Internal.command ctx command_str

def ttl (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 := Internal.ttl ctx key

def pttl (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 := Internal.pttl ctx key

def keys (ctx : Ctx) (pattern : ByteArray) : EIO Error (List ByteArray) := Internal.keys ctx pattern

def hset (ctx : Ctx) (key field value : ByteArray) : EIO Error UInt64 := Internal.hset ctx key field value

def hget (ctx : Ctx) (key field : ByteArray) : EIO Error ByteArray := Internal.hget ctx key field

def hgetall (ctx : Ctx) (key : ByteArray) : EIO Error (List ByteArray) := Internal.hgetall ctx key

def hdel (ctx : Ctx) (key field : ByteArray) : EIO Error UInt64 := Internal.hdel ctx key field

def hexists (ctx : Ctx) (key field : ByteArray) : EIO Error Bool := Internal.hexists ctx key field

def hincrby (ctx : Ctx) (key field : ByteArray) (increment : Int64) : EIO Error UInt64 := Internal.hincrby ctx key field increment

def hkeys (ctx : Ctx) (key : ByteArray) : EIO Error (List ByteArray) := Internal.hkeys ctx key

def zadd (ctx : Ctx) (key : ByteArray) (score : Float) (member : ByteArray) : EIO Error UInt64 := Internal.zadd ctx key score member

def zcard (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 := Internal.zcard ctx key

def zrange (ctx : Ctx) (key : ByteArray) (start stop : Int64) : EIO Error (List ByteArray) := Internal.zrange ctx key start stop

def zscore (ctx : Ctx) (key member : ByteArray) : EIO Error (Option Float) := Internal.zscore ctx key member

def zrank (ctx : Ctx) (key member : ByteArray) : EIO Error (Option UInt64) := Internal.zrank ctx key member

def zrevrank (ctx : Ctx) (key member : ByteArray) : EIO Error (Option UInt64) := Internal.zrevrank ctx key member

def zcount (ctx : Ctx) (key min max : ByteArray) : EIO Error UInt64 := Internal.zcount ctx key min max

def zincrby (ctx : Ctx) (key : ByteArray) (increment : Float) (member : ByteArray) : EIO Error Float := Internal.zincrby ctx key increment member

def zrem (ctx : Ctx) (key : ByteArray) (members : List ByteArray) : EIO Error UInt64 := Internal.zrem ctx key members

def zlexcount (ctx : Ctx) (key min max : ByteArray) : EIO Error UInt64 := Internal.zlexcount ctx key min max

def zmscore (ctx : Ctx) (key : ByteArray) (members : List ByteArray) : EIO Error (List (Option Float)) := Internal.zmscore ctx key members

def zrandmember (ctx : Ctx) (key : ByteArray) (count : Option Int64 := none) (withscores : Bool := false) : EIO Error (List ByteArray) :=
  Internal.zrandmember ctx key count (if withscores then 1 else 0)

def zscan (ctx : Ctx) (key : ByteArray) (cursor : UInt64) (pattern : Option ByteArray := none) (count : Option UInt64 := none) : EIO Error (UInt64 × List ByteArray) :=
  Internal.zscan ctx key cursor pattern count

def zrangebyscore (ctx : Ctx) (key min max : ByteArray) (withscores : Bool := false) (offset : Option UInt64 := none) (count : Option UInt64 := none) : EIO Error (List ByteArray) :=
  Internal.zrangebyscore ctx key min max (if withscores then 1 else 0) offset count

def zrevrange (ctx : Ctx) (key : ByteArray) (start stop : Int64) (withscores : Bool := false) : EIO Error (List ByteArray) :=
  Internal.zrevrange ctx key start stop (if withscores then 1 else 0)

def zrevrangebyscore (ctx : Ctx) (key max min : ByteArray) (withscores : Bool := false) (offset : Option UInt64 := none) (count : Option UInt64 := none) : EIO Error (List ByteArray) :=
  Internal.zrevrangebyscore ctx key max min (if withscores then 1 else 0) offset count

def zrangebylex (ctx : Ctx) (key min max : ByteArray) (offset : Option UInt64 := none) (count : Option UInt64 := none) : EIO Error (List ByteArray) :=
  Internal.zrangebylex ctx key min max offset count

def zrevrangebylex (ctx : Ctx) (key max min : ByteArray) (offset : Option UInt64 := none) (count : Option UInt64 := none) : EIO Error (List ByteArray) :=
  Internal.zrevrangebylex ctx key max min offset count

def zremrangebyrank (ctx : Ctx) (key : ByteArray) (start stop : Int64) : EIO Error UInt64 := Internal.zremrangebyrank ctx key start stop

def zremrangebyscore (ctx : Ctx) (key min max : ByteArray) : EIO Error UInt64 := Internal.zremrangebyscore ctx key min max

def zremrangebylex (ctx : Ctx) (key min max : ByteArray) : EIO Error UInt64 := Internal.zremrangebylex ctx key min max

def zpopmin (ctx : Ctx) (key : ByteArray) (count : Option UInt64 := none) : EIO Error (List ByteArray) := Internal.zpopmin ctx key count

def zpopmax (ctx : Ctx) (key : ByteArray) (count : Option UInt64 := none) : EIO Error (List ByteArray) := Internal.zpopmax ctx key count

def bzpopmin (ctx : Ctx) (keys : List ByteArray) (timeout : Float) : EIO Error (Option (ByteArray × ByteArray × ByteArray)) :=
  Internal.bzpopmin ctx keys timeout

def bzpopmax (ctx : Ctx) (keys : List ByteArray) (timeout : Float) : EIO Error (Option (ByteArray × ByteArray × ByteArray)) :=
  Internal.bzpopmax ctx keys timeout

def zunionstore (ctx : Ctx) (dest : ByteArray) (keys : List ByteArray) : EIO Error UInt64 := Internal.zunionstore ctx dest keys

def zinterstore (ctx : Ctx) (dest : ByteArray) (keys : List ByteArray) : EIO Error UInt64 := Internal.zinterstore ctx dest keys

def zdiffstore (ctx : Ctx) (dest : ByteArray) (keys : List ByteArray) : EIO Error UInt64 := Internal.zdiffstore ctx dest keys

def zunion (ctx : Ctx) (keys : List ByteArray) (withscores : Bool := false) : EIO Error (List ByteArray) :=
  Internal.zunion ctx keys (if withscores then 1 else 0)

def zinter (ctx : Ctx) (keys : List ByteArray) (withscores : Bool := false) : EIO Error (List ByteArray) :=
  Internal.zinter ctx keys (if withscores then 1 else 0)

def zdiff (ctx : Ctx) (keys : List ByteArray) (withscores : Bool := false) : EIO Error (List ByteArray) :=
  Internal.zdiff ctx keys (if withscores then 1 else 0)

def zintercard (ctx : Ctx) (keys : List ByteArray) (limit : Option UInt64 := none) : EIO Error UInt64 := Internal.zintercard ctx keys limit

def zrangestore (ctx : Ctx) (dst src min max : ByteArray) (rangeType : ByteArray := "".toUTF8) (rev : Bool := false) : EIO Error UInt64 :=
  Internal.zrangestore ctx dst src min max rangeType (if rev then 1 else 0)

-- HyperLogLog operations
def pfadd (ctx : Ctx) (key : ByteArray) (elements : List ByteArray) : EIO Error Bool := Internal.pfadd ctx key elements

def pfcount (ctx : Ctx) (keys : List ByteArray) : EIO Error UInt64 := Internal.pfcount ctx keys

def pfmerge (ctx : Ctx) (dest : ByteArray) (sources : List ByteArray) : EIO Error Unit := Internal.pfmerge ctx dest sources

-- Geospatial operations
def geoadd (ctx : Ctx) (key : ByteArray) (items : List (Float × Float × ByteArray)) : EIO Error UInt64 := Internal.geoadd ctx key items

def geodist (ctx : Ctx) (key member1 member2 : ByteArray) (unit : Option ByteArray := none) : EIO Error (Option Float) :=
  Internal.geodist ctx key member1 member2 unit

def geohash (ctx : Ctx) (key : ByteArray) (members : List ByteArray) : EIO Error (List (Option ByteArray)) := Internal.geohash ctx key members

def geopos (ctx : Ctx) (key : ByteArray) (members : List ByteArray) : EIO Error (List (Option (Float × Float))) := Internal.geopos ctx key members

def geosearch (ctx : Ctx) (key fromType fromValue byType : ByteArray) (radius : Float) (unit : ByteArray) (count : Option UInt64 := none) : EIO Error (List ByteArray) :=
  Internal.geosearch ctx key fromType fromValue byType radius unit count

def geosearchstore (ctx : Ctx) (dest src fromType fromValue byType : ByteArray) (radius : Float) (unit : ByteArray) (count : Option UInt64 := none) (storedist : Bool := false) : EIO Error UInt64 :=
  Internal.geosearchstore ctx dest src fromType fromValue byType radius unit count (if storedist then 1 else 0)

-- Bitmap operations
def setbit' (ctx : Ctx) (key : ByteArray) (offset : UInt64) (value : Bool) : EIO Error Bool := do
  let old ← Internal.setbit ctx key offset (if value then 1 else 0)
  pure (old != 0)

def getbit' (ctx : Ctx) (key : ByteArray) (offset : UInt64) : EIO Error Bool := do
  let bit ← Internal.getbit ctx key offset
  pure (bit != 0)

def bitcount (ctx : Ctx) (key : ByteArray) (start : Option Int64 := none) (stop : Option Int64 := none) : EIO Error UInt64 :=
  Internal.bitcount ctx key start stop

def bitop (ctx : Ctx) (operation destkey : ByteArray) (keys : List ByteArray) : EIO Error UInt64 :=
  Internal.bitop ctx operation destkey keys

def bitpos (ctx : Ctx) (key : ByteArray) (bit : Bool) (start : Option Int64 := none) (stop : Option Int64 := none) : EIO Error Int64 :=
  Internal.bitpos ctx key (if bit then 1 else 0) start stop

-- Transaction operations
def multi (ctx : Ctx) : EIO Error Unit := Internal.multi ctx

def exec (ctx : Ctx) : EIO Error (Option (List ByteArray)) := Internal.exec ctx

def discard (ctx : Ctx) : EIO Error Unit := Internal.discard ctx

def watch (ctx : Ctx) (keys : List ByteArray) : EIO Error Unit := Internal.watch ctx keys

def unwatch (ctx : Ctx) : EIO Error Unit := Internal.unwatch ctx

-- Scripting operations
def eval (ctx : Ctx) (script : ByteArray) (keys : List ByteArray := []) (args : List ByteArray := []) : EIO Error ByteArray :=
  Internal.eval ctx script keys args

def evalsha (ctx : Ctx) (sha1 : ByteArray) (keys : List ByteArray := []) (args : List ByteArray := []) : EIO Error ByteArray :=
  Internal.evalsha ctx sha1 keys args

def scriptload (ctx : Ctx) (script : ByteArray) : EIO Error ByteArray := Internal.scriptload ctx script

def scriptexists (ctx : Ctx) (sha1s : List ByteArray) : EIO Error (List Bool) := Internal.scriptexists ctx sha1s

def scriptflush (ctx : Ctx) : EIO Error Unit := Internal.scriptflush ctx

def scriptkill (ctx : Ctx) : EIO Error Unit := Internal.scriptkill ctx

-- Connection operations
def clientid (ctx : Ctx) : EIO Error UInt64 := Internal.clientid ctx

def clientgetname (ctx : Ctx) : EIO Error (Option ByteArray) := Internal.clientgetname ctx

def clientsetname (ctx : Ctx) (name : ByteArray) : EIO Error Unit := Internal.clientsetname ctx name

def clientlist (ctx : Ctx) : EIO Error ByteArray := Internal.clientlist ctx

def clientinfo (ctx : Ctx) : EIO Error ByteArray := Internal.clientinfo ctx

def clientkill (ctx : Ctx) (filterType filterValue : ByteArray) : EIO Error UInt64 := Internal.clientkill ctx filterType filterValue

def clientpause (ctx : Ctx) (timeout : UInt64) : EIO Error Unit := Internal.clientpause ctx timeout

def clientunpause (ctx : Ctx) : EIO Error Unit := Internal.clientunpause ctx

def selectDb (ctx : Ctx) (index : UInt64) : EIO Error Unit := Internal.selectDb ctx index

def echo (ctx : Ctx) (message : ByteArray) : EIO Error ByteArray := Internal.echo ctx message

def quit (ctx : Ctx) : EIO Error Unit := Internal.quit ctx

def reset (ctx : Ctx) : EIO Error Unit := Internal.reset ctx

-- Server operations
def info (ctx : Ctx) (infoSection : Option ByteArray := none) : EIO Error ByteArray := Internal.info ctx infoSection

def dbsize (ctx : Ctx) : EIO Error UInt64 := Internal.dbsize ctx

def lastsave (ctx : Ctx) : EIO Error UInt64 := Internal.lastsave ctx

def bgsave (ctx : Ctx) : EIO Error ByteArray := Internal.bgsave ctx

def bgrewriteaof (ctx : Ctx) : EIO Error ByteArray := Internal.bgrewriteaof ctx

def time (ctx : Ctx) : EIO Error (UInt64 × UInt64) := Internal.time ctx

def configget (ctx : Ctx) (parameter : ByteArray) : EIO Error (List ByteArray) := Internal.configget ctx parameter

def configset (ctx : Ctx) (parameter value : ByteArray) : EIO Error Unit := Internal.configset ctx parameter value

def configrewrite (ctx : Ctx) : EIO Error Unit := Internal.configrewrite ctx

def configresetstat (ctx : Ctx) : EIO Error Unit := Internal.configresetstat ctx

def memoryusage (ctx : Ctx) (key : ByteArray) : EIO Error (Option UInt64) := Internal.memoryusage ctx key

def objectencoding (ctx : Ctx) (key : ByteArray) : EIO Error (Option ByteArray) := Internal.objectencoding ctx key

def objectidletime (ctx : Ctx) (key : ByteArray) : EIO Error (Option UInt64) := Internal.objectidletime ctx key

def objectfreq (ctx : Ctx) (key : ByteArray) : EIO Error (Option UInt64) := Internal.objectfreq ctx key

def slowlogget (ctx : Ctx) (count : Option UInt64 := none) : EIO Error ByteArray := Internal.slowlogget ctx count

def slowloglen (ctx : Ctx) : EIO Error UInt64 := Internal.slowloglen ctx

def slowlogreset (ctx : Ctx) : EIO Error Unit := Internal.slowlogreset ctx

-- Redis Streams operations
def xadd (ctx : Ctx) (key stream_id : ByteArray) (field_values : List (ByteArray × ByteArray)) : EIO Error ByteArray :=
  Internal.xadd ctx key stream_id field_values

def xread (ctx : Ctx) (streams : List (ByteArray × ByteArray)) (count_opt : Option UInt64 := none) (block_opt : Option UInt64 := none) : EIO Error ByteArray :=
  Internal.xread ctx streams count_opt block_opt

def xrange (ctx : Ctx) (key start_id end_id : ByteArray) (count_opt : Option UInt64 := none) : EIO Error ByteArray :=
  Internal.xrange ctx key start_id end_id count_opt

def xlen (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 := Internal.xlen ctx key

def xdel (ctx : Ctx) (key : ByteArray) (entry_ids : List ByteArray) : EIO Error UInt64 := Internal.xdel ctx key entry_ids

def xtrim (ctx : Ctx) (key strategy : ByteArray) (max_len : UInt64) : EIO Error UInt64 := Internal.xtrim ctx key strategy max_len

-- Consumer group operations
def xreadgroup (ctx : Ctx) (group consumer stream : String) (count : UInt64) : EIO Error ByteArray :=
  Internal.xreadgroup ctx group consumer stream count

def xack (ctx : Ctx) (stream group msgid : String) : EIO Error UInt64 :=
  Internal.xack ctx stream group msgid

def xgroup_create (ctx : Ctx) (stream group start_id : String) : EIO Error Unit :=
  Internal.xgroup_create ctx stream group start_id

-- List operations

/-- Direction for list move operations -/
inductive ListDirection where
  | left : ListDirection
  | right : ListDirection
deriving Repr, BEq

def ListDirection.toUInt8 : ListDirection → UInt8
  | .left => 0
  | .right => 1

/-- Insert position for LINSERT -/
inductive InsertPosition where
  | before : InsertPosition
  | after : InsertPosition
deriving Repr, BEq

def InsertPosition.toUInt8 : InsertPosition → UInt8
  | .before => 0
  | .after => 1

def lpush (ctx : Ctx) (key : ByteArray) (elements : List ByteArray) : EIO Error UInt64 :=
  Internal.lpush ctx key elements

def rpush (ctx : Ctx) (key : ByteArray) (elements : List ByteArray) : EIO Error UInt64 :=
  Internal.rpush ctx key elements

def lpushx (ctx : Ctx) (key : ByteArray) (elements : List ByteArray) : EIO Error UInt64 :=
  Internal.lpushx ctx key elements

def rpushx (ctx : Ctx) (key : ByteArray) (elements : List ByteArray) : EIO Error UInt64 :=
  Internal.rpushx ctx key elements

def lpop (ctx : Ctx) (key : ByteArray) (count : Option UInt64 := none) : EIO Error (List ByteArray) :=
  Internal.lpop ctx key count

def rpop (ctx : Ctx) (key : ByteArray) (count : Option UInt64 := none) : EIO Error (List ByteArray) :=
  Internal.rpop ctx key count

def lrange (ctx : Ctx) (key : ByteArray) (start stop : Int64) : EIO Error (List ByteArray) :=
  Internal.lrange ctx key start stop

def lindex (ctx : Ctx) (key : ByteArray) (index : Int64) : EIO Error ByteArray :=
  Internal.lindex ctx key index

def llen (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 :=
  Internal.llen ctx key

def lset (ctx : Ctx) (key : ByteArray) (index : Int64) (value : ByteArray) : EIO Error Unit :=
  Internal.lset ctx key index value

def linsert (ctx : Ctx) (key : ByteArray) (position : InsertPosition) (pivot value : ByteArray) : EIO Error Int64 :=
  Internal.linsert ctx key position.toUInt8 pivot value

def ltrim (ctx : Ctx) (key : ByteArray) (start stop : Int64) : EIO Error Unit :=
  Internal.ltrim ctx key start stop

def lrem (ctx : Ctx) (key : ByteArray) (count : Int64) (value : ByteArray) : EIO Error UInt64 :=
  Internal.lrem ctx key count value

def lpos (ctx : Ctx) (key element : ByteArray) (rank : Option UInt64 := none) (count : Option UInt64 := none) : EIO Error (Option UInt64) :=
  Internal.lpos ctx key element rank count

def lmove (ctx : Ctx) (src dst : ByteArray) (srcDir dstDir : ListDirection) : EIO Error ByteArray :=
  Internal.lmove ctx src dst srcDir.toUInt8 dstDir.toUInt8

def lmpop (ctx : Ctx) (keys : List ByteArray) (direction : ListDirection) (count : Option UInt64 := none) : EIO Error (Option (ByteArray × List ByteArray)) :=
  Internal.lmpop ctx keys direction.toUInt8 count

def blpop (ctx : Ctx) (keys : List ByteArray) (timeout : Float) : EIO Error (Option (ByteArray × ByteArray)) :=
  Internal.blpop ctx keys timeout

def brpop (ctx : Ctx) (keys : List ByteArray) (timeout : Float) : EIO Error (Option (ByteArray × ByteArray)) :=
  Internal.brpop ctx keys timeout

def blmove (ctx : Ctx) (src dst : ByteArray) (srcDir dstDir : ListDirection) (timeout : Float) : EIO Error (Option ByteArray) :=
  Internal.blmove ctx src dst srcDir.toUInt8 dstDir.toUInt8 timeout

def blmpop (ctx : Ctx) (timeout : Float) (keys : List ByteArray) (direction : ListDirection) (count : Option UInt64 := none) : EIO Error (Option (ByteArray × List ByteArray)) :=
  Internal.blmpop ctx timeout keys direction.toUInt8 count

def rpoplpush (ctx : Ctx) (src dst : ByteArray) : EIO Error ByteArray :=
  Internal.rpoplpush ctx src dst

def brpoplpush (ctx : Ctx) (src dst : ByteArray) (timeout : Float) : EIO Error (Option ByteArray) :=
  Internal.brpoplpush ctx src dst timeout

-- String operations (additional)

def append (ctx : Ctx) (key value : ByteArray) : EIO Error UInt64 :=
  Internal.append ctx key value

def getdel (ctx : Ctx) (key : ByteArray) : EIO Error ByteArray :=
  Internal.getdel ctx key

/-- Get value and optionally set expiration -/
def getex (ctx : Ctx) (key : ByteArray) (exSeconds : Option UInt64 := none) (pxMillis : Option UInt64 := none) (persist : Bool := false) : EIO Error ByteArray :=
  Internal.getex ctx key exSeconds pxMillis (if persist then 1 else 0)

def getrange (ctx : Ctx) (key : ByteArray) (start stop : Int64) : EIO Error ByteArray :=
  Internal.getrange ctx key start stop

def getset (ctx : Ctx) (key value : ByteArray) : EIO Error ByteArray :=
  Internal.getset ctx key value

def incrByFloat (ctx : Ctx) (key : ByteArray) (increment : Float) : EIO Error Float :=
  Internal.incrbyfloat ctx key increment

def mget (ctx : Ctx) (keys : List ByteArray) : EIO Error (List (Option ByteArray)) :=
  Internal.mget ctx keys

def mset (ctx : Ctx) (pairs : List (ByteArray × ByteArray)) : EIO Error Unit :=
  Internal.mset ctx pairs

def msetnx (ctx : Ctx) (pairs : List (ByteArray × ByteArray)) : EIO Error Bool :=
  Internal.msetnx ctx pairs

def setnx (ctx : Ctx) (key value : ByteArray) : EIO Error Bool :=
  Internal.setnx ctx key value

def setrange (ctx : Ctx) (key : ByteArray) (offset : UInt64) (value : ByteArray) : EIO Error UInt64 :=
  Internal.setrange ctx key offset value

def strlen (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 :=
  Internal.strlen ctx key

def psetex (ctx : Ctx) (key : ByteArray) (millis : UInt64) (value : ByteArray) : EIO Error Unit :=
  Internal.psetex ctx key millis value

/-- Find longest common subsequence between two strings -/
def lcs (ctx : Ctx) (key1 key2 : ByteArray) (getLen : Bool := false) (getIdx : Bool := false) : EIO Error ByteArray :=
  Internal.lcs ctx key1 key2 (if getLen then 1 else 0) (if getIdx then 1 else 0)

-- Set operations (additional)

def srem (ctx : Ctx) (key : ByteArray) (members : List ByteArray) : EIO Error UInt64 :=
  Internal.srem ctx key members

def spop (ctx : Ctx) (key : ByteArray) (count : Option UInt64 := none) : EIO Error (List ByteArray) :=
  Internal.spop ctx key count

def srandmember (ctx : Ctx) (key : ByteArray) (count : Option UInt64 := none) : EIO Error (List ByteArray) :=
  Internal.srandmember ctx key count

def smove (ctx : Ctx) (src dst member : ByteArray) : EIO Error Bool :=
  Internal.smove ctx src dst member

def smismember (ctx : Ctx) (key : ByteArray) (members : List ByteArray) : EIO Error (List Bool) :=
  Internal.smismember ctx key members

def sdiff (ctx : Ctx) (keys : List ByteArray) : EIO Error (List ByteArray) :=
  Internal.sdiff ctx keys

def sdiffstore (ctx : Ctx) (dst : ByteArray) (keys : List ByteArray) : EIO Error UInt64 :=
  Internal.sdiffstore ctx dst keys

def sinter (ctx : Ctx) (keys : List ByteArray) : EIO Error (List ByteArray) :=
  Internal.sinter ctx keys

def sinterstore (ctx : Ctx) (dst : ByteArray) (keys : List ByteArray) : EIO Error UInt64 :=
  Internal.sinterstore ctx dst keys

def sintercard (ctx : Ctx) (keys : List ByteArray) (limit : Option UInt64 := none) : EIO Error UInt64 :=
  Internal.sintercard ctx keys limit

def sunion (ctx : Ctx) (keys : List ByteArray) : EIO Error (List ByteArray) :=
  Internal.sunion ctx keys

def sunionstore (ctx : Ctx) (dst : ByteArray) (keys : List ByteArray) : EIO Error UInt64 :=
  Internal.sunionstore ctx dst keys

def sscan (ctx : Ctx) (key : ByteArray) (cursor : UInt64) (pattern : Option ByteArray := none) (count : Option UInt64 := none) : EIO Error (UInt64 × List ByteArray) :=
  Internal.sscan ctx key cursor pattern count

-- Key management operations

def scan (ctx : Ctx) (cursor : UInt64) (pattern : Option ByteArray := none) (count : Option UInt64 := none) (keyType : Option ByteArray := none) : EIO Error (UInt64 × List ByteArray) :=
  Internal.scan ctx cursor pattern count keyType

def expire (ctx : Ctx) (key : ByteArray) (seconds : UInt64) : EIO Error Bool :=
  Internal.expire ctx key seconds

def expireat (ctx : Ctx) (key : ByteArray) (timestamp : UInt64) : EIO Error Bool :=
  Internal.expireat ctx key timestamp

def pexpire (ctx : Ctx) (key : ByteArray) (millis : UInt64) : EIO Error Bool :=
  Internal.pexpire ctx key millis

def pexpireat (ctx : Ctx) (key : ByteArray) (timestamp : UInt64) : EIO Error Bool :=
  Internal.pexpireat ctx key timestamp

def persist (ctx : Ctx) (key : ByteArray) : EIO Error Bool :=
  Internal.persistKey ctx key

def rename (ctx : Ctx) (key newkey : ByteArray) : EIO Error Unit :=
  Internal.renameKey ctx key newkey

def renamenx (ctx : Ctx) (key newkey : ByteArray) : EIO Error Bool :=
  Internal.renamenx ctx key newkey

def copy (ctx : Ctx) (src dst : ByteArray) (replace : Bool := false) : EIO Error Bool :=
  Internal.copyKey ctx src dst (if replace then 1 else 0)

def unlink (ctx : Ctx) (keys : List ByteArray) : EIO Error UInt64 :=
  Internal.unlink ctx keys

def touch (ctx : Ctx) (keys : List ByteArray) : EIO Error UInt64 :=
  Internal.touch ctx keys

def expiretime (ctx : Ctx) (key : ByteArray) : EIO Error Int64 :=
  Internal.expiretime ctx key

def randomkey (ctx : Ctx) : EIO Error (Option ByteArray) :=
  Internal.randomkey ctx

-- Hash operations (additional)

def hlen (ctx : Ctx) (key : ByteArray) : EIO Error UInt64 :=
  Internal.hlen ctx key

def hvals (ctx : Ctx) (key : ByteArray) : EIO Error (List ByteArray) :=
  Internal.hvals ctx key

def hsetnx (ctx : Ctx) (key field value : ByteArray) : EIO Error Bool :=
  Internal.hsetnx ctx key field value

def hmget (ctx : Ctx) (key : ByteArray) (fields : List ByteArray) : EIO Error (List (Option ByteArray)) :=
  Internal.hmget ctx key fields

def hmset (ctx : Ctx) (key : ByteArray) (pairs : List (ByteArray × ByteArray)) : EIO Error Unit :=
  Internal.hmset ctx key pairs

def hincrByFloat (ctx : Ctx) (key field : ByteArray) (increment : Float) : EIO Error Float :=
  Internal.hincrbyfloat ctx key field increment

def hstrlen (ctx : Ctx) (key field : ByteArray) : EIO Error UInt64 :=
  Internal.hstrlen ctx key field

def hrandfield (ctx : Ctx) (key : ByteArray) (count : Option UInt64 := none) (withvalues : Bool := false) : EIO Error (List ByteArray) :=
  Internal.hrandfield ctx key count (if withvalues then 1 else 0)

def hscan (ctx : Ctx) (key : ByteArray) (cursor : UInt64) (pattern : Option ByteArray := none) (count : Option UInt64 := none) : EIO Error (UInt64 × List ByteArray) :=
  Internal.hscan ctx key cursor pattern count

-- convenience: connect + auto‑free
def withRedis (host := "127.0.0.1") (port : UInt32 := 6379) (k : Ctx → EIO Error α) : EIO Error α := do
  let ctx ← connectPlain host port
  try
    k ctx
  finally
    Internal.free ctx

/-- Connect with SSL configuration + auto-free -/
def withRedisSSL (host := "127.0.0.1") (port : UInt32 := 6379) (ssl : SSLConfig) (k : Ctx → EIO Error α) : EIO Error α := do
  let ctx ← connect host port (some ssl)
  try
    k ctx
  finally
    Internal.free ctx

-- Helper to convert EIO to IO with error handling
def toIO {α : Type} (eio : EIO Error α) : IO α :=
  EIO.toIO (fun e => IO.userError (toString e)) eio

/-! ## Connection Options & Timeouts -/

/-- Connect with a timeout (milliseconds) -/
def connectWithTimeout (host := "127.0.0.1") (port : UInt32 := 6379) (timeoutMs : UInt64) : EIO Error Ctx :=
  Internal.connectWithTimeout host port timeoutMs

/-- Set command timeout on existing connection (milliseconds) -/
def setTimeout (ctx : Ctx) (timeoutMs : UInt64) : EIO Error Unit :=
  Internal.setTimeout ctx timeoutMs

/-- Enable TCP keepalive on connection -/
def enableKeepAlive (ctx : Ctx) : EIO Error Unit :=
  Internal.enableKeepAlive ctx

/-- Set TCP keepalive interval (seconds) -/
def setKeepAliveInterval (ctx : Ctx) (intervalSec : Int32) : EIO Error Unit :=
  Internal.setKeepAliveInterval ctx intervalSec

/-! ## Unix Socket Connections -/

/-- Connect via Unix socket -/
def connectUnix (path : String) : EIO Error Ctx :=
  Internal.connectUnix path

/-- Connect via Unix socket with timeout (milliseconds) -/
def connectUnixWithTimeout (path : String) (timeoutMs : UInt64) : EIO Error Ctx :=
  Internal.connectUnixWithTimeout path timeoutMs

/-- Connect via Unix socket + auto-free -/
def withRedisUnix (path : String) (k : Ctx → EIO Error α) : EIO Error α := do
  let ctx ← connectUnix path
  try
    k ctx
  finally
    Internal.free ctx

/-! ## Reconnection Support -/

/-- Reconnect using the same connection parameters -/
def reconnect (ctx : Ctx) : EIO Error Unit :=
  Internal.reconnect ctx

/-- Check if connection is still alive -/
def isConnected (ctx : Ctx) : EIO Error Bool :=
  Internal.isConnected ctx

/-- Get file descriptor for the connection -/
def getFd (ctx : Ctx) : EIO Error UInt32 :=
  Internal.getFd ctx

/-- Get the connection error string (if any) -/
def getError (ctx : Ctx) : EIO Error (Option String) :=
  Internal.getError ctx

/-- Clear the error state -/
def clearError (ctx : Ctx) : EIO Error Unit :=
  Internal.clearError ctx

/-! ## Pipeline Support -/

/-- Append a command to the output buffer (no network round-trip yet) -/
def appendCommand (ctx : Ctx) (command : String) : EIO Error Unit :=
  Internal.appendCommand ctx command

/-- Append a command with arguments to the output buffer -/
def appendCommandArgv (ctx : Ctx) (args : List ByteArray) : EIO Error Unit :=
  Internal.appendCommandArgv ctx args

/-- Get the next reply from the pipeline -/
def getReply (ctx : Ctx) : EIO Error ByteArray :=
  Internal.getReply ctx

/-- Flush the output buffer (send all pending commands) -/
def flushPipeline (ctx : Ctx) : EIO Error Unit :=
  Internal.flushPipeline ctx

/-- Pipeline builder for batching commands -/
structure PipelineBuilder where
  commands : Array String
  deriving Repr

namespace PipelineBuilder

/-- Create an empty pipeline builder -/
def empty : PipelineBuilder := ⟨#[]⟩

/-- Add a command to the pipeline -/
def add (pb : PipelineBuilder) (cmd : String) : PipelineBuilder :=
  ⟨pb.commands.push cmd⟩

/-- Add SET command to pipeline -/
def set (pb : PipelineBuilder) (key value : String) : PipelineBuilder :=
  pb.add s!"SET {key} {value}"

/-- Add GET command to pipeline -/
def get (pb : PipelineBuilder) (key : String) : PipelineBuilder :=
  pb.add s!"GET {key}"

/-- Add INCR command to pipeline -/
def incr (pb : PipelineBuilder) (key : String) : PipelineBuilder :=
  pb.add s!"INCR {key}"

/-- Add DEL command to pipeline -/
def del (pb : PipelineBuilder) (key : String) : PipelineBuilder :=
  pb.add s!"DEL {key}"

/-- Add HSET command to pipeline -/
def hset (pb : PipelineBuilder) (key field value : String) : PipelineBuilder :=
  pb.add s!"HSET {key} {field} {value}"

/-- Add HGET command to pipeline -/
def hget (pb : PipelineBuilder) (key field : String) : PipelineBuilder :=
  pb.add s!"HGET {key} {field}"

/-- Number of commands in pipeline -/
def size (pb : PipelineBuilder) : Nat := pb.commands.size

end PipelineBuilder

/-- Execute a pipeline and return all replies -/
def executePipeline (ctx : Ctx) (pb : PipelineBuilder) : EIO Error (Array ByteArray) := do
  -- Send all commands
  for cmd in pb.commands do
    appendCommand ctx cmd
  -- Flush to send
  flushPipeline ctx
  -- Collect all replies
  let mut replies : Array ByteArray := #[]
  for _ in [:pb.commands.size] do
    let reply ← getReply ctx
    replies := replies.push reply
  return replies

/-- Execute pipeline with a builder function -/
def withPipeline (ctx : Ctx) (build : PipelineBuilder → PipelineBuilder) : EIO Error (Array ByteArray) := do
  let pb := build PipelineBuilder.empty
  executePipeline ctx pb

/-! ## Async/Non-blocking Support -/

/-- Connect without blocking (for async patterns) -/
def connectNonBlock (host := "127.0.0.1") (port : UInt32 := 6379) : EIO Error Ctx :=
  Internal.connectNonBlock host port

/-- Check if there's data available to read (with timeout in ms) -/
def canRead (ctx : Ctx) (timeoutMs : UInt64 := 0) : EIO Error Bool :=
  Internal.canRead ctx timeoutMs

/-- Check if we can write without blocking (with timeout in ms) -/
def canWrite (ctx : Ctx) (timeoutMs : UInt64 := 0) : EIO Error Bool :=
  Internal.canWrite ctx timeoutMs

/-- Send pending data in output buffer. Returns true if done. -/
def bufferWrite (ctx : Ctx) : EIO Error Bool :=
  Internal.bufferWrite ctx

/-- Read data into input buffer -/
def bufferRead (ctx : Ctx) : EIO Error Unit :=
  Internal.bufferRead ctx

/-- Try to get a reply from input buffer (non-blocking, returns None if not ready) -/
def getReplyNonBlock (ctx : Ctx) : EIO Error (Option ByteArray) :=
  Internal.getReplyNonBlock ctx

/-- Poll for a reply with timeout (milliseconds). Returns None on timeout. -/
def pollReply (ctx : Ctx) (timeoutMs : UInt64) : EIO Error (Option ByteArray) := do
  -- Check if data is available
  let readable ← canRead ctx timeoutMs
  if !readable then
    return none
  -- Read into buffer
  bufferRead ctx
  -- Try to get reply
  getReplyNonBlock ctx

end FFI

end Redis
