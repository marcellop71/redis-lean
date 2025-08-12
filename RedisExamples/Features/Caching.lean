import RedisLean.Cache
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesCachingExample

open Redis

/-!
# Caching Patterns Examples

Demonstrates various caching patterns provided by redis-lean:
- Memoization (automatic function result caching)
- Cache-aside (lazy loading)
- Write-through (synchronous write)
- Write-behind (asynchronous write)
- Stampede prevention with distributed locks
-/

/-- Simulated slow computation -/
def slowComputation (n : Nat) : IO Nat := do
  IO.sleep 10  -- Simulate work
  return n * n

/-- Simulated database read -/
def fetchFromDatabase (userId : String) : IO String := do
  IO.sleep 5  -- Simulate database latency
  return s!"User data for {userId}"

/-- Simulated database write -/
def writeToDatabase (_userId : String) (data : String) : IO Unit := do
  IO.sleep 5  -- Simulate database latency
  IO.println s!"  [DB] Wrote: {data}"

/-- Example: Memoization pattern -/
def exMemoization : RedisM Unit := do
  Log.info "Example: Memoization pattern"

  -- First call - cache miss, computes result
  Log.info "First call (cache miss expected)..."
  let result1 ← memoize "memoize:square:5" 60 (slowComputation 5)
  Log.info s!"  Result: {result1}"

  -- Second call - cache hit, returns cached result
  Log.info "Second call (cache hit expected)..."
  let result2 ← memoize "memoize:square:5" 60 (slowComputation 5)
  Log.info s!"  Result: {result2}"

  -- Different key - cache miss
  Log.info "Different key (cache miss expected)..."
  let result3 ← memoize "memoize:square:10" 60 (slowComputation 10)
  Log.info s!"  Result: {result3}"

  -- Cleanup
  let _ ← invalidate "memoize:square:5"
  let _ ← invalidate "memoize:square:10"

/-- Example: Cache-aside pattern -/
def exCacheAside : RedisM Unit := do
  Log.info "Example: Cache-aside pattern (lazy loading)"

  -- Cache-aside: Check cache first, fetch from DB on miss
  let userId := "user:123"
  let cacheKey := s!"cache-aside:{userId}"

  Log.info s!"Loading {userId} (cache miss expected)..."
  let data1 ← cacheAside cacheKey (fetchFromDatabase userId) (some 300)
  Log.info s!"  Data: {data1}"

  Log.info s!"Loading {userId} again (cache hit expected)..."
  let data2 ← cacheAside cacheKey (fetchFromDatabase userId) (some 300)
  Log.info s!"  Data: {data2}"

  -- Cleanup
  let _ ← invalidate cacheKey

/-- Example: Write-through pattern -/
def exWriteThrough : RedisM Unit := do
  Log.info "Example: Write-through pattern"

  let cacheKey := "write-through:user:456"
  let userData := "Updated user profile"

  -- Write-through: Write to both cache and database synchronously
  Log.info s!"Writing to cache and database..."
  writeThrough cacheKey userData (writeToDatabase "user:456")

  -- Read back from cache
  let exists_ ← existsKey cacheKey
  if exists_ then
    let cached ← get cacheKey
    Log.info s!"  Cached data: {String.fromUTF8! cached}"
  else
    Log.info "  Not found in cache"

  -- Cleanup
  let _ ← invalidate cacheKey

/-- Example: Write-behind pattern -/
def exWriteBehind : RedisM Unit := do
  Log.info "Example: Write-behind pattern (async write)"

  let cacheKey := "write-behind:user:789"
  let userData := "Asynchronously persisted data"

  -- Write-behind: Write to cache immediately, schedule DB write
  Log.info s!"Writing to cache (DB write deferred)..."
  writeBehind cacheKey userData (writeToDatabase "user:789")

  -- Data is immediately available in cache
  let exists_ ← existsKey cacheKey
  if exists_ then
    let cached ← get cacheKey
    Log.info s!"  Cached data (available immediately): {String.fromUTF8! cached}"
  else
    Log.info "  Not found in cache"

  -- Cleanup
  let _ ← invalidate cacheKey

