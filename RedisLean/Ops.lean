import RedisLean.Codec
import RedisLean.FFI
import RedisLean.Enums
import RedisLean.Monad

open RedisLean

namespace RedisLean

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

  -- operations on keys
  del : List α → m Nat
  existsKey : α → m Bool
  typeKey : α → m RedisValue

  -- operations on strings that can be parsed as integers
  incr : α → m Int
  incrBy : α → Int → m Int
  decr : α → m Int
  decrBy : α → Int → m Int

  -- operations on sets
  sismember {β : Type} [Codec β] : α → β → m Bool
  scard : α → m Nat
  sadd {β : Type} [Codec β] : α → β → m Nat

  -- Pub/Sub operations
  publish {β: Type} [Codec β] : String → β → m Nat

  -- Redis Streams operations
  xadd {β : Type} [Codec β] : α → String → List (α × β) → m String
  xread : List (α × String) → Option Nat → Option Nat → m ByteArray
  xrange : α → String → String → Option Nat → m ByteArray
  xlen : α → m Nat
  xdel : α → List String → m Nat
  xtrim : α → String → Nat → m Nat  -- other operations
  ping : α → m Bool

-- implementation for the RedisM monad using FFI.hiredis
instance [Codec α] : Ops α RedisM where
  set := fun k v => liftRedisEIO RedisCmd.SET (fun ctx => FFI.hiredis.set ctx (Codec.enc k) (Codec.enc v) FFI.SetExistsOption.none.toUInt8)
  setnx := fun k v => liftRedisEIO RedisCmd.SET (fun ctx => FFI.hiredis.set ctx (Codec.enc k) (Codec.enc v) FFI.SetExistsOption.nx.toUInt8)
  setxx := fun k v => liftRedisEIO RedisCmd.SET (fun ctx => FFI.hiredis.set ctx (Codec.enc k) (Codec.enc v) FFI.SetExistsOption.xx.toUInt8)
  setex := fun k v msec => liftRedisEIO RedisCmd.SETEX (fun ctx => FFI.hiredis.setex ctx (Codec.enc k) (Codec.enc v) (UInt64.ofNat msec) FFI.SetExistsOption.none.toUInt8)
  setexnx := fun k v msec => liftRedisEIO RedisCmd.SETEX (fun ctx => FFI.hiredis.setex ctx (Codec.enc k) (Codec.enc v) (UInt64.ofNat msec) FFI.SetExistsOption.nx.toUInt8)
  setexxx := fun k v msec => liftRedisEIO RedisCmd.SETEX (fun ctx => FFI.hiredis.setex ctx (Codec.enc k) (Codec.enc v) (UInt64.ofNat msec) FFI.SetExistsOption.xx.toUInt8)
  get := fun k => do
    let tmp ← liftRedisEIO RedisCmd.GET (fun ctx => FFI.hiredis.get ctx (Codec.enc k))
    return tmp
  getAs := fun β [Codec β] k => do
    let tmp ← liftRedisEIO RedisCmd.GET (fun ctx => FFI.hiredis.get ctx (Codec.enc k))
    match Codec.dec tmp with
    | .ok value => return value
    | .error msg => throw (RedisError.otherError s!"Codec decoding failed: {msg}")

  del := fun ks => do
    let result ← liftRedisEIO RedisCmd.DEL (fun ctx => FFI.hiredis.del ctx (ks.map Codec.enc))
    return result.toNat
  existsKey := fun k => liftRedisEIO RedisCmd.EXISTS (fun ctx => FFI.hiredis.existsKey ctx (Codec.enc k))
  typeKey := fun k => do
    let typeString ← liftRedisEIO RedisCmd.TYPE (fun ctx => FFI.hiredis.typeKey ctx (Codec.enc k))
    return RedisValue.fromString typeString

  incr := fun k => do
    let result ← liftRedisEIO RedisCmd.INCR (fun ctx => FFI.hiredis.incr ctx (Codec.enc k))
    return Int.ofNat result.toNat
  incrBy := fun k n => do
    let result ← liftRedisEIO RedisCmd.INCRBY (fun ctx => FFI.hiredis.incrby ctx (Codec.enc k) (Int64.ofInt n))
    return Int.ofNat result.toNat
  decr := fun k => do
    let result ← liftRedisEIO RedisCmd.DECR (fun ctx => FFI.hiredis.decr ctx (Codec.enc k))
    return Int.ofNat result.toNat
  decrBy := fun k decrement => do
    let result ← liftRedisEIO RedisCmd.DECRBY (fun ctx => FFI.hiredis.decrby ctx (Codec.enc k) (Int64.ofInt decrement))
    return Int.ofNat result.toNat

  sismember := fun k member => liftRedisEIO RedisCmd.SISMEMBER (fun ctx => FFI.hiredis.sismember ctx (Codec.enc k) (Codec.enc member))
  scard := fun k => do
    let result ← liftRedisEIO RedisCmd.SCARD (fun ctx => FFI.hiredis.scard ctx (Codec.enc k))
    return result.toNat
  sadd := fun k member => do
    let result ← liftRedisEIO RedisCmd.SADD (fun ctx => FFI.hiredis.sadd ctx (Codec.enc k) (Codec.enc member))
    return result.toNat

  publish := fun {β} [Codec β] channel message => do
    let result ← liftRedisEIO RedisCmd.PUBLISH (fun ctx => FFI.hiredis.publish ctx channel (Codec.enc message))
    return result.toNat

  -- Redis Streams operations implementation
  xadd := fun {β} [Codec β] k stream_id field_values => do
    let encoded_fv := field_values.map (fun (f, v) => (Codec.enc f, Codec.enc v))
    let result ← liftRedisEIO RedisCmd.XADD (fun ctx => FFI.hiredis.xadd ctx (Codec.enc k) (String.toUTF8 stream_id) encoded_fv)
    match String.fromUTF8? result with
    | some str => return str
    | none => throw (RedisError.otherError "Invalid UTF-8 in XADD response")

  xread := fun streams count_opt block_opt => do
    let encoded_streams := streams.map (fun (stream, id) => (Codec.enc stream, String.toUTF8 id))
    let count_u64 := count_opt.map (fun n => UInt64.ofNat n)
    let block_u64 := block_opt.map (fun n => UInt64.ofNat n)
    liftRedisEIO RedisCmd.XREAD (fun ctx => FFI.hiredis.xread ctx encoded_streams count_u64 block_u64)

  xrange := fun k start_id end_id count_opt => do
    let count_u64 := count_opt.map (fun n => UInt64.ofNat n)
    liftRedisEIO RedisCmd.XRANGE (fun ctx => FFI.hiredis.xrange ctx (Codec.enc k) (String.toUTF8 start_id) (String.toUTF8 end_id) count_u64)

  xlen := fun k => do
    let result ← liftRedisEIO RedisCmd.XLEN (fun ctx => FFI.hiredis.xlen ctx (Codec.enc k))
    return result.toNat

  xdel := fun k entry_ids => do
    let encoded_ids := entry_ids.map String.toUTF8
    let result ← liftRedisEIO RedisCmd.XDEL (fun ctx => FFI.hiredis.xdel ctx (Codec.enc k) encoded_ids)
    return result.toNat

  xtrim := fun k strategy max_len => do
    let result ← liftRedisEIO RedisCmd.XTRIM (fun ctx => FFI.hiredis.xtrim ctx (Codec.enc k) (String.toUTF8 strategy) (UInt64.ofNat max_len))
    return result.toNat

  ping := fun msg => liftRedisEIO RedisCmd.PING (fun ctx => FFI.hiredis.ping ctx (Codec.enc msg))

