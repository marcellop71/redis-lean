# Redis-Lean Examples

Focused examples demonstrating Redis operations using the redis-lean library. Examples are organized into two complementary approaches showcasing different levels of abstraction and control.

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

**Example structure:**
Each FFI example contains 3 focused functions:
- `ex0` - Basic operations demonstrating core functionality
- `ex1` - Intermediate patterns with multiple operations
- `ex2` - Advanced scenarios with error handling

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

**Example structure:**
Each Monadic example contains focused functions:
- `ex0` - Basic operations with try-catch error handling
- `ex1` - Type-safe operations or membership testing
- `ex2` - Advanced patterns like multiple sets or team management

## 🚀 Quick Start

### Prerequisites
```bash
# Ensure Redis server is running
redis-server

# Or start with Docker
docker run -d -p 6379:6379 redis:latest
```

### Running Examples

**Individual example files:**
```bash
# FFI examples
lake exe Examples/FFI/Set.lean
lake exe Examples/FFI/Get.lean
lake exe Examples/FFI/SAdd.lean
lake exe Examples/FFI/Del.lean

# Monadic examples  
lake exe Examples/Monadic/Set.lean
lake exe Examples/Monadic/Get.lean
lake exe Examples/Monadic/SAdd.lean
lake exe Examples/Monadic/Del.lean
```

## 📚 Learning Path

### 🟢 Beginners
1. **Start with Monadic examples** - safer and more intuitive
2. **Begin with `Set.lean` and `Get.lean`** - core Redis operations
3. **Study the `ex0` functions** - basic patterns with error handling

### 🟡 Intermediate  
1. **Compare equivalent operations** across FFI and Monadic examples
2. **Explore `SAdd.lean`** - Redis set data structures
3. **Study `ex1` and `ex2` functions** - advanced patterns

### 🔴 Advanced
1. **Deep dive into FFI examples** - performance optimization
2. **Understand ByteArray handling** - binary data operations
3. **Build custom operations** using FFI as foundation

## ⚙️ Key Differences

| Aspect | FFI | Monadic |
|--------|-----|---------|
| **Type Safety** | Manual ByteArray handling | Automatic codec conversion |
| **Error Handling** | Explicit try-catch | Built-in Redis monad |
| **Resource Management** | `FFI.withRedis` wrapper | Automatic via `runRedis` |
| **Performance** | Maximum efficiency | Optimized with safety |
| **Data Types** | ByteArray only | String, Nat, Int, Bool |
| **Connection** | Manual context passing | Environment-based |

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
      Log.EIO.info s!"✓ retrieved: {retrieved}"
    catch e =>
      Log.EIO.error s!"✗ error: {e}"
```

### Monadic Pattern  
```lean
def ex0 : Redis Unit := do
  try
    set "example" "data"
    let result ← getAs String "example"
    Log.info s!"✓ retrieved: {result}"
  catch e =>
    Log.error s!"✗ error: {e}"
```

## 🔍 Example Details

### Set Operations
- **FFI**: NX/XX options, manual ByteArray conversion, explicit context
- **Monadic**: Type-safe set/get, setnx/setxx helpers, automatic codec handling

### Get Operations  
- **FFI**: Direct ByteArray results, manual UTF-8 conversion, explicit error handling
- **Monadic**: Typed retrieval with `getAs`, automatic deserialization, built-in error management

### Set Operations (SAdd)
- **FFI**: Manual member addition, explicit cardinality checks, ByteArray member handling
- **Monadic**: Clean set operations, automatic type handling, simplified membership testing

### Delete Operations
- **FFI**: Batch deletion with ByteArray keys, manual existence checking
- **Monadic**: Type-safe deletion, automatic error recovery, simplified patterns

## ⚠️ Safety Guidelines

- **Use prefixed keys** to avoid conflicts between examples
- **Examples include proper error handling** demonstrating exception management
- **FFI examples use `FFI.withRedis`** for automatic connection cleanup
- **Monadic examples use `runRedis`** with built-in resource management
- **Test with dedicated Redis instance** when learning

## 🤝 Contributing

When adding examples:

1. **Follow the ex0/ex1/ex2 pattern** - focused, progressive complexity
2. **Include comprehensive error handling** with try-catch blocks
3. **Use descriptive logging** - show operation and result
4. **Document key concepts** in comments
5. **Test both success and error scenarios**
6. **Maintain consistency** between FFI and Monadic approaches

## 📖 See Also

- **Main documentation** - `../README.md` for library overview
- **Implementation details** - `../RedisLean/` module source code
- **API reference** - `../RedisLean/Ops.lean` for monadic operations
- **FFI layer** - `../RedisLean/FFI.lean` for low-level bindings
