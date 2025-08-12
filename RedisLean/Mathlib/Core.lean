import Lean.Expr
import Lean.Data.Json
import RedisLean.Codec
import RedisLean.Error
import RedisLean.Monad
import RedisLean.Ops
import RedisLean.Expr

namespace Redis.Mathlib

/-!
# Core Types and Utilities for Mathlib Integration

This module provides shared types, key naming conventions, and serialization
utilities used across all Mathlib integration features.
-/

open Redis

/-- TypePattern: A pattern for matching Lean types in theorem search.
    More flexible than SimpleExpr for pattern matching. -/
inductive TypePattern where
  | const (name : String)
  | app (fn : TypePattern) (arg : TypePattern)
  | arrow (dom : TypePattern) (cod : TypePattern)
  | forallE (name : String) (body : TypePattern)
  | var (idx : Nat)
  | any  -- Wildcard for matching anything
  deriving Repr, BEq, Inhabited

namespace TypePattern

/-- Convert TypePattern to a string for storage -/
partial def toEncodedString : TypePattern → String
  | .const name => s!"C[{name}]"
  | .app fn arg => s!"A({toEncodedString fn})({toEncodedString arg})"
  | .arrow dom cod => s!"→({toEncodedString dom})({toEncodedString cod})"
  | .forallE name body => s!"∀[{name}]({toEncodedString body})"
  | .var idx => s!"V{idx}"
  | .any => "_"

/-- Hash a TypePattern for indexing -/
partial def hash : TypePattern → UInt64
  | .const name => name.hash
  | .app fn arg => mixHash (hash fn) (hash arg)
  | .arrow dom cod => mixHash (mixHash 0x1234567890abcdef (hash dom)) (hash cod)
  | .forallE name body => mixHash name.hash (hash body)
  | .var idx => UInt64.ofNat idx
  | .any => 0
where
  mixHash (h1 h2 : UInt64) : UInt64 := h1 ^^^ (h2 * 0x9e3779b97f4a7c15)

/-- Check if a TypePattern matches another (with wildcard support) -/
partial def matchesPattern (pattern target : TypePattern) : Bool :=
  match pattern, target with
  | .any, _ => true
  | .const n1, .const n2 => n1 == n2
  | .app f1 a1, .app f2 a2 => matchesPattern f1 f2 && matchesPattern a1 a2
  | .arrow d1 c1, .arrow d2 c2 => matchesPattern d1 d2 && matchesPattern c1 c2
  | .forallE _ b1, .forallE _ b2 => matchesPattern b1 b2
  | .var i1, .var i2 => i1 == i2
  | _, _ => false

/-- Alias for matchesPattern -/
def «matches» := matchesPattern

/-- Convert SimpleExpr to TypePattern -/
partial def fromSimpleExpr : SimpleExpr → TypePattern
  | .const name _ => .const name
  | .app fn arg => .app (fromSimpleExpr fn) (fromSimpleExpr arg)
  | .forallE name type body =>
    if isArrow type body then
      .arrow (fromSimpleExpr type) (fromSimpleExpr body)
    else
      .forallE name (fromSimpleExpr body)
  | .bvar idx => .var idx
  | _ => .any
where
  isArrow (_type body : SimpleExpr) : Bool :=
    -- Simple heuristic: if body doesn't reference the bound var, it's an arrow
    not (hasVar 0 body)
  hasVar (idx : Nat) : SimpleExpr → Bool
    | .bvar i => i == idx
    | .app fn arg => hasVar idx fn || hasVar idx arg
    | .lam _ t b => hasVar idx t || hasVar (idx + 1) b
    | .forallE _ t b => hasVar idx t || hasVar (idx + 1) b
    | .letE _ t v b => hasVar idx t || hasVar idx v || hasVar (idx + 1) b
    | .proj _ _ s => hasVar idx s
    | _ => false

end TypePattern

instance : Lean.ToJson TypePattern where
  toJson p := Lean.Json.str p.toEncodedString

instance : Lean.FromJson TypePattern where
  fromJson? j := do
    let s ← j.getStr?
    -- Simple parsing - for complex patterns, store as encoded string
    return .const s  -- Simplified; full parser would be more complex

instance : Codec TypePattern where
  enc p := String.toUTF8 p.toEncodedString
  dec bs := match String.fromUTF8? bs with
    | some s => .ok (.const s)  -- Simplified decoding
    | none => .error "Invalid UTF-8 in TypePattern"

-- ========== Key Naming Conventions ==========

/-- Build a tactic cache key -/
def tacticKey (keyPrefix : String) (hash : UInt64) : String :=
  s!"{keyPrefix}:tactic:{hash}"

/-- Build a tactic stats key -/
def tacticStatsKey (keyPrefix : String) (stat : String) : String :=
  s!"{keyPrefix}:tactic:stats:{stat}"

