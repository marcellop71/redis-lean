-- FFI layer wrapping the hiredis C library
import RedisLean.Error

namespace RedisLean

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

-- FFI declarations of functions wrapped around hiredis
-- data types used are the Lean equivalent of C data types used in hiredis
namespace hiredis

@[extern "l_hiredis_connect"]
opaque connect (host : @& String) (port : @& UInt32) : EIO RedisError Ctx

@[extern "l_hiredis_free"]
opaque free (ctx : @& Ctx) : EIO RedisError Unit

@[extern "l_hiredis_ping"]
opaque ping (ctx : @& Ctx) (msg : @& ByteArray) : EIO RedisError Bool

@[extern "l_hiredis_set"]
opaque set (ctx : @& Ctx) (k : @& ByteArray) (v : @& ByteArray) (existsOption : @& UInt8) : EIO RedisError Unit

@[extern "l_hiredis_setex"]
opaque setex (ctx : @& Ctx) (k : @& ByteArray) (v : @& ByteArray) (msec : @& UInt64) (existsOption : @& UInt8) : EIO RedisError Unit

@[extern "l_hiredis_get"]
opaque get (ctx : @& Ctx) (k : @& ByteArray) : EIO RedisError ByteArray

@[extern "l_hiredis_del"]
opaque del (ctx : @& Ctx) (keys : @& List ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_exists"]
opaque existsKey (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError Bool

@[extern "l_hiredis_type"]
opaque typeKey (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError String

@[extern "l_hiredis_incr"]
opaque incr (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_incrby"]
opaque incrby (ctx : @& Ctx) (key : @& ByteArray) (increment : @& Int64) : EIO RedisError UInt64

@[extern "l_hiredis_decr"]
opaque decr (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_decrby"]
opaque decrby (ctx : @& Ctx) (key : @& ByteArray) (decrement : @& Int64) : EIO RedisError UInt64

@[extern "l_hiredis_sismember"]
opaque sismember (ctx : @& Ctx) (key : @& ByteArray) (member : @& ByteArray) : EIO RedisError Bool

@[extern "l_hiredis_scard"]
opaque scard (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_sadd"]
opaque sadd (ctx : @& Ctx) (key : @& ByteArray) (member : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_flushall"]
opaque flushall (ctx : @& Ctx) (mode : @& String) : EIO RedisError Bool

@[extern "l_hiredis_publish"]
opaque publish (ctx : @& Ctx) (channel : @& String) (message : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_command"]
opaque command (ctx : @& Ctx) (command_str : @& String) : EIO RedisError ByteArray

@[extern "l_hiredis_ttl"]
opaque ttl (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_pttl"]
opaque pttl (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_keys"]
opaque keys (ctx : @& Ctx) (pattern : @& ByteArray) : EIO RedisError (List ByteArray)

@[extern "l_hiredis_hset"]
opaque hset (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) (value : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_hget"]
opaque hget (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) : EIO RedisError ByteArray

@[extern "l_hiredis_hgetall"]
opaque hgetall (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError (List ByteArray)

@[extern "l_hiredis_hdel"]
opaque hdel (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_hexists"]
opaque hexists (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) : EIO RedisError Bool

@[extern "l_hiredis_hincrby"]
opaque hincrby (ctx : @& Ctx) (key : @& ByteArray) (field : @& ByteArray) (increment : @& Int64) : EIO RedisError UInt64

@[extern "l_hiredis_hkeys"]
opaque hkeys (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError (List ByteArray)

@[extern "l_hiredis_zadd"]
opaque zadd (ctx : @& Ctx) (key : @& ByteArray) (score : @& Float) (member : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_zcard"]
opaque zcard (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_zrange"]
opaque zrange (ctx : @& Ctx) (key : @& ByteArray) (start : @& Int64) (stop : @& Int64) : EIO RedisError (List ByteArray)

-- Redis Streams commands
@[extern "l_hiredis_xadd"]
opaque xadd (ctx : @& Ctx) (key : @& ByteArray) (stream_id : @& ByteArray) (field_values : @& List (ByteArray × ByteArray)) : EIO RedisError ByteArray

@[extern "l_hiredis_xread"]
opaque xread (ctx : @& Ctx) (streams : @& List (ByteArray × ByteArray)) (count_opt : @& Option UInt64) (block_opt : @& Option UInt64) : EIO RedisError ByteArray

@[extern "l_hiredis_xrange"]
opaque xrange (ctx : @& Ctx) (key : @& ByteArray) (start_id : @& ByteArray) (end_id : @& ByteArray) (count_opt : @& Option UInt64) : EIO RedisError ByteArray

@[extern "l_hiredis_xlen"]
opaque xlen (ctx : @& Ctx) (key : @& ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_xdel"]
opaque xdel (ctx : @& Ctx) (key : @& ByteArray) (entry_ids : @& List ByteArray) : EIO RedisError UInt64

@[extern "l_hiredis_xtrim"]
opaque xtrim (ctx : @& Ctx) (key : @& ByteArray) (strategy : @& ByteArray) (max_len : @& UInt64) : EIO RedisError UInt64

end hiredis

/-- ByteArray-based helpers (direct FFI interface) -/

def connect (host := "127.0.0.1") (port : UInt32 := 6379) : EIO RedisError Ctx := hiredis.connect host port

def free (ctx : Ctx) : EIO RedisError Unit := hiredis.free ctx

def ping (ctx : Ctx) (msg : ByteArray) : EIO RedisError Bool := hiredis.ping ctx msg

def set (ctx : Ctx) (k v : ByteArray) (existsOption : SetExistsOption := .none) : EIO RedisError Unit :=
  hiredis.set ctx k v existsOption.toUInt8

def setex (ctx : Ctx) (k v : ByteArray) (msec : UInt64) (existsOption : SetExistsOption := .none) : EIO RedisError Unit :=
  hiredis.setex ctx k v msec existsOption.toUInt8

def get (ctx : Ctx) (k : ByteArray) : EIO RedisError ByteArray := hiredis.get ctx k

def del (ctx : Ctx) (keys : List ByteArray) : EIO RedisError UInt64 := hiredis.del ctx keys

def existsKey (ctx : Ctx) (key : ByteArray) : EIO RedisError Bool := hiredis.existsKey ctx key

def typeKey (ctx : Ctx) (key : ByteArray) : EIO RedisError String := hiredis.typeKey ctx key

def incr (ctx : Ctx) (key : ByteArray) : EIO RedisError UInt64 := hiredis.incr ctx key

def incrBy (ctx : Ctx) (key : ByteArray) (increment : Int64) : EIO RedisError UInt64 := hiredis.incrby ctx key increment

def decr (ctx : Ctx) (key : ByteArray) : EIO RedisError UInt64 := hiredis.decr ctx key

def decrBy (ctx : Ctx) (key : ByteArray) (decrement : Int64) : EIO RedisError UInt64 := hiredis.decrby ctx key decrement

def sismember (ctx : Ctx) (key member : ByteArray) : EIO RedisError Bool := hiredis.sismember ctx key member

def scard (ctx : Ctx) (key : ByteArray) : EIO RedisError UInt64 := hiredis.scard ctx key

def sadd (ctx : Ctx) (key member : ByteArray) : EIO RedisError UInt64 := hiredis.sadd ctx key member

def flushall (ctx : Ctx) (mode : String := "SYNC") : EIO RedisError Bool := hiredis.flushall ctx mode

def publish (ctx : Ctx) (channel : String) (message : ByteArray) : EIO RedisError UInt64 := hiredis.publish ctx channel message

def command (ctx : Ctx) (command_str : String) : EIO RedisError ByteArray := hiredis.command ctx command_str

def ttl (ctx : Ctx) (key : ByteArray) : EIO RedisError UInt64 := hiredis.ttl ctx key

def pttl (ctx : Ctx) (key : ByteArray) : EIO RedisError UInt64 := hiredis.pttl ctx key

def keys (ctx : Ctx) (pattern : ByteArray) : EIO RedisError (List ByteArray) := hiredis.keys ctx pattern

def hset (ctx : Ctx) (key field value : ByteArray) : EIO RedisError UInt64 := hiredis.hset ctx key field value

def hget (ctx : Ctx) (key field : ByteArray) : EIO RedisError ByteArray := hiredis.hget ctx key field

def hgetall (ctx : Ctx) (key : ByteArray) : EIO RedisError (List ByteArray) := hiredis.hgetall ctx key

def hdel (ctx : Ctx) (key field : ByteArray) : EIO RedisError UInt64 := hiredis.hdel ctx key field

def hexists (ctx : Ctx) (key field : ByteArray) : EIO RedisError Bool := hiredis.hexists ctx key field

def hincrby (ctx : Ctx) (key field : ByteArray) (increment : Int64) : EIO RedisError UInt64 := hiredis.hincrby ctx key field increment

def hkeys (ctx : Ctx) (key : ByteArray) : EIO RedisError (List ByteArray) := hiredis.hkeys ctx key

def zadd (ctx : Ctx) (key : ByteArray) (score : Float) (member : ByteArray) : EIO RedisError UInt64 := hiredis.zadd ctx key score member

def zcard (ctx : Ctx) (key : ByteArray) : EIO RedisError UInt64 := hiredis.zcard ctx key

def zrange (ctx : Ctx) (key : ByteArray) (start stop : Int64) : EIO RedisError (List ByteArray) := hiredis.zrange ctx key start stop

-- Redis Streams operations
def xadd (ctx : Ctx) (key stream_id : ByteArray) (field_values : List (ByteArray × ByteArray)) : EIO RedisError ByteArray :=
  hiredis.xadd ctx key stream_id field_values

def xread (ctx : Ctx) (streams : List (ByteArray × ByteArray)) (count_opt : Option UInt64 := none) (block_opt : Option UInt64 := none) : EIO RedisError ByteArray :=
  hiredis.xread ctx streams count_opt block_opt

def xrange (ctx : Ctx) (key start_id end_id : ByteArray) (count_opt : Option UInt64 := none) : EIO RedisError ByteArray :=
  hiredis.xrange ctx key start_id end_id count_opt

def xlen (ctx : Ctx) (key : ByteArray) : EIO RedisError UInt64 := hiredis.xlen ctx key

def xdel (ctx : Ctx) (key : ByteArray) (entry_ids : List ByteArray) : EIO RedisError UInt64 := hiredis.xdel ctx key entry_ids

def xtrim (ctx : Ctx) (key strategy : ByteArray) (max_len : UInt64) : EIO RedisError UInt64 := hiredis.xtrim ctx key strategy max_len

-- convenience: connect + auto‑free
def withRedis (host := "127.0.0.1") (port : UInt32 := 6379) (k : Ctx → EIO RedisError α) : EIO RedisError α := do
  let ctx ← hiredis.connect host port
  try
    k ctx
  finally
    hiredis.free ctx

-- Helper to convert EIO to IO with error handling
def toIO {α : Type} (eio : EIO RedisError α) : IO α :=
  EIO.toIO (fun e => IO.userError (toString e)) eio

end FFI

end RedisLean
