import RedisLean.Codec
import RedisLean.Error
import RedisLean.Monad
import RedisLean.Ops

namespace Redis

/-- Phantom-typed key that prevents mixing keys of different value types.
    The type parameter `α` represents the type of value stored at this key. -/
structure TypedKey (α : Type) where
  key : String
  deriving Repr, BEq, Hashable

namespace TypedKey

/-- Get the underlying key string -/
def toString (tk : TypedKey α) : String := tk.key

instance : ToString (TypedKey α) where
  toString := TypedKey.toString

/-- Codec instance for TypedKey - encodes as the underlying string -/
instance : Codec (TypedKey α) where
  enc tk := String.toUTF8 tk.key
  dec bs := match String.fromUTF8? bs with
    | some s => .ok ⟨s⟩
    | none => .error "Invalid UTF-8 in TypedKey"

end TypedKey

/-- Set a value at a typed key -/
def typedSet [Codec α] (tk : TypedKey α) (value : α) : RedisM Unit :=
  set tk.key (Codec.enc value)

/-- Get a value from a typed key -/
def typedGet [Codec α] (tk : TypedKey α) : RedisM (Option α) := do
  let keyExists ← existsKey tk.key
  if !keyExists then return none
  else
    let bs ← get tk.key
    match Codec.dec bs with
    | .ok v => return some v
    | .error msg => throw (.otherError s!"Decode failed: {msg}")

/-- Set a value at a typed key with expiration in seconds -/
def typedSetex [Codec α] (tk : TypedKey α) (value : α) (seconds : Nat) : RedisM Unit :=
  setex tk.key (Codec.enc value) seconds

/-- Delete typed keys -/
def typedDel (tks : List (TypedKey α)) : RedisM Nat :=
  del (tks.map TypedKey.key)

/-- Check if a typed key exists -/
def typedExists (tk : TypedKey α) : RedisM Bool :=
  existsKey tk.key

/-- Get TTL for a typed key -/
def typedTtl (tk : TypedKey α) : RedisM Nat :=
  ttl tk.key

/-- Set expiration on a typed key -/
def typedExpire (tk : TypedKey α) (seconds : Nat) : RedisM Bool :=
  expire tk.key seconds

/-- Namespace for organizing keys with a common prefix -/
structure Namespace where
  nsPrefix : String
  deriving Repr, BEq

namespace Namespace

/-- Create a namespace from a prefix string -/
def create (nsPrefix : String) : Namespace := ⟨nsPrefix⟩

/-- Create a typed key within this namespace -/
def key (ns : Namespace) (name : String) : TypedKey α :=
  ⟨s!"{ns.nsPrefix}:{name}"⟩

/-- Create a nested namespace -/
def nested (ns : Namespace) (subPrefix : String) : Namespace :=
  ⟨s!"{ns.nsPrefix}:{subPrefix}"⟩

/-- Get all keys matching a pattern in this namespace -/
def keysMatching (ns : Namespace) (pattern : String) : RedisM (List ByteArray) :=
  keys (α := String) (String.toUTF8 s!"{ns.nsPrefix}:{pattern}")

/-- Delete all keys in this namespace (matching pattern *) -/
def clear (ns : Namespace) : RedisM Nat := do
  let ks ← ns.keysMatching "*"
  if ks.isEmpty then return 0
  let keyStrs := ks.filterMap (fun bs => String.fromUTF8? bs)
  del keyStrs

end Namespace

/-- A typed hash field for type-safe hash operations -/
structure TypedHashField (α : Type) where
  field : String
  deriving Repr, BEq, Hashable

namespace TypedHashField

def create (field : String) : TypedHashField α := ⟨field⟩

instance : Codec (TypedHashField α) where
  enc tf := String.toUTF8 tf.field
  dec bs := match String.fromUTF8? bs with
    | some s => .ok ⟨s⟩
    | none => .error "Invalid UTF-8 in TypedHashField"

end TypedHashField

/-- Type-safe hash set operation -/
def typedHset [Codec α] (key : String) (field : TypedHashField α) (value : α) : RedisM Nat :=
  hset key field.field (Codec.enc value)

/-- Type-safe hash get operation -/
def typedHget [Codec α] (key : String) (field : TypedHashField α) : RedisM (Option α) := do
  let fieldExists ← hexists key field.field
  if !fieldExists then return none
  else
    let bs ← hget key field.field
    match Codec.dec bs with
    | .ok v => return some v
    | .error msg => throw (.otherError s!"Hash decode failed: {msg}")

end Redis