/-- Build a theorem index key by conclusion type -/
def theoremConclusionKey (keyPrefix : String) (typeHash : UInt64) : String :=
  s!"{keyPrefix}:thm:index:concl:{typeHash}"

/-- Build a theorem index key by hypothesis type -/
def theoremHypothesisKey (keyPrefix : String) (typeHash : UInt64) : String :=
  s!"{keyPrefix}:thm:index:hyp:{typeHash}"

/-- Build a theorem name key -/
def theoremNameKey (keyPrefix : String) (name : String) : String :=
  s!"{keyPrefix}:thm:name:{name}"

/-- Build a declaration key -/
def declKey (keyPrefix : String) (name : String) : String :=
  s!"{keyPrefix}:decl:{name}"

/-- Build a declaration dependencies key -/
def declDepsKey (keyPrefix : String) (name : String) : String :=
  s!"{keyPrefix}:decl:deps:{name}"

/-- Build an environment snapshot key -/
def envSnapshotKey (keyPrefix : String) (id : String) : String :=
  s!"{keyPrefix}:env:snapshot:{id}"

/-- Build an instance cache key -/
def instanceCacheKey (keyPrefix : String) (classHash typeHash : UInt64) : String :=
  s!"{keyPrefix}:instance:{classHash}:{typeHash}"

/-- Build a proof session key -/
def proofSessionKey (keyPrefix : String) (sessionId : String) : String :=
  s!"{keyPrefix}:proof:session:{sessionId}"

/-- Build a proof step key -/
def proofStepKey (keyPrefix : String) (sessionId : String) (step : Nat) : String :=
  s!"{keyPrefix}:proof:step:{sessionId}:{step}"

/-- Build a proof trace key -/
def proofTraceKey (keyPrefix : String) (sessionId : String) : String :=
  s!"{keyPrefix}:proof:trace:{sessionId}"

/-- Build a distributed jobs queue key -/
def distJobsKey (keyPrefix : String) : String :=
  s!"{keyPrefix}:dist:jobs"

/-- Build a distributed lock key -/
def distLockKey (keyPrefix : String) (moduleName : String) : String :=
  s!"{keyPrefix}:dist:lock:{moduleName}"

/-- Build a distributed complete set key -/
def distCompleteKey (keyPrefix : String) : String :=
  s!"{keyPrefix}:dist:complete"

/-- Build a distributed progress key -/
def distProgressKey (keyPrefix : String) : String :=
  s!"{keyPrefix}:dist:progress"

/-- Build a distributed job status key -/
def distJobStatusKey (keyPrefix : String) (jobId : String) : String :=
  s!"{keyPrefix}:dist:job:{jobId}"

/-- Build a distributed worker key -/
def distWorkerKey (keyPrefix : String) (workerId : String) : String :=
  s!"{keyPrefix}:dist:worker:{workerId}"

-- ========== Hash Utilities ==========

/-- Hash a Lean.Syntax for tactic caching -/
def hashSyntax (stx : Lean.Syntax) : UInt64 :=
  stx.formatStx.pretty.hash

/-- Hash a Lean.Name -/
def hashName (n : Lean.Name) : UInt64 :=
  n.toString.hash

-- ========== JSON Codec Helper ==========

/-- Helper to convert Option to Except -/
def optionToExcept (o : Option α) (err : String) : Except String α :=
  match o with
  | some a => .ok a
  | none => .error err

/-- Helper to convert Except to Except (identity, but explicit) -/
def exceptToExcept (e : Except String α) : Except String α := e

/-- Create a codec from JSON instances -/
def jsonCodec [Lean.ToJson α] [Lean.FromJson α] : Codec α where
  enc a := String.toUTF8 (Lean.toJson a).compress
  dec bs := do
    let str ← optionToExcept (String.fromUTF8? bs) "Invalid UTF-8"
    let json ← exceptToExcept (Lean.Json.parse str)
    exceptToExcept (Lean.fromJson? json)

-- ========== Utility Functions ==========

/-- Generate a unique ID based on timestamp and random component -/
def generateId : IO String := do
  let time ← IO.monoNanosNow
  let rand ← IO.rand 0 0xFFFFFFFF
  return s!"{time}-{rand}"

/-- Get current timestamp in nanoseconds -/
def nowNanos : IO Nat := IO.monoNanosNow

/-- Get current timestamp in seconds -/
def nowSeconds : IO Nat := do
  let nanos ← IO.monoNanosNow
  return nanos / 1000000000

/-- Check if a string contains a substring -/
def containsSubstr (s : String) (sub : String) : Bool :=
  if sub.isEmpty then true
  else
    let sLen := s.length
    let subLen := sub.length
    if subLen > sLen then false
    else
      (List.range (sLen - subLen + 1)).any fun i =>
        (s.drop i).take subLen == sub

/-- Drop prefix from a string and convert to String -/
def dropPrefix (s : String) (n : Nat) : String :=
  (s.drop n).toString

end Redis.Mathlib
