import RedisLean.Mathlib.Core

namespace Redis.Mathlib

/-!
# Instance Resolution Cache for Lean/Mathlib

Caches type class instance synthesis results to avoid repeated resolution
of the same instances across sessions.
-/

open Redis

/-- Key identifying an instance synthesis query -/
structure InstanceKey where
  /-- Name of the type class -/
  className : String
  /-- Target type pattern -/
  targetType : TypePattern
  /-- Combined hash for quick lookup -/
  keyHash : UInt64
  deriving Repr, BEq

namespace InstanceKey

/-- Create an instance key from class name and target type -/
def make (className : String) (targetType : TypePattern) : InstanceKey :=
  let classHash := className.hash
  let typeHash := targetType.hash
  let combined := classHash ^^^ (typeHash * 0x9e3779b97f4a7c15)
  { className, targetType, keyHash := combined }

end InstanceKey

/-- Result of instance synthesis -/
structure InstanceResult where
  /-- The synthesized instance expression -/
  instanceExpr : SimpleExpr
  /-- When the instance was synthesized -/
  synthesizedAt : Nat
  /-- Whether this is a local instance -/
  isLocal : Bool
  /-- Module where synthesized -/
  moduleName : String
  deriving Repr, BEq, Inhabited

instance : Lean.ToJson InstanceResult where
  toJson r := Lean.Json.mkObj [
    ("instanceExpr", Lean.toJson r.instanceExpr.toEncodedString),
    ("synthesizedAt", Lean.toJson r.synthesizedAt),
    ("isLocal", Lean.toJson r.isLocal),
    ("moduleName", Lean.toJson r.moduleName)
  ]

instance : Lean.FromJson InstanceResult where
  fromJson? j := do
    let exprStr ← j.getObjValAs? String "instanceExpr"
    let synthesizedAt ← j.getObjValAs? Nat "synthesizedAt"
    let isLocal ← j.getObjValAs? Bool "isLocal"
    let moduleName ← j.getObjValAs? String "moduleName"
    return {
      instanceExpr := .other exprStr
      synthesizedAt
      isLocal
      moduleName
    }

instance : Codec InstanceResult := jsonCodec

/-- Statistics for instance cache -/
structure InstanceStats where
  hits : Nat
  misses : Nat
  classCount : Nat  -- Number of distinct classes cached
  deriving Repr, BEq

/-- Configuration for instance caching -/
structure InstanceCache where
  /-- Prefix for all cache keys -/
  keyPrefix : String := "mathlib"
  /-- Time-to-live in seconds -/
  ttlSeconds : Nat := 7200
  /-- Whether to track statistics -/
  enableStats : Bool := true
  deriving Repr

namespace InstanceCache

/-- Create a new instance cache -/
def create (kPrefix : String := "mathlib") (ttl : Nat := 7200) : InstanceCache :=
  { keyPrefix := kPrefix, ttlSeconds := ttl, enableStats := true }

/-- Get the Redis key for an instance -/
def cacheKey (cache : InstanceCache) (ik : InstanceKey) : String :=
  instanceCacheKey cache.keyPrefix ik.className.hash ik.keyHash

/-- Store an instance result -/
def store (cache : InstanceCache) (ik : InstanceKey) (result : InstanceResult) : RedisM Unit := do
  let k := cache.cacheKey ik
  setex k (Codec.enc result) cache.ttlSeconds
  -- Track class in a set for statistics
  if cache.enableStats then
    let _ ← sadd s!"{cache.keyPrefix}:instance:classes" ik.className

/-- Load a cached instance result -/
def load (cache : InstanceCache) (ik : InstanceKey) : RedisM (Option InstanceResult) := do
  let k := cache.cacheKey ik
  let keyExists ← existsKey k
  if !keyExists then
    if cache.enableStats then
      let _ ← incr s!"{cache.keyPrefix}:instance:stats:misses"
    return none
  let bs ← get k
  match Codec.dec bs with
  | .ok result =>
    if cache.enableStats then
      let _ ← incr s!"{cache.keyPrefix}:instance:stats:hits"
    return some result
  | .error _ =>
    if cache.enableStats then
      let _ ← incr s!"{cache.keyPrefix}:instance:stats:misses"
    return none

/-- Get cached instance or synthesize it -/
def getOrSynthesize (cache : InstanceCache) (ik : InstanceKey) (synthesize : IO InstanceResult) : RedisM InstanceResult := do
  match ← cache.load ik with
  | some result => return result
  | none =>
    let result ← synthesize
    cache.store ik result
    return result

/-- Invalidate all instances for a class -/
def invalidateClass (cache : InstanceCache) (className : String) : RedisM Nat := do
  let pattern := s!"{cache.keyPrefix}:instance:{className.hash}:*"
  let allKeys ← keys (α := String) (String.toUTF8 pattern)
  if allKeys.isEmpty then return 0
  let keyStrs := allKeys.filterMap String.fromUTF8?
  del keyStrs

/-- Invalidate all instances from a module -/
def invalidateModule (cache : InstanceCache) (moduleName : String) : RedisM Nat := do
  let pattern := s!"{cache.keyPrefix}:instance:*"
  let allKeys ← keys (α := String) (String.toUTF8 pattern)
  let keyStrs := allKeys.filterMap String.fromUTF8?
  let mut deleted := 0
  for k in keyStrs do
    if containsSubstr k "stats" || containsSubstr k "classes" then continue
    let keyExists ← existsKey k
    if keyExists then
      let bs ← get k
      match Codec.dec (α := InstanceResult) bs with
      | .ok result =>
        if result.moduleName == moduleName then
          let _ ← del [k]
          deleted := deleted + 1
      | .error _ => pure ()
  return deleted

/-- Clear the entire instance cache -/
def clear (cache : InstanceCache) : RedisM Nat := do
  let pattern := s!"{cache.keyPrefix}:instance:*"
  let allKeys ← keys (α := String) (String.toUTF8 pattern)
  if allKeys.isEmpty then return 0
  let keyStrs := allKeys.filterMap String.fromUTF8?
  del keyStrs

/-- Get cache statistics -/
def getStats (cache : InstanceCache) : RedisM InstanceStats := do
  let hitsKey := s!"{cache.keyPrefix}:instance:stats:hits"
  let missesKey := s!"{cache.keyPrefix}:instance:stats:misses"
  let classesKey := s!"{cache.keyPrefix}:instance:classes"

  let hits ← do
    let keyExists ← existsKey hitsKey
    if keyExists then do
      let bs ← get hitsKey
      pure (String.fromUTF8? bs |>.bind (·.toNat?) |>.getD 0)
    else pure 0

  let misses ← do
    let keyExists ← existsKey missesKey
    if keyExists then do
      let bs ← get missesKey
      pure (String.fromUTF8? bs |>.bind (·.toNat?) |>.getD 0)
    else pure 0

  let classCount ← scard classesKey

  return { hits, misses, classCount }

/-- Reset statistics -/
def resetStats (cache : InstanceCache) : RedisM Unit := do
  let _ ← del [
    s!"{cache.keyPrefix}:instance:stats:hits",
    s!"{cache.keyPrefix}:instance:stats:misses"
  ]

end InstanceCache

end Redis.Mathlib
