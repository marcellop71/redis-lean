import Lean.Expr
import RedisLean.Codec
import RedisLean.Error
import RedisLean.Monad
import RedisLean.Ops

namespace Redis

/-!
# Experimental: Support for storing Lean Expr values in Redis.

WARNING: This module is experimental and has limitations:
- Expr serialization requires an Environment for full fidelity
- Cross-session Expr values may not be compatible
- Large expressions may be slow to serialize/deserialize

This is primarily useful for:
- Caching compiled expressions
- Sharing expressions between Lean processes with the same environment
- Debugging and introspection
-/

/-- Simple Expr representation for serialization.
    This captures the basic structure but not all metadata. -/
inductive SimpleExpr where
  | bvar (idx : Nat)
  | fvar (id : UInt64)
  | mvar (id : UInt64)
  | sort (level : Nat)
  | const (name : String) (levels : List Nat)
  | app (fn : SimpleExpr) (arg : SimpleExpr)
  | lam (name : String) (type : SimpleExpr) (body : SimpleExpr)
  | forallE (name : String) (type : SimpleExpr) (body : SimpleExpr)
  | letE (name : String) (type : SimpleExpr) (value : SimpleExpr) (body : SimpleExpr)
  | lit (value : String)
  | proj (typeName : String) (idx : Nat) (struct : SimpleExpr)
  | other (description : String)
  deriving Repr, BEq, Inhabited

namespace SimpleExpr

private def levelToNat : Lean.Level → Nat
  | .zero => 0
  | .succ l => levelToNat l + 1
  | .mvar _ => 0
  | .param _ => 0
  | .max l1 l2 => max (levelToNat l1) (levelToNat l2)
  | .imax l1 l2 => max (levelToNat l1) (levelToNat l2)

/-- Convert a Lean.Expr to SimpleExpr (lossy conversion) -/
partial def fromExpr (e : Lean.Expr) : SimpleExpr :=
  match e with
  | .bvar idx => .bvar idx
  | .fvar id => .fvar id.name.hash
  | .mvar id => .mvar id.name.hash
  | .sort level => .sort (levelToNat level)
  | .const name levels => .const name.toString (levels.map levelToNat)
  | .app fn arg => .app (fromExpr fn) (fromExpr arg)
  | .lam name type body _ => .lam name.toString (fromExpr type) (fromExpr body)
  | .forallE name type body _ => .forallE name.toString (fromExpr type) (fromExpr body)
  | .letE name type value body _ => .letE name.toString (fromExpr type) (fromExpr value) (fromExpr body)
  | .lit (.natVal n) => .lit s!"nat:{n}"
  | .lit (.strVal s) => .lit s!"str:{s}"
  | .mdata _ expr => fromExpr expr
  | .proj typeName idx struct => .proj typeName.toString idx (fromExpr struct)

/-- Convert SimpleExpr to string representation -/
partial def toEncodedString : SimpleExpr → String
  | .bvar idx => s!"B{idx}"
  | .fvar id => s!"F{id}"
  | .mvar id => s!"M{id}"
  | .sort level => s!"S{level}"
  | .const name levels => s!"C[{name}]{levels}"
  | .app fn arg => s!"A({toEncodedString fn})({toEncodedString arg})"
  | .lam name type body => s!"L[{name}]({toEncodedString type})({toEncodedString body})"
  | .forallE name type body => s!"P[{name}]({toEncodedString type})({toEncodedString body})"
  | .letE name type value body => s!"E[{name}]({toEncodedString type})({toEncodedString value})({toEncodedString body})"
  | .lit value => s!"I[{value}]"
  | .proj typeName idx struct => s!"R[{typeName}:{idx}]({toEncodedString struct})"
  | .other desc => s!"O[{desc}]"

/-- Encode SimpleExpr to bytes using a simple format -/
def encode (e : SimpleExpr) : ByteArray :=
  String.toUTF8 (toEncodedString e)

/-- Decode bytes to SimpleExpr (basic parsing, may fail on complex expressions) -/
def decode (bs : ByteArray) : Except String SimpleExpr :=
  match String.fromUTF8? bs with
  | none => .error "Invalid UTF-8 in SimpleExpr"
  | some s => parseSimple s
where
  parseSimple (s : String) : Except String SimpleExpr :=
    if s.startsWith "B" then
      match (s.drop 1).toNat? with
      | some n => .ok (.bvar n)
      | none => .error "Invalid bvar index"
    else if s.startsWith "S" then
      match (s.drop 1).toNat? with
      | some n => .ok (.sort n)
      | none => .error "Invalid sort level"
    else if s.startsWith "O[" && s.endsWith "]" then
      let content := (s.drop 2).dropEnd 1 |>.toString
      .ok (.other content)
    else
      -- For complex expressions, return as "other" with the raw string
      .ok (.other s)

end SimpleExpr

