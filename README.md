# redis-lean

> ⚠️ **Warning**: this is work in progress, it is still incomplete and it ~~may~~ will contain errors

## AI Assistance Disclosure

Parts of this repository were created with assistance from AI-powered coding tools, specifically Claude by Anthropic. Not all generated code may have been reviewed. Generated code may have been adapted by the author. Design choices, architectural decisions, and final validation were performed independently by the author.

## Overview

[Redis](https://redis.io/) is an outstanding database, and enabling the [Lean](https://lean-lang.org/) ecosystem to interact with it could unlock many exciting possibilities.
The versatility and efficiency of *Redis* make it an ideal candidate for storing Lean's complex terms and types
(including maybe internal structures such as proof states).

This repo hosts:

🔧 a minimal *Redis* **[Client](RedisLean/README.md)**: client library for *Lean* built around [hiredis](https://github.com/redis/hiredis) (a C library), improved with a typed monadic interface (somehow inspired by Haskell's [Hedis](https://hackage.haskell.org/package/hedis) library)

📖 a minimal *Redis* **[Model](RedisModel/README.md)**: tentative formal specs for the very core *Redis* operations (an abstract formal model of *Redis* as a key-value store) meant to be used in a theorem proving framework. The model is minimal and does not encompass the very rich set of *Redis* features (key expirations, non-bytearray data types, pubsub engine and much more)

📝 some **[Remarks](RedisLean/remarks.md)** about Redis

🌊 **[Redis Streams](docs/STREAMS.md)** support with XADD, XREAD, XRANGE, XLEN, XDEL, XTRIM commands

🏹 **[Arrow Integration](#arrow-integration-redisarrow)** for storing Arrow columnar data in Redis and converting streams to Arrow batches

🔒 **[Type Safety](#type-safety)** with phantom-typed keys and namespaces

💾 **[Caching Utilities](#caching-utilities)** including memoization, cache-aside, and write-through patterns

🔌 **[Connection Pooling](#connection-pooling)** for managing multiple Redis connections

📊 **[Observability](#observability)** with tracing, metrics export (Prometheus/JSON), and percentile latencies

🧪 **[Testing Support](#testing-support)** with in-memory Redis mock and test fixtures

🔬 **[Mathlib Integration](#mathlib-integration)** for Lean theorem prover workflows (tactic caching, theorem search, distributed proof checking)

Please remark:

- client **[wrapping](hiredis/README.md)** just *hiredis* synchronous APIs
- comprehensive Redis command coverage (~155 commands) across all major categories
- no full support for some command options (for example: the basic SET command has also a GET option which is not covered)
- testing is still to be developed (also in relation to the abstract model)
- this repo include some simple **[examples](Examples/README.md)** about how to use the client lib

## Command Coverage

The library provides comprehensive coverage of Redis commands organized by category:

| Category | Commands | Count |
|----------|----------|-------|
| **String** | SET, GET, SETEX, APPEND, GETDEL, GETEX, GETRANGE, GETSET, INCR, INCRBY, INCRBYFLOAT, DECR, DECRBY, MGET, MSET, MSETNX, SETNX, SETRANGE, STRLEN, PSETEX, LCS | 21 |
| **Key** | DEL, EXISTS, TYPE, TTL, PTTL, KEYS, SCAN, EXPIRE, EXPIREAT, PEXPIRE, PEXPIREAT, PERSIST, RENAME, RENAMENX, COPY, UNLINK, TOUCH, EXPIRETIME, RANDOMKEY | 19 |
| **List** | LPUSH, RPUSH, LPUSHX, RPUSHX, LPOP, RPOP, LRANGE, LINDEX, LLEN, LSET, LINSERT, LTRIM, LREM, LPOS, LMOVE, LMPOP, BLPOP, BRPOP, BLMOVE, BLMPOP, RPOPLPUSH, BRPOPLPUSH | 22 |
| **Set** | SADD, SCARD, SISMEMBER, SMEMBERS, SREM, SPOP, SRANDMEMBER, SMOVE, SMISMEMBER, SDIFF, SDIFFSTORE, SINTER, SINTERSTORE, SINTERCARD, SUNION, SUNIONSTORE, SSCAN | 17 |
| **Hash** | HSET, HGET, HGETALL, HDEL, HEXISTS, HINCRBY, HKEYS, HLEN, HVALS, HSETNX, HMGET, HMSET, HINCRBYFLOAT, HSTRLEN, HRANDFIELD, HSCAN | 16 |
| **Sorted Set** | ZADD, ZCARD, ZRANGE, ZSCORE, ZRANK, ZREVRANK, ZCOUNT, ZINCRBY, ZREM, ZLEXCOUNT, ZMSCORE, ZRANDMEMBER, ZSCAN, ZRANGEBYSCORE, ZREVRANGE, ZREVRANGEBYSCORE, ZRANGEBYLEX, ZREVRANGEBYLEX, ZREMRANGEBYRANK, ZREMRANGEBYSCORE, ZREMRANGEBYLEX, ZPOPMIN, ZPOPMAX, BZPOPMIN, BZPOPMAX, ZUNIONSTORE, ZINTERSTORE, ZDIFFSTORE, ZUNION, ZINTER, ZDIFF, ZINTERCARD, ZRANGESTORE | 33 |
| **Stream** | XADD, XREAD, XREADGROUP, XRANGE, XLEN, XDEL, XTRIM | 7 |
| **HyperLogLog** | PFADD, PFCOUNT, PFMERGE | 3 |
| **Geospatial** | GEOADD, GEODIST, GEOHASH, GEOPOS, GEOSEARCH, GEOSEARCHSTORE | 6 |
| **Bitmap** | SETBIT, GETBIT, BITCOUNT, BITOP, BITPOS | 5 |
| **Transaction** | MULTI, EXEC, DISCARD, WATCH, UNWATCH | 5 |
| **Scripting** | EVAL, EVALSHA, SCRIPT LOAD, SCRIPT EXISTS, SCRIPT FLUSH, SCRIPT KILL | 6 |
| **Pub/Sub** | PUBLISH, SUBSCRIBE | 2 |
| **Connection** | AUTH, HELLO, PING, CLIENT ID, CLIENT GETNAME, CLIENT SETNAME, CLIENT LIST, CLIENT INFO, CLIENT KILL, CLIENT PAUSE, CLIENT UNPAUSE, SELECT, ECHO, QUIT, RESET | 15 |
| **Server** | INFO, DBSIZE, LASTSAVE, BGSAVE, BGREWRITEAOF, TIME, CONFIG GET, CONFIG SET, CONFIG REWRITE, CONFIG RESETSTAT, MEMORY USAGE, OBJECT ENCODING, OBJECT IDLETIME, OBJECT FREQ, SLOWLOG GET, SLOWLOG LEN, SLOWLOG RESET, FLUSHALL, COMMAND | 19 |

Please note that, despite the presence of this minimal model of Redis, the true potential of Lean remains largely untapped in this repository. At present, Lean is being used primarily as a functional programming language—similar to Haskell (though arguably an even more expressive and elegant one). However, its far greater strength lies in its capabilities as an interactive theorem prover. This project does not yet explore those dimensions: no formal proofs of correctness, consistency, or deeper properties of the model have been attempted here. The current work should therefore be seen as a foundation—a minimal but precise specification of Redis's core operations—on top of which richer formal reasoning and verification could eventually be developed.

## Requirements

- **Lean 4**: v4.27.0 or compatible
- **hiredis**: Redis C client library
- **zlog**: Logging library

### System Dependencies

**Ubuntu/Debian:**
```bash
sudo apt-get install libhiredis-dev libzlog-dev
```

**macOS:**
```bash
brew install hiredis zlog
```

## Building

```bash
# Build the library
lake build RedisLean

# Build with Arrow integration
lake build RedisArrow

# Run examples
lake exe examples

# Run tests
lake exe tests
```

## Usage

Add to your `lakefile.lean`:

```lean
require redisLean from git
  "https://github.com/marcellop71/redis-lean" @ "main"
```

### Basic Operations

```lean
import RedisLean

open Redis

def example : IO Unit := do
  let config : Read := { config := Config.default }
  match ← init config with
  | .error e => IO.println s!"Connection failed: {e}"
  | .ok sRef =>
    let result ← runRedis config sRef (do
      set "mykey" "hello"
      let value ← get "mykey"
      IO.println s!"Value: {String.fromUTF8! value}"
    )
    match result with
    | .ok () => IO.println "Success"
    | .error e => IO.println s!"Error: {e}"
```

### Authentication

Set `password` (and `username` for a Redis 6+ ACL user) on the `Config`; `AUTH` is sent right
after connecting, before `SELECT`, and again after `FFI.reconnectConfig` (hiredis' own
reconnect does not log in again; connection pools use `reconnectConfig`):

```lean
let config : Read := { config := Config.default.withAuth "secret" (username := some "app") }
```

A rejected login fails the connect with the server's error (e.g. `WRONGPASS`). `Repr Config`
masks the password. Test: `RedisTests/run-auth-test.sh` (throwaway server).

### Redis Streams

```lean
import RedisLean

open Redis

def streamExample : IO Unit := do
  let config : Read := { config := Config.default }
  match ← init config with
  | .error e => IO.println s!"Connection failed: {e}"
  | .ok sRef =>
    let _ ← runRedis config sRef (do
      -- Add to stream
      let id ← xadd "mystream" "*" [("field1", "value1"), ("field2", "value2")]
      IO.println s!"Added entry: {id}"

      -- Read from stream
      let entries ← xread [("mystream", "0")] (some 10) (some 1000)
      IO.println s!"Read {entries.size} bytes"

      -- Get stream length
      let len ← xlen "mystream"
      IO.println s!"Stream length: {len}"
    )
```

`xread`/`xreadgroup`/`xrange` return the reply flattened into newline-separated text.
For parsed entries (ids and field/value pairs, binary-safe) use `RedisLean.Streams`:

```lean
-- (stream, entries) pairs; [] on timeout
let streams ← xreadEntries [("mystream", "$")] (count := some 10) (blockMs := some 1000)
for (stream, entries) in streams do
  for e in entries do
    IO.println s!"{stream} {e.id} {e.fieldString? "field1"}"

-- consumer groups: ">" = new entries, "0" = this consumer's pending ones
let fresh ← xreadgroupEntries "workers" "worker-1" [("mystream", ">")] (count := some 10)

let entries ← xrangeEntries "mystream" "-" "+"   -- Array StreamEntry
```

These run on `commandArgv`, which executes any command given as an argument vector and
returns the reply tree (`Redis.Reply`); `commandReply` is its `RedisM` form.

## Arrow Integration (RedisArrow)

The `RedisArrow` module provides high-level integration between Arrow columnar data and Redis, implementing two patterns:

### Pattern 1: Keys of Type Arrow (Table Storage)

Store Arrow tables in Redis with schema, batches, and manifest:

```lean
import RedisArrow

open RedisArrow
open Redis

-- Configure table storage
let tableCfg := TableConfig.create "trades"
-- Keys: arrow:schema:trades, arrow:batch:trades:*, arrow:manifest:trades

-- Store schema once
let schema ← ArrowSchema.forType ArrowType.float64 "price"
storeSchema tableCfg schema

-- Store batches (auto-generates IDs, updates manifest)
let batch : RecordBatch := { schema := schema, array := myArray }
let result ← storeBatch tableCfg batch
-- result.batchId, result.serializedSize

-- Retrieve batches
let headBatch ← getHeadBatch tableCfg        -- Latest batch
let allBatches ← getAllBatches tableCfg      -- All batches in order
let manifest ← getManifest tableCfg          -- Batch IDs only

-- Iterate over batches
forEachBatch tableCfg fun batch => do
  IO.println s!"Batch with {batch.length} rows"
```

### Pattern 2: Stream-to-Arrow Micro-Batching

Convert Redis Streams into Arrow batches:

```lean
import RedisArrow

open RedisArrow

-- Configure batching
let streamCfg : StreamBatchConfig := {
  streamKey := "events"
  maxBatchRows := 10000      -- Flush every 10k rows
  maxBatchTimeMs := 5000     -- Or every 5 seconds
  blockTimeoutMs := some 1000
}

let tableCfg := TableConfig.create "events_archive"
let schema ← ArrowSchema.forType ArrowType.string "payload"

-- Process stream and store as Arrow batches
let results ← processStreamToBatches streamCfg tableCfg schema
for r in results do
  IO.println s!"Flushed {r.entriesProcessed} entries as batch {r.batchId}"
```

### RedisArrow Key Structure

| Key Pattern | Type | Description |
|------------|------|-------------|
| `arrow:schema:<table>` | String | Serialized schema |
| `arrow:batch:<table>:<id>` | String | Serialized RecordBatch |
| `arrow:manifest:<table>` | Sorted Set | Batch IDs (score = timestamp) |
| `arrow:head:<table>` | String | Latest batch ID |

### RedisArrow API Reference

```lean
-- Table operations
storeSchema      : TableConfig → ArrowSchema → RedisM Unit
getSchema        : TableConfig → RedisM (Option ArrowSchema)
storeBatch       : TableConfig → RecordBatch → RedisM StoreBatchResult
getBatch         : TableConfig → String → RedisM (Option RecordBatch)
getHeadBatch     : TableConfig → RedisM (Option RecordBatch)
getAllBatches    : TableConfig → RedisM (Array RecordBatch)
getManifest      : TableConfig → RedisM (Array String)
getBatchCount    : TableConfig → RedisM Nat
forEachBatch     : TableConfig → (RecordBatch → IO Unit) → RedisM Unit
deleteTable      : TableConfig → RedisM Unit

-- Window operations
getRecentBatches : TableConfig → Nat → RedisM (Array RecordBatch)
compactToRecent  : TableConfig → Nat → RedisM Nat

-- Stream operations
processStreamToBatches : StreamBatchConfig → TableConfig → ArrowSchema → RedisM (Array FlushResult)
readStreamEntries      : String → RedisM ByteArray
getStreamLength        : String → RedisM Nat
trimStream             : String → Nat → RedisM Nat
```

## Project Structure

```
redis-lean/
├── RedisLean/
│   ├── FFI.lean          # Low-level hiredis bindings
│   ├── Config.lean       # Connection configuration
│   ├── Error.lean        # Error types
│   ├── Codec.lean        # RESP encoding/decoding
│   ├── Ops.lean          # Redis operations
│   ├── Monad.lean        # RedisM monad
│   ├── Log.lean          # Logging utilities
│   ├── Metrics.lean      # Performance metrics & tracing
│   ├── TypedKey.lean     # Phantom-typed keys & namespaces
│   ├── Cache.lean        # Caching patterns (memoize, cache-aside)
│   ├── Pool.lean         # Connection pooling
│   ├── Expr.lean         # Lean Expr serialization (experimental)
│   └── Mathlib/          # Lean/Mathlib integration
│       ├── Core.lean         # Shared types, key naming, utilities
│       ├── TacticCache.lean  # Tactic elaboration caching
│       ├── TheoremSearch.lean # Type-indexed theorem search
│       ├── Declaration.lean  # Declaration storage & dependencies
│       ├── InstanceCache.lean # Instance resolution caching
│       ├── ProofState.lean   # Proof state snapshots
│       └── DistProof.lean    # Distributed proof coordination
├── RedisArrow/
│   ├── Table.lean        # Arrow table storage in Redis
│   └── Stream.lean       # Stream-to-Arrow micro-batching
├── RedisModel/
│   └── AbstractMinimal.lean  # Formal Redis model
├── RedisTests/
│   ├── Mock.lean         # In-memory Redis mock
│   ├── Fixtures.lean     # Test utilities & fixtures
│   └── ...               # Other test modules
├── Examples/
│   └── ...               # Usage examples
├── hiredis/
│   └── shim.c            # C FFI shim
├── docs/
│   └── STREAMS.md        # Streams documentation
├── RedisLean.lean        # Main module
├── RedisArrow.lean       # Arrow integration module
├── RedisModel.lean       # Model module
├── RedisTests.lean       # Test module exports
└── lakefile.lean
```

## Type Safety

The `TypedKey` module provides phantom-typed keys to prevent mixing keys of different value types at compile time.

### Phantom-Typed Keys

```lean
import RedisLean

open Redis

-- Create typed keys that enforce value types at compile time
def userAge : TypedKey Int := TypedKey.mk "user:age"
def userName : TypedKey String := TypedKey.mk "user:name"

def example : RedisM Unit := do
  -- Type-safe operations
  typedSet userAge 25
  typedSet userName "Alice"

  -- These return the correct types
  let age ← typedGet userAge      -- Option Int
  let name ← typedGet userName    -- Option String

  -- Compile-time error: can't use userName with Int operations
  -- typedSet userName 42  -- Type error!
```

### Namespaces

```lean
-- Organize keys with namespaces
let users := Namespace.mk "users"
let products := Namespace.mk "products"

-- Create namespaced typed keys
let userEmail : TypedKey String := users.key "email"
-- Key will be "users:email"

-- Nested namespaces
let adminUsers := users.child "admin"
let adminEmail : TypedKey String := adminUsers.key "email"
-- Key will be "users:admin:email"
```

### Typed Hash Fields

```lean
-- Type-safe hash operations
let userHash := TypedKey.mk "user:1"
let ageField : TypedHashField Int := TypedHashField.mk "age"
let nameField : TypedHashField String := TypedHashField.mk "name"

typedHset userHash ageField 30
typedHset userHash nameField "Bob"

let age ← typedHget userHash ageField    -- Option Int
let name ← typedHget userHash nameField  -- Option String
```

## Caching Utilities

The `Cache` module provides common caching patterns for Redis.

### Memoization

```lean
import RedisLean

open Redis

-- Memoize expensive computations with TTL
def getCachedData : RedisM String := do
  memoize "expensive:computation" 300 do  -- 5 minute TTL
    -- This only runs if cache miss
    IO.println "Computing..."
    pure "result"
```

### Cache-Aside Pattern

```lean
-- Fetch from cache, or load from source and cache
def getUserProfile (userId : String) : RedisM UserProfile := do
  cacheAside s!"user:profile:{userId}" fetchFromDB (some 3600)
where
  fetchFromDB : IO UserProfile := do
    -- Load from database
    pure { name := "Alice", email := "alice@example.com" }
```

### Write-Through Cache

```lean
-- Write to cache and persist simultaneously
def updateUser (user : User) : RedisM Unit := do
  writeThrough s!"user:{user.id}" user persistToDb
where
  persistToDb (u : User) : IO Unit := do
    -- Save to database
    pure ()
```

### Cache Invalidation

```lean
-- Invalidate all keys matching a pattern
let deleted ← invalidatePattern "user:*"
IO.println s!"Invalidated {deleted} keys"

-- Using CacheConfig for organized caching
let cache := CacheConfig.create "myapp" 3600
cache.invalidateAll  -- Clears myapp:*
```

## Connection Pooling

The `Pool` module provides connection pooling for managing multiple Redis connections efficiently.

```lean
import RedisLean

open Redis

def example : IO Unit := do
  let redisConfig := Config.default
  let poolConfig : PoolConfig := {
    maxConnections := 10
    minConnections := 2
    acquireTimeoutMs := 5000
    idleTimeoutMs := 60000
    validateOnAcquire := true
  }

  -- Create pool
  let pool ← Pool.create redisConfig poolConfig

  -- Use connection from pool
  let result ← pool.withConnection (do
    set "key" "value".toUTF8
    get "key"
  )

  -- Pool statistics
  let stats ← pool.getStats
  IO.println s!"Total connections: {stats.totalConnections}"
  IO.println s!"Active: {stats.activeConnections}"
  IO.println s!"Idle: {stats.idleConnections}"

  -- Cleanup
  pool.close
```

## Observability

The `Metrics` module provides tracing, metrics collection, and export capabilities.

### Tracing

```lean
import RedisLean

open Redis

def example : RedisM Unit := do
  -- Wrap operations with tracing
  withTrace "fetch-user" (do
    let _ ← get "user:1"
    let _ ← hgetall "user:1:profile"
  )
```

### Metrics Export

```lean
-- Get metrics snapshot
let metrics ← getMetrics
let snapshot ← metrics.snapshot

IO.println s!"Total commands: {snapshot.totalCommands}"
IO.println s!"Error count: {snapshot.totalErrors}"
IO.println s!"Avg latency: {snapshot.avgLatencyMs}ms"
IO.println s!"P99 latency: {snapshot.p99LatencyMs}ms"

-- Export to Prometheus format
let prometheusOutput ← metrics.toPrometheus
-- redis_commands_total{command="GET"} 1234
-- redis_command_latency_ms{command="GET",quantile="0.99"} 2
-- redis_bytes_written_total 56789
-- ...

-- Export to JSON
let jsonOutput ← metrics.toJson
```

### Slow Command Logging

```lean
-- Configure slow command threshold
metrics.setSlowThreshold 100  -- Log commands > 100ms

-- Get slow commands
let slowCmds ← metrics.getSlowCommands
for (cmd, latencyMs) in slowCmds do
  IO.println s!"Slow: {cmd} took {latencyMs}ms"
```

## Testing Support

### In-Memory Mock

The `MockRedis` structure provides an in-memory Redis implementation for testing without a live server.

```lean
import RedisTests

open Redis

def testExample : IO Unit := do
  -- Create mock instance
  let mock ← MockRedis.create

  -- Use mock directly (not through RedisM)
  mock.set "key" "value".toUTF8
  let value ← mock.get "key"

  -- Supports all basic operations
  let _ ← mock.lpush "list" ["a".toUTF8, "b".toUTF8]
  let _ ← mock.sadd "set" "member".toUTF8
  let _ ← mock.hset "hash" "field" "value".toUTF8

  -- Key expiration
  mock.setex "temp" "data".toUTF8 60
  let ttl ← mock.ttl "temp"

  -- Pattern matching
  let keys ← mock.keys "user:*"

  -- Cleanup
  mock.flushall
```

### Test Fixtures

```lean
import RedisTests

open Redis.Fixtures

-- Generate unique keys to avoid test collisions
let key ← uniqueKey "test"  -- e.g., "test:1234567890:42"

-- Generate multiple unique keys
let keys ← uniqueKeys "test" 5

-- Random data generation
let bytes ← randomBytes 32
let str ← randomString 16
let num ← randomInt (-100) 100

-- Automatic cleanup with withTestKeys
withTestKeys ["key1", "key2"] (do
  set "key1" "value1".toUTF8
  set "key2" "value2".toUTF8
  -- keys are automatically deleted after this block
)

-- Or with auto-generated unique key
withUniqueKey "test" fun key => do
  set key "value".toUTF8
  let v ← get key
  -- key is automatically cleaned up
```

### Test Suite Runner

```lean
let suite : TestSuite := {
  name := "Redis Operations"
  tests := [
    ("SET/GET works", do
      let mock ← MockRedis.create
      mock.set "k" "v".toUTF8
      let v ← mock.get "k"
      assertTrue (v == some "v".toUTF8)
    ),
    ("INCR increments", do
      let mock ← MockRedis.create
      let v1 ← mock.incr "counter"
      let v2 ← mock.incr "counter"
      assertEqual v1 1
      assertEqual v2 2
    )
  ]
}

let allPassed ← runTestSuite suite
-- Output:
-- === Redis Operations ===
-- ✓ SET/GET works (0ms)
-- ✓ INCR increments (0ms)
-- Results: 2 passed, 0 failed
```

## Mathlib Integration

The `RedisLean.Mathlib` module provides Redis-backed features designed for Lean theorem prover and Mathlib development workflows.

### Features Overview

| Module | Purpose |
|--------|---------|
| **TacticCache** | Cache elaboration results to speed up repeated tactic applications |
| **TheoremSearch** | Type-indexed search for theorems by conclusion, hypotheses, or name |
| **Declaration** | Store and query Lean declarations with dependency tracking |
| **InstanceCache** | Cache type class instance synthesis results |
| **ProofState** | Snapshot and replay proof states for time-travel debugging |
| **DistProof** | Coordinate distributed proof checking across multiple workers |

### Tactic Caching

Cache elaboration results to avoid redundant computation:

```lean
import RedisLean.Mathlib

open Redis Redis.Mathlib

def example : RedisM Unit := do
  let cache := TacticCache.create "myproject" 3600  -- 1 hour TTL

  -- Cache a tactic elaboration result
  let syntaxHash : UInt64 := hashSyntax stx
  let result ← cache.getOrElaborate syntaxHash (elaborate stx)

  -- Get cache statistics
  let stats ← cache.getStats
  IO.println s!"Hit rate: {TacticCache.hitRate stats}%"

  -- Invalidate cache for a specific module
  let deleted ← cache.invalidateModule "MyProject.Tactics"
```

### Theorem Search

Search for theorems by their type structure:

```lean
open Redis.Mathlib

def example : RedisM Unit := do
  let search := TheoremSearch.create "mathlib"

  -- Index a theorem
  let thm : TheoremInfo := {
    name := "Nat.add_comm"
    moduleName := "Mathlib.Data.Nat.Basic"
    conclusion := .app (.const "Eq") (.app (.const "Nat.add") (.var 0))
    hypotheses := []
    docstring := some "Addition is commutative"
    tags := ["algebra", "nat", "commutative"]
  }
  search.indexTheorem thm

  -- Search by conclusion type
  let results ← search.searchByConclusion (.const "Eq") 20
  for r in results do
    IO.println s!"{r.theoremInfo.name} (score: {r.score})"

  -- Search by name pattern
  let named ← search.searchByName "add_comm" 10

  -- Search by tag
  let tagged ← search.searchByTag "commutative" 50
```

### Declaration Storage

Store Lean declarations with dependency tracking:

```lean
open Redis.Mathlib

def example : RedisM Unit := do
  let storage := DeclStorage.create "mathlib"

  -- Store a declaration
  let decl : SimpleDeclInfo := {
    name := "Nat.succ_pred"
    kind := .theoremDecl
    levelParams := []
    declType := .other "∀ n : Nat, n ≠ 0 → Nat.succ (Nat.pred n) = n"
    value := none
    isUnsafe := false
    moduleName := "Mathlib.Data.Nat.Basic"
    dependencies := ["Nat.pred", "Nat.succ"]
  }
  storage.storeDecl decl

  -- Load a declaration
  let loaded ← storage.loadDecl "Nat.succ_pred"

  -- Query dependencies
  let deps ← storage.getDependencies "Nat.succ_pred"
  let dependents ← storage.getDependents "Nat.succ"

  -- Create environment snapshot
  let snapshot ← storage.createSnapshot "v1.0" ["Nat.succ_pred", "Nat.add_comm"] ["Init"]
```

### Instance Resolution Cache

Cache type class instance synthesis:

```lean
open Redis.Mathlib

def example : RedisM Unit := do
  let cache := InstanceCache.create "mathlib" 7200  -- 2 hour TTL

  -- Create instance key
  let key := InstanceKey.make "Add" (.const "Nat")

  -- Cache or retrieve instance
  let result ← cache.getOrSynthesize key (synthesizeInstance "Add" "Nat")

  -- Invalidate instances for a class
  let deleted ← cache.invalidateClass "Add"

  -- Get statistics
  let stats ← cache.getStats
  IO.println s!"Classes cached: {stats.classCount}"
```

### Proof State Snapshots

Enable time-travel debugging for proof development:

```lean
open Redis.Mathlib

def example : RedisM Unit := do
  let config := ProofState.createConfig "debug" 86400  -- 24 hour TTL

  -- Start a proof session
  let session ← ProofState.startSession config "my_theorem" (.const "Prop")

  -- Record proof steps
  let snapshot : ProofSnapshot := {
    stepId := 0
    goals := [{ mvarId := 1, userName := "h", goalType := .const "True", localContext := [] }]
    tactic := "intro h"
    parentStep := none
    timestamp := 0
  }
  ProofState.recordStep config session snapshot

  -- Navigate proof history
  let allSteps ← ProofState.getAllSteps config session.sessionId
  let parentStep ← ProofState.getParentStep config session.sessionId 5
  let path ← ProofState.getPathToStep config session.sessionId 10

  -- End session
  ProofState.endSession config session true
```

### Distributed Proof Checking

Coordinate parallel proof checking across workers:

```lean
open Redis.Mathlib

def example : RedisM Unit := do
  let config := DistProof.createConfig "mathlib"

  -- Initialize job queue with modules
  let modules : List Module := [
    { name := "Data.Nat.Basic", dependencies := [], complexity := 10, sourcePath := "..." },
    { name := "Data.List.Basic", dependencies := ["Data.Nat.Basic"], complexity := 20, sourcePath := "..." }
  ]
  DistProof.initializeJobs config modules

  -- Register a worker
  let worker : Worker := {
    workerId := "worker-1"
    host := "localhost"
    startedAt := 0
    lastHeartbeat := 0
    claimedJobs := []
  }
  DistProof.registerWorker config worker

  -- Claim a job (respects dependencies)
  match ← DistProof.claimJob config "worker-1" with
  | some job =>
    IO.println s!"Claimed: {job.jobModule.name}"
    -- Do the work...
    DistProof.updateProgress config job.jobId 50
    DistProof.completeJob config job.jobId true
  | none =>
    IO.println "No jobs available"

  -- Monitor progress
  let progress ← DistProof.getProgress config
  IO.println s!"Completed: {progress.completed}/{progress.totalModules}"

  -- Handle stale workers
  let requeued ← DistProof.requeueStaleJobs config
```

### Key Naming Conventions

All Mathlib integration keys use a hierarchical namespace:

| Pattern | Type | Description |
|---------|------|-------------|
| `{prefix}:tactic:{hash}` | String | Cached elaboration results |
| `{prefix}:tactic:stats:*` | String | Hit/miss counters |
| `{prefix}:thm:name:{name}` | String | Theorem metadata |
| `{prefix}:thm:index:concl:{hash}` | Sorted Set | Theorems by conclusion type |
| `{prefix}:thm:index:hyp:{hash}` | Sorted Set | Theorems by hypothesis type |
| `{prefix}:decl:{name}` | Hash | Declaration data |
| `{prefix}:decl:deps:{name}` | Set | Forward dependencies |
| `{prefix}:decl:rdeps:{name}` | Set | Reverse dependencies |
| `{prefix}:instance:{class}:{type}` | String | Cached instance |
| `{prefix}:proof:session:{id}` | String | Session metadata |
| `{prefix}:proof:step:{id}:{n}` | String | Proof state at step N |
| `{prefix}:dist:jobs` | Sorted Set | Job queue by priority |
| `{prefix}:dist:lock:{module}` | String | Distributed lock |

## Dependencies

- `zlogLean` - Structured logging
- `arrowLean` - Arrow columnar data (for RedisArrow module)
- `Cli` - CLI argument parsing
- `LSpec` - Testing framework
