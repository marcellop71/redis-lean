import RedisLean.TypedKey
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesTypedKeysExample

open Redis

/-!
# TypedKey Examples

Demonstrates phantom-typed keys for compile-time type safety.
TypedKeys ensure that values stored and retrieved are of the expected type,
preventing runtime errors from type mismatches.
-/

/-- Example: Basic TypedKey usage -/
def exBasicTypedKey : RedisM Unit := do
  Log.info "Example: Basic TypedKey usage"

  -- Create typed keys with compile-time type information
  let userAge : TypedKey Nat := TypedKey.mk "user:age:123"
  let userName : TypedKey String := TypedKey.mk "user:name:123"
  let userScore : TypedKey Float := TypedKey.mk "user:score:123"

  -- Store values with type safety
  typedSet userAge 25
  typedSet userName "Alice"
  typedSet userScore 95.5

  -- Retrieve values with correct types
  let ageOpt ← typedGet userAge
  let nameOpt ← typedGet userName
  let scoreOpt ← typedGet userScore

  match ageOpt, nameOpt, scoreOpt with
  | some age, some name, some score =>
    Log.info s!"User: {name}, Age: {age}, Score: {score}"
  | _, _, _ =>
    Log.info "Some values not found"

  -- Cleanup (delete each separately since they have different types)
  let _ ← del [userAge.key, userName.key, userScore.key]

/-- Example: Namespace organization -/
def exNamespace : RedisM Unit := do
  Log.info "Example: Namespace organization"

  -- Create namespaces for logical grouping
  let appNs := Namespace.create "app"
  let usersNs := appNs.nested "users"
  let ordersNs := appNs.nested "orders"

  -- Keys are automatically prefixed with namespace
  let userKey : TypedKey String := usersNs.key "profile:alice"
  let orderKey : TypedKey String := ordersNs.key "order:12345"

  Log.info s!"User key: {userKey.key}"     -- "app:users:profile:alice"
  Log.info s!"Order key: {orderKey.key}"   -- "app:orders:order:12345"

  -- Store and retrieve using namespaced keys
  typedSet userKey "Alice's profile data"
  typedSet orderKey "Order #12345 data"

  let userDataOpt ← typedGet userKey
  let orderDataOpt ← typedGet orderKey

  match userDataOpt with
  | some d => Log.info s!"User data: {d}"
  | none => Log.info "User data not found"

  match orderDataOpt with
  | some d => Log.info s!"Order data: {d}"
  | none => Log.info "Order data not found"

  -- Cleanup
  let _ ← typedDel [userKey, orderKey]

/-- Example: Typed hash fields -/
def exTypedHashFields : RedisM Unit := do
  Log.info "Example: Typed hash fields"

  -- Create a hash key
  let userHash := "user:profile:456"

  -- Define typed fields
  let nameField : TypedHashField String := TypedHashField.create "name"
  let ageField : TypedHashField Nat := TypedHashField.create "age"
  let activeField : TypedHashField Bool := TypedHashField.create "active"

  -- Store typed field values
  let _ ← typedHset userHash nameField "Bob"
  let _ ← typedHset userHash ageField 30
  let _ ← typedHset userHash activeField true

  -- Retrieve typed field values
  let nameOpt ← typedHget userHash nameField
  let ageOpt ← typedHget userHash ageField
  let activeOpt ← typedHget userHash activeField

  match nameOpt, ageOpt, activeOpt with
  | some name, some age, some active =>
    Log.info s!"Hash user: {name}, Age: {age}, Active: {active}"
  | _, _, _ =>
    Log.info "Some hash fields not found"

  -- Cleanup
  let _ ← del [userHash]

/-- Example: Multi-level namespaces -/
def exMultiLevelNamespaces : RedisM Unit := do
  Log.info "Example: Multi-level namespaces"

  -- Build hierarchical namespace structure
  let rootNs := Namespace.create "myapp"
  let cacheNs := rootNs.nested "cache"
  let sessionNs := rootNs.nested "sessions"
  let metricsNs := rootNs.nested "metrics"

  -- Sub-namespaces for different cache types
  let userCacheNs := cacheNs.nested "users"
  let productCacheNs := cacheNs.nested "products"

  -- Generate keys with full namespace path
  let userCacheKey : TypedKey String := userCacheNs.key "user:789"
  let productCacheKey : TypedKey String := productCacheNs.key "product:abc"
  let sessionKey : TypedKey String := sessionNs.key "session:xyz"
  let metricsKey : TypedKey String := metricsNs.key "requests"

  Log.info s!"User cache key: {userCacheKey.key}"       -- "myapp:cache:users:user:789"
  Log.info s!"Product cache key: {productCacheKey.key}" -- "myapp:cache:products:product:abc"
  Log.info s!"Session key: {sessionKey.key}"            -- "myapp:sessions:session:xyz"
  Log.info s!"Metrics key: {metricsKey.key}"            -- "myapp:metrics:requests"

/-- Example: Type-safe key patterns -/
def exTypeSafePatterns : RedisM Unit := do
  Log.info "Example: Type-safe key patterns"

  -- Create keys for different data types with clear naming
  let counterKey : TypedKey Int := TypedKey.mk "counters:visitors"
  let flagKey : TypedKey Bool := TypedKey.mk "flags:maintenance"
  let configKey : TypedKey String := TypedKey.mk "config:database_url"

  -- Store values
  typedSet counterKey 1000
  typedSet flagKey false
  typedSet configKey "redis://localhost:6379"

  -- Type-safe retrieval - compiler ensures correct types
  let visitorsOpt ← typedGet counterKey
  let maintenanceOpt ← typedGet flagKey
  let dbUrlOpt ← typedGet configKey

  match visitorsOpt with
  | some v => Log.info s!"Visitors: {v}"
  | none => Log.info "Visitors key not found"

  match maintenanceOpt with
  | some m => Log.info s!"Maintenance mode: {m}"
  | none => Log.info "Maintenance flag not found"

  match dbUrlOpt with
  | some url => Log.info s!"DB URL: {url}"
  | none => Log.info "DB URL not found"

  -- Cleanup (delete each separately since they have different types)
  let _ ← del [counterKey.key, flagKey.key, configKey.key]

/-- Example: TTL with typed keys -/
def exTypedKeyTTL : RedisM Unit := do
  Log.info "Example: TTL with typed keys"

  let sessionKey : TypedKey String := TypedKey.mk "session:abc123"

  -- Set with expiration
  typedSetex sessionKey "user_session_data" 3600  -- 1 hour

  -- Check TTL
  let ttlValue ← typedTtl sessionKey
  Log.info s!"Session TTL: {ttlValue} seconds"

  -- Refresh expiration
  let _ ← typedExpire sessionKey 7200  -- 2 hours

  let newTtl ← typedTtl sessionKey
  Log.info s!"Session TTL after refresh: {newTtl} seconds"

  -- Check existence
  let exists_ ← typedExists sessionKey
  Log.info s!"Session exists: {exists_}"

  -- Cleanup
  let _ ← typedDel [sessionKey]

/-- Run all typed key examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== TypedKey Examples ==="
  exBasicTypedKey
  exNamespace
  exTypedHashFields
  exMultiLevelNamespaces
  exTypeSafePatterns
  exTypedKeyTTL
  Log.info "=== TypedKey Examples Complete ==="

end FeaturesTypedKeysExample
