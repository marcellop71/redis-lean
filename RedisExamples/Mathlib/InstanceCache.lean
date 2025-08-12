import RedisLean.Mathlib
import RedisLean.Log
import RedisLean.Monad

namespace MathlibInstanceCacheExample

open Redis Redis.Mathlib

/-!
# Instance Resolution Cache Example

Demonstrates caching type class instance synthesis results.
This is useful for:
- Speeding up repeated instance resolution (expensive in large hierarchies)
- Sharing instance cache across compilation sessions
- Reducing elaboration time for complex type class queries
-/

/-- Simulate instance synthesis (in real usage, this would call Lean's synthesizer) -/
def simulateSynthesis (className targetType : String) : IO InstanceResult := do
  -- Simulate some computation time
  IO.sleep 5
  let now ← IO.monoNanosNow
  return {
    instanceExpr := .app (.const s!"inst_{className}" []) (.const targetType [])
    synthesizedAt := now / 1000000000
    isLocal := false
    moduleName := "Mathlib.Algebra.Group.Basic"
  }

/-- Example: Basic instance caching -/
def exBasicCaching : RedisM Unit := do
  Log.info "Example: Basic instance caching"

  let cache := InstanceCache.create "example" 3600  -- 1 hour TTL

  -- Create an instance key for Add Nat
  let key := InstanceKey.make "Add" (.const "Nat")
  Log.info s!"Looking up instance: Add Nat (hash: {key.keyHash})"

  -- First lookup - cache miss
  Log.info "First lookup (cache miss expected)..."
  let result1 ← cache.getOrSynthesize key (simulateSynthesis "Add" "Nat")
  Log.info s!"  Synthesized: {result1.instanceExpr.toEncodedString}"

  -- Second lookup - cache hit
  Log.info "Second lookup (cache hit expected)..."
  let result2 ← cache.getOrSynthesize key (simulateSynthesis "Add" "Nat")
  Log.info s!"  From cache: {result2.instanceExpr.toEncodedString}"

/-- Example: Multiple instances -/
def exMultipleInstances : RedisM Unit := do
  Log.info "Example: Caching multiple instances"

  let cache := InstanceCache.create "example" 3600

  -- Cache instances for different type classes and types
  let instances := [
    ("Add", "Nat"),
    ("Add", "Int"),
    ("Mul", "Nat"),
    ("Mul", "Int"),
    ("Monoid", "Nat"),
    ("Group", "Int"),
    ("Ring", "Int")
  ]

  for (className, targetType) in instances do
    let key := InstanceKey.make className (.const targetType)
    let _ ← cache.getOrSynthesize key (simulateSynthesis className targetType)
    Log.info s!"  Cached: {className} {targetType}"

  -- Check statistics
  let stats ← cache.getStats
  Log.info s!"Cache statistics:"
  Log.info s!"  Distinct classes: {stats.classCount}"
  Log.info s!"  Hits: {stats.hits}"
  Log.info s!"  Misses: {stats.misses}"

/-- Example: Cache invalidation by class -/
def exInvalidateClass : RedisM Unit := do
  Log.info "Example: Invalidating cache by class"

  let cache := InstanceCache.create "example" 3600

  -- Cache some Add instances
  let addNat := InstanceKey.make "Add" (.const "Nat")
  let addInt := InstanceKey.make "Add" (.const "Int")
  let mulNat := InstanceKey.make "Mul" (.const "Nat")

  let _ ← cache.getOrSynthesize addNat (simulateSynthesis "Add" "Nat")
  let _ ← cache.getOrSynthesize addInt (simulateSynthesis "Add" "Int")
  let _ ← cache.getOrSynthesize mulNat (simulateSynthesis "Mul" "Nat")

  Log.info "Cached instances for Add Nat, Add Int, Mul Nat"

  -- Invalidate all Add instances (e.g., after modifying Add class)
  let deleted ← cache.invalidateClass "Add"
  Log.info s!"Invalidated {deleted} Add instances"

  -- Mul should still be cached
  let mulResult ← cache.load mulNat
  match mulResult with
  | some _ => Log.info "Mul Nat still cached (as expected)"
  | none => Log.info "Mul Nat not found (unexpected)"

  -- Add should need re-synthesis
  let addResult ← cache.load addNat
  match addResult with
  | some _ => Log.info "Add Nat still cached (unexpected)"
  | none => Log.info "Add Nat invalidated (as expected)"

/-- Example: Cache invalidation by module -/
def exInvalidateModule : RedisM Unit := do
  Log.info "Example: Invalidating cache by module"

  let cache := InstanceCache.create "example" 3600

  -- Manually store instances from different modules
  let key1 := InstanceKey.make "Semiring" (.const "Nat")
  let instResult1 : InstanceResult := {
    instanceExpr := .const "Nat.instSemiring" []
    synthesizedAt := 0
    isLocal := false
    moduleName := "Mathlib.Algebra.Ring.Basic"
  }
  cache.store key1 instResult1

  let key2 := InstanceKey.make "Field" (.const "Rat")
  let instResult2 : InstanceResult := {
    instanceExpr := .const "Rat.instField" []
    synthesizedAt := 0
    isLocal := false
    moduleName := "Mathlib.Data.Rat.Basic"
  }
  cache.store key2 instResult2

  Log.info "Stored instances from Mathlib.Algebra.Ring.Basic and Mathlib.Data.Rat.Basic"

  -- Invalidate instances from Ring module
  let deleted ← cache.invalidateModule "Mathlib.Algebra.Ring.Basic"
  Log.info s!"Invalidated {deleted} instances from Mathlib.Algebra.Ring.Basic"

/-- Example: Local vs global instances -/
def exLocalInstances : RedisM Unit := do
  Log.info "Example: Local vs global instances"

  let cache := InstanceCache.create "example" 3600

  -- Store a global instance
  let globalKey := InstanceKey.make "Ord" (.const "String")
  let globalResult : InstanceResult := {
    instanceExpr := .const "String.instOrd" []
    synthesizedAt := 0
    isLocal := false
    moduleName := "Init.Data.String"
  }
  cache.store globalKey globalResult
  Log.info "Stored global instance: Ord String"

  -- Store a local instance (e.g., from a have statement)
  let localKey := InstanceKey.make "Decidable" (.const "CustomProp")
  let localResult : InstanceResult := {
    instanceExpr := .other "local_decidable_inst"
    synthesizedAt := 0
    isLocal := true
    moduleName := "MyProject.Custom"
  }
  cache.store localKey localResult
  Log.info "Stored local instance: Decidable CustomProp"

  -- Load and check
  let loaded ← cache.load localKey
  match loaded with
  | some r => Log.info s!"  Local instance: isLocal = {r.isLocal}"
  | none => Log.info "  Not found"

/-- Example: Reset statistics -/
def exResetStats : RedisM Unit := do
  Log.info "Example: Reset cache statistics"

  let cache := InstanceCache.create "example" 3600

  -- Generate some activity
  let key := InstanceKey.make "Test" (.const "Type")
  let _ ← cache.getOrSynthesize key (simulateSynthesis "Test" "Type")
  let _ ← cache.getOrSynthesize key (simulateSynthesis "Test" "Type")

  let statsBefore ← cache.getStats
  Log.info s!"Before reset: hits={statsBefore.hits}, misses={statsBefore.misses}"

  -- Reset statistics
  cache.resetStats
  Log.info "Statistics reset"

  let statsAfter ← cache.getStats
  Log.info s!"After reset: hits={statsAfter.hits}, misses={statsAfter.misses}"

/-- Run all instance cache examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Instance Cache Examples ==="
  exBasicCaching
  exMultipleInstances
  exInvalidateClass
  exInvalidateModule
  exLocalInstances
  exResetStats
  Log.info "=== Instance Cache Examples Complete ==="

end MathlibInstanceCacheExample