/-- Codec instance for SimpleExpr -/
instance : Codec SimpleExpr where
  enc := SimpleExpr.encode
  dec := SimpleExpr.decode

/-- Store an expression in Redis (converts to SimpleExpr) -/
def storeExpr (key : String) (e : Lean.Expr) : RedisM Unit := do
  let simple := SimpleExpr.fromExpr e
  set key (Codec.enc simple)

/-- Store an expression with TTL -/
def storeExprEx (key : String) (e : Lean.Expr) (ttlSeconds : Nat) : RedisM Unit := do
  let simple := SimpleExpr.fromExpr e
  setex key (Codec.enc simple) ttlSeconds

/-- Load a SimpleExpr from Redis -/
def loadExpr (key : String) : RedisM (Option SimpleExpr) := do
  let keyExists ← existsKey key
  if !keyExists then return none
  let bs ← get key
  match Codec.dec bs with
  | .ok e => return some e
  | .error msg => throw (.otherError s!"Failed to decode expr: {msg}")

/-- Expression cache for memoizing computations involving expressions -/
structure ExprCache where
  cachePrefix : String
  ttlSeconds : Nat

namespace ExprCache

/-- Create a new expression cache -/
def create (cachePrefix : String) (ttlSeconds : Nat := 3600) : ExprCache :=
  { cachePrefix, ttlSeconds }

/-- Generate cache key for an expression -/
def cacheKey (cache : ExprCache) (name : String) : String :=
  s!"{cache.cachePrefix}:expr:{name}"

/-- Store an expression in the cache -/
def store (cache : ExprCache) (name : String) (e : Lean.Expr) : RedisM Unit :=
  storeExprEx (cache.cacheKey name) e cache.ttlSeconds

/-- Load an expression from the cache -/
def load (cache : ExprCache) (name : String) : RedisM (Option SimpleExpr) :=
  loadExpr (cache.cacheKey name)

/-- Invalidate a cached expression -/
def invalidate (cache : ExprCache) (name : String) : RedisM Nat :=
  del [cache.cacheKey name]

/-- Clear all cached expressions -/
def clear (cache : ExprCache) : RedisM Nat := do
  let pattern := s!"{cache.cachePrefix}:expr:*"
  let ks ← keys (α := String) (String.toUTF8 pattern)
  if ks.isEmpty then return 0
  let keyStrs := ks.filterMap (fun bs => String.fromUTF8? bs)
  del keyStrs

end ExprCache

/-- Metadata for stored expressions -/
structure ExprMetadata where
  /-- When the expression was stored -/
  storedAt : Nat
  /-- Size of the serialized expression in bytes -/
  sizeBytes : Nat
  /-- Original expression type (if known) -/
  exprType : Option String
  /-- Custom tags -/
  tags : List String
  deriving Repr, BEq

/-- Codec for ExprMetadata -/
instance : Codec ExprMetadata where
  enc m := String.toUTF8 s!"{m.storedAt}|{m.sizeBytes}|{m.exprType.getD ""}|{String.intercalate "," m.tags}"
  dec bs := match String.fromUTF8? bs with
    | none => .error "Invalid UTF-8 in ExprMetadata"
    | some s =>
      let parts := s.splitOn "|"
      if parts.length >= 4 then
        let storedAt := parts[0]!.toNat?.getD 0
        let sizeBytes := parts[1]!.toNat?.getD 0
        let exprType := if parts[2]!.isEmpty then none else some parts[2]!
        let tags := if parts[3]!.isEmpty then [] else parts[3]!.splitOn ","
        .ok { storedAt, sizeBytes, exprType, tags }
      else
        .error "Invalid ExprMetadata format"

/-- Store expression with metadata -/
def storeExprWithMetadata (key : String) (e : Lean.Expr) (exprType : Option String := none) (tags : List String := []) : RedisM Unit := do
  let simple := SimpleExpr.fromExpr e
  let encoded := Codec.enc simple
  let now ← IO.monoNanosNow
  let metadata : ExprMetadata := {
    storedAt := now,
    sizeBytes := encoded.size,
    exprType,
    tags
  }
  set key encoded
  set (key ++ ":meta") (Codec.enc metadata)

/-- Load expression with metadata -/
def loadExprWithMetadata (key : String) : RedisM (Option (SimpleExpr × ExprMetadata)) := do
  let keyExists ← existsKey key
  if !keyExists then return none
  let bs ← get key
  let metaBs ← get (key ++ ":meta")
  match Codec.dec bs, Codec.dec metaBs with
  | .ok e, .ok m => return some (e, m)
  | .ok e, .error _ =>
    -- Return expression with default metadata if metadata is missing
    let defaultMeta : ExprMetadata := { storedAt := 0, sizeBytes := bs.size, exprType := none, tags := [] }
    return some (e, defaultMeta)
  | .error msg, _ => throw (.otherError s!"Failed to decode expr: {msg}")

end Redis
