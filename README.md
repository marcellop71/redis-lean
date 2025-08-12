# redis-lean

> ⚠️ **Warning**: this is work in progress, it is still incomplete and it ~~may~~ will contain errors

## AI Assistance Disclosure

Parts of this repository were created with assistance from AI-powered coding tools, specifically Claude by Anthropic. All generated code has been reviewed and adapted by the author. Design choices, architectural decisions, and final validation were performed independently by the author.

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

Please remark:

- client **[wrapping](hiredis/README.md)** just *hiredis* synchronous APIs
- *Redis* is huge and not all the commands have been wrapped and inserted into the high-level interface (anyway, a generic low-level way to send arbitrary commands is available)
- no SSL/TLS support, no password support
- no full support for some command options (for example: the basic SET command has also a GET option which is not covered)
- testing is still to be developed (also in relation
to the abstract model)
- this repo include some simple **[examples](Examples/README.md)** about how to use the client lib

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
│   └── Metrics.lean      # Performance metrics
├── RedisArrow/
│   ├── Table.lean        # Arrow table storage in Redis
│   └── Stream.lean       # Stream-to-Arrow micro-batching
├── RedisModel/
│   └── AbstractMinimal.lean  # Formal Redis model
├── Examples/
│   └── ...               # Usage examples
├── Tests/
│   └── ...               # Test suite
├── hiredis/
│   └── shim.c            # C FFI shim
├── docs/
│   └── STREAMS.md        # Streams documentation
├── RedisLean.lean        # Main module
├── RedisArrow.lean       # Arrow integration module
├── RedisModel.lean       # Model module
└── lakefile.lean
```

## Dependencies

- `zlogLean` - Structured logging
- `arrowLean` - Arrow columnar data (for RedisArrow module)
- `Cli` - CLI argument parsing
- `LSpec` - Testing framework