/-- Example: Stampede prevention -/
def exStampedePrevention : RedisM Unit := do
  Log.info "Example: Stampede prevention with distributed locks"

  -- Simulate expensive computation that shouldn't run concurrently
  let expensiveComputation : IO String := do
    IO.println "  [Compute] Starting expensive computation..."
    IO.sleep 50  -- Simulate work
    IO.println "  [Compute] Computation complete"
    return "computed result"

  let key := "stampede:expensive:result"
  let lockKey := "stampede:expensive:lock"

  -- getOrComputeWithLock prevents multiple concurrent computations
  Log.info "First request (will compute)..."
  let result1 ← getOrComputeWithLock key lockKey 60 30 expensiveComputation

  Log.info "Second request (will use cache)..."
  let result2 ← getOrComputeWithLock key lockKey 60 30 expensiveComputation

  Log.info s!"Results: {result1}, {result2}"

  -- Cleanup
  let _ ← invalidate key

/-- Example: Cache invalidation -/
def exCacheInvalidation : RedisM Unit := do
  Log.info "Example: Cache invalidation"

  -- Store some cached values
  set "invalidation:item:1" "Value 1"
  set "invalidation:item:2" "Value 2"
  set "invalidation:item:3" "Value 3"
  set "invalidation:other:1" "Other value"

  Log.info "Stored 4 items in cache"

  -- Invalidate specific key
  let _ ← invalidate "invalidation:item:1"
  Log.info "Invalidated invalidation:item:1"

  -- Check what remains
  let item1Exists ← existsKey "invalidation:item:1"
  let item2Exists ← existsKey "invalidation:item:2"
  let other1Exists ← existsKey "invalidation:other:1"

  Log.info s!"item:1 exists: {item1Exists}"
  Log.info s!"item:2 exists: {item2Exists}"
  Log.info s!"other:1 exists: {other1Exists}"

  -- Invalidate by pattern (all items matching pattern)
  let deleted ← invalidatePattern "invalidation:item:*"
  Log.info s!"Invalidated {deleted} keys matching 'invalidation:item:*'"

  -- Cleanup
  let _ ← invalidate "invalidation:other:1"

/-- Example: Cache statistics -/
def exCacheStats : RedisM Unit := do
  Log.info "Example: Cache statistics"

  let key := "stats:example"

  -- Store a value with TTL
  setex key "some cached value" 3600

  -- Get cache statistics
  let stats ← cacheStats key
  Log.info s!"Cache statistics for '{key}':"
  Log.info s!"  Key exists: {stats.keyExists}"
  Log.info s!"  TTL remaining: {stats.ttlRemaining} seconds"
  Log.info s!"  Value size: {stats.valueSize} bytes"

  -- Touch cache to refresh TTL
  let _ ← touchCache key 7200
  let newTtl ← cacheTtl key
  Log.info s!"TTL after touch: {newTtl} seconds"

  -- Cleanup
  let _ ← invalidate key

/-- Example: Conditional caching -/
def exConditionalCache : RedisM Unit := do
  Log.info "Example: Conditional caching"

  -- Only cache if value meets criteria
  let smallValue := "small"
  let largeValue := "this is a much larger value that might not be worth caching"

  -- Cache small values
  let cached1 ← cacheIf "conditional:small" smallValue (some 60) (fun v => v.length < 20)
  Log.info s!"Small value cached: {cached1}"

  -- Don't cache large values
  let cached2 ← cacheIf "conditional:large" largeValue (some 60) (fun v => v.length < 20)
  Log.info s!"Large value cached: {cached2}"

  -- Verify
  let smallExists ← existsKey "conditional:small"
  let largeExists ← existsKey "conditional:large"
  Log.info s!"Small key exists: {smallExists}"
  Log.info s!"Large key exists: {largeExists}"

  -- Cleanup
  let _ ← invalidate "conditional:small"

/-- Example: Refresh cache -/
def exRefreshCache : RedisM Unit := do
  Log.info "Example: Refresh cache"

  let key := "refresh:data"

  -- Initial cache
  let _ ← memoize key 60 (pure "initial value")
  let initial ← get key
  Log.info s!"Initial value: {String.fromUTF8! initial}"

  -- Force refresh even if cached
  let refreshed ← refreshCache key 60 (pure "refreshed value")
  Log.info s!"Refreshed value: {refreshed}"

  -- Cleanup
  let _ ← invalidate key

/-- Run all caching examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Caching Pattern Examples ==="
  exMemoization
  exCacheAside
  exWriteThrough
  exWriteBehind
  exStampedePrevention
  exCacheInvalidation
  exCacheStats
  exConditionalCache
  exRefreshCache
  Log.info "=== Caching Pattern Examples Complete ==="

end FeaturesCachingExample
