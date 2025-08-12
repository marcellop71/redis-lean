# RedisLean

A high-performance Redis client for Lean 4, built on the proven **hiredis** C library with a clean monadic interface inspired by Haskell's **Hedis**.

### Key Features

- 🔒 **Type Safety**: Leverage Lean's type system for compile-time guarantees
- 📦 **Binary Data**: Full support for binary data including embedded NULs  
- 🧮 **Monadic Interface**: Clean composition using `do` notation
- ⚡ **Performance**: Built on battle-tested hiredis C library
- 🔄 **Resource Safety**: Automatic connection management and cleanup
- 📊 **Metrics Collection**: Built-in latency and error tracking
- 🎯 **Extensible**: Easy to add new Redis commands and operations

## Installation

For detailed installation instructions including prerequisites and platform-specific setup, see [install.md](install.md).

### Quick Start

```lean
import RedisLean.Ops
import RedisLean.Log

open RedisLean

def demo : IO Unit := do
  let result ← runRedis {} do
    -- Basic operations
    set "greeting" "Hello, Redis!"
    let msg ← getAs String "greeting"
    Log.info s!"Retrieved: {msg}"
    
    -- Type-safe operations
    set "counter" (42 : Nat)
    let count ← getAs Nat "counter"
    Log.info s!"Counter: {count}"
    
    -- Set operations
    sadd "fruits" "apple"
    sadd "fruits" "banana"
    let size ← scard "fruits"
    Log.info s!"Set size: {size}"
    
    -- Key management
    let exists ← existsKey "greeting"
    let deleted ← del ["greeting"]
    Log.info s!"Deleted {deleted} keys"
  
  match result with
  | Except.ok _ => Log.info "Demo completed successfully!"
  | Except.error e => Log.error s!"Demo failed: {e}"
```

## Core API

### Connection Management

```lean
-- Automatic connection management with default config
runRedis {} computation

-- With custom configuration
let config : Env := { 
  host := "127.0.0.1", 
  port := 6379,
  metrics := { enabled := true }
}
runRedis config computation
```

### Basic Operations

```lean
-- Key-value operations
set : String → α → Redis Unit                    -- [Codec α]
get : String → Redis ByteArray                   -- Raw ByteArray
getAs : (α : Type) → String → Redis α            -- [Codec α] 
del : List String → Redis UInt64
existsKey : String → Redis Bool

-- Conditional set operations  
setnx : String → α → Redis Unit                  -- Set if not exists
setxx : String → α → Redis Unit                  -- Set if exists

-- Numeric operations
incr : String → Redis Int
incrBy : String → Int → Redis Int
decr : String → Redis Int
```

### Set Operations

```lean
-- Redis set operations
sadd : String → String → Redis UInt64            -- Add member to set
sismember : String → String → Redis Bool         -- Check membership
scard : String → Redis UInt64                    -- Get set cardinality
```

### Data Types

The library supports automatic codec-based serialization:

```lean
-- String data
set "user:name" "Alice"
let name ← getAs String "user:name"

-- Numeric types
set "user:age" (25 : Nat)
set "score" (-10 : Int)  
set "active" true
let age ← getAs Nat "user:age"
let score ← getAs Int "score"
let active ← getAs Bool "active"

-- Raw binary data
let raw ← get "binary:data"  -- Returns ByteArray directly
```

### Error Handling

The Redis monad provides comprehensive error handling:

```lean
-- Try-catch pattern (recommended)
def safeOperation : Redis Unit := do
  try
    set "key" "value"
    let result ← getAs String "key"
    Log.info s!"Success: {result}"
  catch e =>
    Log.error s!"Redis error: {e}"

-- The Redis monad is: ReaderT Env (ExceptT RedisError IO)
-- Errors are automatically propagated unless caught
```

### Metrics and Logging

```lean
-- Built-in metrics collection
let config : Env := { 
  metrics := { 
    enabled := true,
    latencyThresholdMs := 100 
  }
}

-- Comprehensive logging
Log.info "Operation completed"
Log.error "Connection failed"
Log.warn "High latency detected"

-- In FFI context
Log.EIO.info "FFI operation started"
Log.EIO.error "FFI operation failed"
```

## Architecture

The library follows a layered architecture:

```
┌─────────────────────────────────────┐
│   High-Level API (Ops.lean)        │  ← Redis monad operations
├─────────────────────────────────────┤
│   Type System (Codec.lean)         │  ← Automatic serialization  
├─────────────────────────────────────┤
│   Redis Monad (Monad.lean)         │  ← Error handling + metrics
├─────────────────────────────────────┤  
│   FFI Bindings (FFI.lean)          │  ← Low-level C interface
├─────────────────────────────────────┤
│   C Implementation (c/*.c)         │  ← hiredis integration
└─────────────────────────────────────┘
```

**Key Components:**

- **`Monad.lean`**: Core Redis monad with metrics integration
- **`Ops.lean`**: High-level typed operations (get, set, sadd, etc.)
- **`FFI.lean`**: Low-level bindings with direct ByteArray handling  
- **`Codec.lean`**: Type-safe serialization for String, Nat, Int, Bool
- **`Error.lean`**: Comprehensive error types and handling
- **`Metrics.lean`**: Performance monitoring and latency tracking
- **`Log.lean`**: Structured logging for both Redis and EIO contexts

**Data Flow:**
```
Lean Types → Codec → Redis Monad → FFI → C → hiredis → Redis
```

## FFI Layer

For performance-critical applications, use the FFI layer directly:

```lean
import RedisLean.FFI

def directFFI : EIO RedisError Unit := do
  FFI.withRedis "127.0.0.1" 6379 fun ctx => do
    let key := String.toUTF8 "direct"
    let value := String.toUTF8 "data"
    
    try
      FFI.set ctx key value
      let result ← FFI.get ctx key
      let retrieved := String.fromUTF8! result
      Log.EIO.info s!"Retrieved: {retrieved}"
    catch e =>
      Log.EIO.error s!"Error: {e}"
```

## Examples

The `Examples/` directory contains comprehensive usage patterns:

### **FFI Examples** (`Examples/FFI/`)
Direct FFI usage for maximum performance:
- `Set.lean` - Basic set operations, NX/XX options
- `Get.lean` - Key retrieval with error handling  
- `SAdd.lean` - Redis set operations
- `Del.lean` - Key deletion and existence checking

### **Monadic Examples** (`Examples/Monadic/`)  
High-level monadic interface with type safety:
- `Set.lean` - Type-safe operations with String, Nat, Int, Bool
- `Get.lean` - Automatic codec handling and error recovery
- `SAdd.lean` - Set operations with membership testing
- `Del.lean` - Safe deletion with comprehensive error handling

Each example follows the `ex0`/`ex1`/`ex2` pattern for progressive learning.

## Performance and Safety

**Type Safety Features:**
- Compile-time guarantees for Redis operations
- Automatic serialization/deserialization via Codec instances
- Proper error handling with the Redis monad

**Performance Optimizations:**
- Direct hiredis C library integration
- Minimal FFI overhead
- Built-in metrics for performance monitoring
- Automatic connection management

**Memory Safety:**
- Automatic resource cleanup via `runRedis` and `FFI.withRedis`  
- No manual memory management required
- Safe ByteArray handling for binary data

## Configuration

```lean
structure Env where
  host : String := "127.0.0.1"
  port : Nat := 6379
  metrics : MetricsConfig := { enabled := false }
  ctx : Ctx := arbitrary  -- Internal FFI context

structure MetricsConfig where  
  enabled : Bool := false
  latencyThresholdMs : Nat := 100
```

## Strongly typed operations

A Lean term that can be encoded as a ByteArray may be stored in Redis as the value of a key. But what about its Lean type? (Here “Lean type” is distinct from the Redis type. For example, in Lean we might have a Nat, whereas in Redis it may be stored as an integer represented as a string.)

The Lean type information may be lost. While we can always retrieve the serialized ByteArray for the term, recovering the original Lean type require to include the type (say, its name) explicitly in the serialization.

To preserve type information, the client could:
decorate the Redis key with the type (e.g., key:{type}),
store a companion key containing the type, or
embed the term in a JSON object with a schema that records the type and other metadata.

Correspondingly, the "get" APIs should be designed to align with this approach.

## Future Enhancements

- broader coverage of Redis commands
- richer Config options with built-in validation
- more comprehensive examples
- expanded monadic wrapper (to match the full FFI surface)
- connection Pooling: efficient management of multiple connections
- support for the cluster protocol
- integration with Redis Streams
- support for MULTI/EXEC transactions
- pipelining: batched command execution
- pure Lean: direct RESP communication over TCP sockets (no external client)
- interaction with Lean proof states
- strongly typed set/get operations

## The Redis Monad Transformer

To interact with Redis from Lean, we wrap computations in a dedicated **Redis monad transformer**. This provides a uniform way to handle environment access and error reporting.

```lean
abbrev RedisT (m : Type → Type) := ReaderT Env (ExceptT RedisError m)
abbrev Result (α : Type) := Except RedisError α
abbrev Redis (α : Type) := RedisT IO α
```

### What this means
- `m : Type → Type` is a *type constructor*.  
  When we write `m α`, it means “a value of type `α` living in the computational context `m`.”  
  This context is often described as an *effect* (e.g., `Option`, `List`, `Reader`, `IO`), but it’s better understood as a computational setting or container, not necessarily a side effect.

- `RedisT m α` is a computation that:  
  1. has access to a Redis **environment** (`Env`),  
  2. may fail with a `RedisError`, and  
  3. eventually returns a value of type `α` in some base monad `m`.  

- `Redis α` is just `RedisT IO α`: the concrete instantiation of the Redis monad transformer on top of `IO`.  

- `Result α = Except RedisError α` is the pure, non-monadic result type: either a successful value or an error.  

### Why not just `EIO`?
Lean’s FFI often uses `EIO`, a built-in monad for IO computations that can fail with an error:  

```lean
EIO ε α ≡ EStateM ε IO.RealWorld α
IO α     ≡ EStateM IO.Error IO.RealWorld α
```

So `IO α` is really `EIO IO.Error α`. But our Redis stack expects:  

```lean
ExceptT RedisError IO α
≡ ExceptT RedisError (EStateM IO.Error IO.RealWorld) α
```

That is, Redis computations carry their own error type `RedisError` via `ExceptT`, instead of reusing `IO.Error`.  

### Bridging the gap
Even though `EIO RedisError α` is definitionally equivalent to `ExceptT RedisError IO α`, Lean doesn’t coerce between them automatically. That’s why we need an explicit conversion function (often called `eioToExceptT`) to move from `EIO` to our `Redis` monad stack.  

This explicit layering:  
- keeps Redis errors distinct from general IO errors,  
- makes error handling clearer, and  
- avoids confusion when mixing Lean’s FFI (`EIO`) with Redis computations (`ExceptT`).  
