import RedisLean.Mathlib
import RedisLean.Log
import RedisLean.Monad

namespace MathlibTacticCacheExample

open Redis Redis.Mathlib

/-!
# Tactic Cache Example

Demonstrates caching elaboration results to speed up repeated tactic applications.
This is useful for:
- Caching expensive tactic elaborations during proof development
- Sharing cached results across multiple Lean sessions
- Reducing compilation time for large Mathlib projects
-/

/-- Simulate an expensive elaboration computation -/
def simulateElaboration (syntaxHash : UInt64) : IO ElabResult := do
  -- In real usage, this would be actual Lean elaboration
  IO.sleep 10  -- Simulate computation time
  let now ← IO.monoNanosNow
  return {
    expr := .const s!"elaborated_{syntaxHash}" []
    typeHash := syntaxHash * 17
    cachedAt := now / 1000000000
    moduleName := "Example.Tactics"
  }

/-- Example: Basic store and load operations -/
def exBasicCaching : RedisM Unit := do
  Log.info "Example: Basic tactic caching"

  let cache := TacticCache.create "example" 3600  -- 1 hour TTL

  -- Simulate a syntax hash (in real usage, use hashSyntax)
  let syntaxHash : UInt64 := 12345678

  -- First access: cache miss, need to elaborate
  Log.info s!"First access for hash {syntaxHash}..."
  let result1 ← cache.getOrElaborate syntaxHash (simulateElaboration syntaxHash)
  Log.info s!"  Result: {result1.expr.toEncodedString}"

  -- Second access: cache hit, instant
  Log.info s!"Second access for hash {syntaxHash}..."
  let result2 ← cache.getOrElaborate syntaxHash (simulateElaboration syntaxHash)
  Log.info s!"  Result: {result2.expr.toEncodedString}"
  Log.info s!"  (Retrieved from cache - no computation needed)"

/-- Example: Cache statistics -/
def exCacheStats : RedisM Unit := do
  Log.info "Example: Cache statistics"

  let cache := TacticCache.create "example" 3600

  -- Generate some cache activity
  for i in [0:5] do
    let hash := UInt64.ofNat (1000 + i)
    let _ ← cache.getOrElaborate hash (simulateElaboration hash)

  -- Access some cached entries again (hits)
  for i in [0:3] do
    let hash := UInt64.ofNat (1000 + i)
    let _ ← cache.getOrElaborate hash (simulateElaboration hash)

  -- Get and display statistics
  let stats ← cache.getStats
  Log.info s!"Cache Statistics:"
  Log.info s!"  Hits: {stats.hits}"
  Log.info s!"  Misses: {stats.misses}"
  Log.info s!"  Hit Rate: {TacticCache.hitRate stats}%"

/-- Example: Module-based invalidation -/
def exModuleInvalidation : RedisM Unit := do
  Log.info "Example: Module-based cache invalidation"

  let cache := TacticCache.create "example" 3600

  -- Cache some results from different modules
  let moduleA := "MyProject.ModuleA"
  let moduleB := "MyProject.ModuleB"

  -- Store results for ModuleA
  for i in [0:3] do
    let hash := UInt64.ofNat (2000 + i)
    let result : ElabResult := {
      expr := .const s!"resultA_{i}" []
      typeHash := hash
      cachedAt := 0
      moduleName := moduleA
    }
    cache.store hash result
  Log.info s!"Stored 3 cache entries for {moduleA}"

  -- Store results for ModuleB
  for i in [0:2] do
    let hash := UInt64.ofNat (3000 + i)
    let result : ElabResult := {
      expr := .const s!"resultB_{i}" []
      typeHash := hash
      cachedAt := 0
      moduleName := moduleB
    }
    cache.store hash result
  Log.info s!"Stored 2 cache entries for {moduleB}"

  -- Invalidate ModuleA (e.g., after editing)
  let deleted ← cache.invalidateModule moduleA
  Log.info s!"Invalidated {deleted} cache entries for {moduleA}"

  -- ModuleB entries should still be cached
  let resultB ← cache.load (UInt64.ofNat 3000)
  match resultB with
  | some r => Log.info s!"ModuleB entry still cached: {r.expr.toEncodedString}"
  | none => Log.info "ModuleB entry not found (unexpected)"

/-- Run all tactic cache examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Tactic Cache Examples ==="
  exBasicCaching
  exCacheStats
  exModuleInvalidation
  Log.info "=== Tactic Cache Examples Complete ==="

end MathlibTacticCacheExample
