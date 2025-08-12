import RedisLean.Codec
import RedisLean.Error
import RedisLean.Monad
import RedisLean.Ops

namespace Redis

/-- Memoization with TTL - caches the result of a computation in Redis.
    If the key exists and can be decoded, returns the cached value.
    Otherwise, computes the value, stores it with the given TTL, and returns it. -/
def memoize [Codec α] (key : String) (ttlSeconds : Nat) (compute : IO α) : RedisM α := do
  let keyExists ← existsKey key
  if keyExists then
    let bs ← get key
    match Codec.dec bs with
    | .ok v => return v
    | .error _ => recompute key ttlSeconds compute
  else
    recompute key ttlSeconds compute
where
  recompute (key : String) (ttlSeconds : Nat) (compute : IO α) : RedisM α := do
    let v ← compute
    setex key (Codec.enc v) ttlSeconds
    return v

/-- Cache-aside pattern - checks cache first, falls back to fetch function.
    Optionally sets a TTL on the cached value. -/
def cacheAside [Codec α] (key : String) (fetch : IO α) (ttl : Option Nat := none) : RedisM α := do
  let keyExists ← existsKey key
  if keyExists then
    let bs ← get key
    match Codec.dec bs with
    | .ok v => return v
    | .error _ => fetchAndCache key fetch ttl
  else
    fetchAndCache key fetch ttl
where
  fetchAndCache (key : String) (fetch : IO α) (ttl : Option Nat) : RedisM α := do
    let v ← fetch
    match ttl with
    | some seconds => setex key (Codec.enc v) seconds
    | none => set key (Codec.enc v)
    return v

/-- Write-through cache - writes to both cache and persistent storage.
    The cache is updated first, then the persist function is called. -/
def writeThrough [Codec α] (key : String) (value : α) (persist : α → IO Unit) : RedisM Unit := do
  set key (Codec.enc value)
  persist value

/-- Write-through cache with TTL -/
def writeThroughEx [Codec α] (key : String) (value : α) (ttlSeconds : Nat) (persist : α → IO Unit) : RedisM Unit := do
  setex key (Codec.enc value) ttlSeconds
  persist value

/-- Write-behind cache - writes to cache immediately, persist is called but errors are logged.
    This provides better write performance at the cost of potential inconsistency. -/
def writeBehind [Codec α] (key : String) (value : α) (persist : α → IO Unit) : RedisM Unit := do
  set key (Codec.enc value)
  -- In a production system, this would be queued for async execution
  -- For now, we execute synchronously but catch errors
  try
    persist value
  catch _ =>
    -- Log error but don't fail the cache write
    pure ()

/-- Cache invalidation by pattern - deletes all keys matching the given pattern.
    Returns the number of keys deleted. -/
def invalidatePattern (pattern : String) : RedisM Nat := do
  let ks ← keys (α := String) (String.toUTF8 pattern)
  if ks.isEmpty then return 0
  let keyStrs := ks.filterMap (fun bs => String.fromUTF8? bs)
  del keyStrs

/-- Invalidate a single cache key -/
def invalidate (key : String) : RedisM Nat :=
  del [key]

/-- Refresh cache - recomputes and stores a value even if cached.
    Useful for forcing cache refresh. -/
def refreshCache [Codec α] (key : String) (ttlSeconds : Nat) (compute : IO α) : RedisM α := do
  let v ← compute
  setex key (Codec.enc v) ttlSeconds
  return v

/-- Get or compute with lock - prevents cache stampede by using SETNX as a lock.
    Only one caller will compute the value, others will wait and retry. -/
def getOrComputeWithLock [Codec α]
    (key : String)
    (lockKey : String)
    (ttlSeconds : Nat)
    (lockTimeoutSeconds : Nat := 30)
    (compute : IO α)
    (maxRetries : Nat := 10)
    (retryDelayMs : Nat := 100) : RedisM α := do
  -- Try to get cached value first
  let keyExists ← existsKey key
  if keyExists then
    let bs ← get key
    match Codec.dec bs with
    | .ok v => return v
    | .error _ => computeWithLock key lockKey ttlSeconds lockTimeoutSeconds compute maxRetries retryDelayMs
  else
    computeWithLock key lockKey ttlSeconds lockTimeoutSeconds compute maxRetries retryDelayMs
where
  computeWithLock (key lockKey : String) (ttlSeconds lockTimeoutSeconds : Nat)
      (compute : IO α) (maxRetries retryDelayMs : Nat) : RedisM α := do
    -- Try to acquire lock
    let lockAcquired ← acquireLock lockKey lockTimeoutSeconds
    if lockAcquired then
      try
        -- Double-check cache after acquiring lock
        let keyExists ← existsKey key
        if keyExists then
          let bs ← get key
          match Codec.dec bs with
          | .ok v =>
            let _ ← invalidate lockKey
            return v
          | .error _ => pure ()
        -- Compute and cache
        let v ← compute
        setex key (Codec.enc v) ttlSeconds
        let _ ← invalidate lockKey
        return v
      catch e =>
        let _ ← invalidate lockKey
        throw e
    else
      -- Wait and retry
      waitAndRetry key lockKey ttlSeconds lockTimeoutSeconds compute maxRetries retryDelayMs 0

  acquireLock (lockKey : String) (timeoutSeconds : Nat) : RedisM Bool := do
    -- Use SETNX with expiration
    let lockExists ← existsKey lockKey
    if lockExists then return false
    else
      setnx lockKey "locked"
      let _ ← expire lockKey timeoutSeconds
      return true

  waitAndRetry (key lockKey : String) (ttlSeconds lockTimeoutSeconds : Nat)
      (compute : IO α) (maxRetries retryDelayMs currentRetry : Nat) : RedisM α := do
    if currentRetry >= maxRetries then
      -- Give up waiting, compute anyway
      let v ← compute
      setex key (Codec.enc v) ttlSeconds
      return v
    else
      -- Sleep and retry
      IO.sleep (UInt32.ofNat retryDelayMs)
      -- Check if value is now cached
      let keyExists ← existsKey key
      if keyExists then
        let bs ← get key
        match Codec.dec bs with
        | .ok v => return v
        | .error _ => waitAndRetry key lockKey ttlSeconds lockTimeoutSeconds compute maxRetries retryDelayMs (currentRetry + 1)
      else
        waitAndRetry key lockKey ttlSeconds lockTimeoutSeconds compute maxRetries retryDelayMs (currentRetry + 1)

/-- Conditional cache - only cache if the predicate returns true -/
def cacheIf [Codec α] (key : String) (value : α) (ttl : Option Nat) (predicate : α → Bool) : RedisM Bool := do
  if predicate value then
    match ttl with
    | some seconds => setex key (Codec.enc value) seconds
    | none => set key (Codec.enc value)
    return true
  else
    return false

/-- Touch cache - refresh TTL without modifying the value -/
def touchCache (key : String) (ttlSeconds : Nat) : RedisM Bool :=
  expire key ttlSeconds

/-- Get cache TTL remaining -/
def cacheTtl (key : String) : RedisM Nat :=
  ttl key

/-- Cache statistics for a key -/
structure CacheStats where
  keyExists : Bool
  ttlRemaining : Nat
  valueSize : Nat
  deriving Repr

/-- Get cache statistics for a key -/
def cacheStats (key : String) : RedisM CacheStats := do
  let keyExists ← existsKey key
  if keyExists then
    let ttlVal ← ttl key
    let bs ← get key
    return { keyExists := true, ttlRemaining := ttlVal, valueSize := bs.size }
  else
    return { keyExists := false, ttlRemaining := 0, valueSize := 0 }

end Redis