-- Redis command operations

variable {α β : Type} [Codec α] [Codec β] [Ops α m]

-- Set a key-value pair
def set (k : α) (v : β) : m Unit := Ops.set k v
def setnx (k : α) (v : β) : m Unit := Ops.setnx k v
def setxx (k : α) (v : β) : m Unit := Ops.setxx k v

-- Set a key-value pair with expiration in milliseconds
def setex (k : α) (v : β) (msec : Nat) : m Unit := Ops.setex k v msec
def setexnx (k : α) (v : β) (msec : Nat) : m Unit := Ops.setexnx k v msec
def setexxx (k : α) (v : β) (msec : Nat) : m Unit := Ops.setexxx k v msec

-- Get a value by key
def get (k : α) : m ByteArray := Ops.get k

-- Get a value of type β by key
def getAs (β : Type) [Codec β] (k : α) : m β := Ops.getAs β k

-- Delete keys
def del (ks : List α) : m Nat := Ops.del ks

-- Check if a key exists
def existsKey (k : α) : m Bool := Ops.existsKey k

-- Get the type of a key
def typeKey (k : α) : m RedisValue := Ops.typeKey k

-- increment a numeric value at a key by 1
def incr (k : α) : m Int := Ops.incr k

-- increment a numeric value at a key by the given amount
def incrBy (k : α) (n : Int) : m Int := Ops.incrBy k n

-- decrement a numeric value at a key by 1
def decr (k : α) : m Int := Ops.decr k

-- decrement a numeric value at a key by the given amount
def decrBy (k : α) (n : Int) : m Int := Ops.decrBy k n

-- Check if a member exists in a set
def sismember (k : α) (member : α) : m Bool := Ops.sismember k member

-- Get the number of members in a set
def scard (k : α) : m Nat := Ops.scard k

-- Add a member to a set
def sadd (k : α) (member : α) : m Nat := Ops.sadd k member

-- Publish a message to a channel
def publish [inst : Ops α m] [Codec β] (channel : String) (message : β) : m Nat :=
  inst.publish channel message

-- Ping the Redis server
def ping (msg : α) : m Bool := Ops.ping msg

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

end RedisLean
