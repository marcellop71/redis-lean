# Redis-Lean Examples

Focused examples demonstrating Redis operations using the redis-lean library. Examples are organized into three complementary approaches showcasing different levels of abstraction and use cases.

## 🔧 FFI Examples (`FFI/`)

Direct usage of the Foreign Function Interface wrapping the hiredis C library.

**When to use:**
- Performance-critical applications requiring minimal overhead
- Need precise control over Redis operations
- Working with binary data and ByteArray operations
- Building custom abstractions on top of Redis

**Available examples:**
- `Set.lean` - Basic set operations, NX/XX options, and set/get workflows
- `Get.lean` - Key retrieval patterns and non-existent key handling
- `Del.lean` - Key deletion operations and existence checking
- `SAdd.lean` - Redis set operations with membership testing

## 🏗️ Monadic Examples (`Monadic/`)

High-level monadic interface with type safety and automatic resource management.

**When to use:**
- Application development requiring safety and ease of use
- Complex workflows benefiting from monadic composition
- Type-safe operations with compile-time guarantees
- Automatic connection and error management

**Available examples:**
- `Set.lean` - Typed operations (String, Nat, Int, Bool) and conditional sets
- `Get.lean` - Type-safe retrieval with automatic codec handling
- `Del.lean` - Safe deletion with comprehensive error handling
- `SAdd.lean` - Set operations using monadic interface with team examples
- `ConnectionReuse.lean` - Connection pooling and reuse patterns

## 🔬 Mathlib Examples (`Mathlib/`)

Redis-backed features designed for Lean theorem prover and Mathlib development workflows.

**When to use:**
- Caching elaboration and tactic results across Lean sessions
- Building searchable theorem databases
- Tracking proof state for time-travel debugging
- Coordinating distributed proof checking

**Available examples:**

### `TacticCache.lean` - Elaboration Caching
Demonstrates caching elaboration results to speed up repeated tactic applications:
- Basic store/load with TTL
- Cache statistics (hit rate, miss count)
- Module-based invalidation

### `TheoremSearch.lean` - Type-Indexed Search
Shows how to index and search theorems by type structure:
- Index theorems with metadata and tags
- Search by conclusion type, hypothesis type
- Search by name pattern, tag, or module
- Remove theorems from index

### `Declaration.lean` - Declaration Storage
Demonstrates storing Lean declarations with dependency tracking:
- Store/load declarations with metadata
- Query forward and reverse dependencies
- Get declarations by module
- Environment snapshots for incremental builds

### `InstanceCache.lean` - Instance Resolution Cache
Shows caching type class instance synthesis:
- Cache instances by class and target type
- Get or synthesize pattern
- Invalidate by class or module
- Cache statistics

### `ProofState.lean` - Time-Travel Debugging
Demonstrates proof state snapshots for debugging:
- Start proof sessions
- Record proof steps with goals and local context
- Record tactic execution trace with timing
- Navigate proof history (parent step, path to step)
- Compare proof states

### `DistProof.lean` - Distributed Proof Checking
Shows coordinating parallel proof checking:
- Initialize job queue with module dependencies
- Register workers and heartbeats
- Claim jobs respecting dependencies
- Track progress and handle failures
- Requeue stale jobs from dead workers

## 🚀 Quick Start

### Prerequisites
```bash
# Ensure Redis server is running
redis-server

# Or start with Docker
docker run -d -p 6379:6379 redis:latest
```

### Running Examples

**Using the CLI:**
```bash
# Run all examples
lake exe redis_examples

# Run only FFI examples
lake exe redis_examples --ffi

# Run only Monadic examples
lake exe redis_examples --monadic

# Run only Mathlib examples
lake exe redis_examples --mathlib
```

## 📚 Learning Path

### 🟢 Beginners
1. **Start with Monadic examples** - safer and more intuitive
2. **Begin with `Set.lean` and `Get.lean`** - core Redis operations
3. **Study the `ex0` functions** - basic patterns with error handling

### 🟡 Intermediate
1. **Compare equivalent operations** across FFI and Monadic examples
2. **Explore `SAdd.lean`** - Redis set data structures
3. **Try Mathlib `TacticCache.lean`** - caching patterns

### 🔴 Advanced
1. **Deep dive into FFI examples** - performance optimization
2. **Explore `DistProof.lean`** - distributed coordination
3. **Study `ProofState.lean`** - complex data structures

## ⚙️ Key Differences

| Aspect | FFI | Monadic | Mathlib |
|--------|-----|---------|---------|
| **Type Safety** | Manual ByteArray | Automatic codec | Domain-specific types |
| **Use Case** | Low-level control | General apps | Theorem prover workflows |
| **Abstraction** | Minimal | Medium | High |
| **Data Types** | ByteArray | String, Nat, Int, Bool | Expr, TypePattern, Goals |

## 💡 Example Patterns

### FFI Pattern
```lean
def ex0 : EIO RedisError Unit := do
  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let key := String.toUTF8 "example"
    let value := String.toUTF8 "data"

    try
      FFI.set ctx key value
      let result ← FFI.get ctx key
      let retrieved := String.fromUTF8! result
      Log.EIO.info s!"retrieved: {retrieved}"
    catch e =>
      Log.EIO.error s!"error: {e}"
```

### Monadic Pattern
```lean
def ex0 : RedisM Unit := do
  try
    set "example" "data"
    let result ← getAs String "example"
    Log.info s!"retrieved: {result}"
  catch e =>
    Log.error s!"error: {e}"
```

### Mathlib Pattern
```lean
def exTacticCache : RedisM Unit := do
  let cache := TacticCache.create "myproject" 3600

  -- First access: cache miss
  let result ← cache.getOrElaborate syntaxHash elaborateTactic

  -- Second access: cache hit (instant)
  let cached ← cache.getOrElaborate syntaxHash elaborateTactic

  -- Check statistics
  let stats ← cache.getStats
  Log.info s!"Hit rate: {TacticCache.hitRate stats}%"
```

## 🔍 Mathlib Example Details

### Tactic Caching
- Content-addressable caching using syntax hashes
- Configurable TTL for cache entries
- Per-module invalidation for incremental builds
- Hit/miss statistics for performance monitoring

### Theorem Search
- Index theorems by conclusion and hypothesis types
- Hash-based type pattern matching
- Sorted set storage for relevance ranking
- Multi-index for flexible querying

### Declaration Storage
- Hash storage for declaration metadata
- Set-based dependency tracking (forward and reverse)
- Environment snapshots with content hashing
- Module-scoped queries

### Instance Cache
- Class+type hash for cache keys
- Synthesis result caching with module tracking
- Class-wide and module-wide invalidation
- Local vs global instance distinction

### Proof State
- Session-based proof tracking
- Step-by-step state snapshots
- Tactic execution tracing with timing
- Parent chain for backtracking
- Goal and local context serialization

### Distributed Proof
- Priority-based job queue (sorted sets)
- Dependency-aware job claiming
- Worker registration and heartbeats
- Stale job detection and requeuing
- Progress tracking and monitoring

## ⚠️ Safety Guidelines

- **Use prefixed keys** to avoid conflicts between examples
- **Examples include proper error handling** demonstrating exception management
- **FFI examples use `FFI.withRedis`** for automatic connection cleanup
- **Monadic examples use `runRedis`** with built-in resource management
- **Mathlib examples use configurable key prefixes** for isolation
- **Test with dedicated Redis instance** when learning
