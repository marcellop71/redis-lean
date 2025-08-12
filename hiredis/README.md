# Redis-Lean C Wrappers

This directory contains C wrapper functions that provide a Foreign Function Interface (FFI) between Lean 4 and the hiredis Redis client library. Each Redis command is implemented as a separate C file following a consistent pattern.

## Architecture Overview

The wrapper system consists of:

1. **Individual command files** (e.g., `set.c`, `get.c`, `hset.c`) - Each implements a specific Redis command
2. **Error handling** (`errors.c`) - Centralized Redis error type constructors
3. **Connection management** (`connect.c`) - Redis context creation and cleanup
4. **Main shim file** (`shim.c`) - Includes all wrapper files and provides necessary headers

## Wrapper Construction Pattern

All Redis command wrappers follow a consistent structure:

### 1. Function Signature
```c
lean_obj_res l_hiredis_<command>(uint64_t ctx, <parameters>, lean_obj_arg w)
```

- `ctx`: Redis context (cast from `redisContext*`)
- `<parameters>`: Command-specific parameters (keys, values, options)
- `w`: Lean world token (for IO sequencing)
- Returns: `lean_obj_res` containing either result or error

### 2. Parameter Extraction
```c
redisContext* c = (redisContext*)ctx;
const char* k = (const char*)lean_sarray_cptr(key);
size_t k_len = lean_sarray_size(key);
```

ByteArray parameters are extracted to C strings with explicit length handling.

### 3. Redis Command Execution
```c
const char* argv[] = {"COMMAND", arg1, arg2, ...};
size_t argvlen[] = {command_len, arg1_len, arg2_len, ...};
redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
```

Uses `redisCommandArgv` for binary-safe command execution with explicit argument lengths.

### 4. Response Processing
Handles different Redis reply types:

- **REDIS_REPLY_STRING**: String responses → ByteArray
- **REDIS_REPLY_INTEGER**: Numeric responses → UInt64
- **REDIS_REPLY_ARRAY**: List responses → List ByteArray
- **REDIS_REPLY_STATUS**: Status responses (e.g., "OK")
- **REDIS_REPLY_NIL**: Null responses → Error or empty result
- **REDIS_REPLY_ERROR**: Redis errors → RedisError

### 5. Error Handling
```c
if (r->type == REDIS_REPLY_ERROR && r->str) {
    if (strstr(r->str, "WRONGTYPE") != NULL) {
        // Handle type mismatch errors
    }
    // Handle other Redis errors
}
```

Specific error patterns are detected and converted to appropriate Lean error types.

### 6. Memory Management
```c
freeReplyObject(r);
return lean_io_result_mk_ok(result);
```

All Redis reply objects must be freed, and results are wrapped in Lean's IO result type.

## Command Categories

### String Operations
- `set.c`, `get.c`, `setex.c`: Basic key-value operations
- `incr.c`, `decr.c`: Numeric increment/decrement operations

### Hash Operations
- `hset.c`, `hget.c`, `hgetall.c`: Hash field operations
- `hdel.c`, `hexists.c`: Hash field management
- `hincrby.c`: Hash field numeric operations
- `hkeys.c`: Hash introspection

### Set Operations
- `sadd.c`, `scard.c`: Set membership operations
- `sismember.c`: Set membership testing

### Sorted Set Operations
- `zadd.c`: Add scored members to sorted sets
- `zcard.c`: Get sorted set cardinality
- `zrange.c`: Retrieve sorted set ranges

### Utility Operations
- `exists.c`, `type.c`, `ttl.c`: Key introspection
- `del.c`: Key deletion
- `keys.c`: Key pattern matching
- `ping.c`: Connection testing
- `flushall.c`: Database clearing
- `publish.c`: Pub/Sub messaging
- `command.c`: Generic command execution

## Type Mapping

| Lean Type | C Type | Redis Type | Usage |
|-----------|--------|------------|-------|
| `ByteArray` | `const char*` + `size_t` | String | Keys, values, members |
| `UInt64` | `uint64_t` | Integer | Counts, IDs, timestamps |
| `Int64` | `int64_t` | Integer | Signed numbers, indices |
| `Float` | `double` | Float | Scores, numeric values |
| `String` | `const char*` | String | Commands, simple text |
| `List ByteArray` | Linked list | Array | Multiple values |
| `Bool` | `int` (0/1) | Integer | Boolean results |

## Error Types

The error handling system provides specific error types:

- `keyNotFoundError`: Key doesn't exist
- `noExpiryDefinedError`: No TTL set on key
- `nullReplyError`: Unexpected null response
- `replyError`: Generic Redis error
- `unexpectedReplyTypeError`: Wrong response type

## Adding New Commands

To add a new Redis command wrapper:

1. **Create the wrapper file**: `<command>.c`
2. **Follow the pattern**: Use existing wrappers as templates
3. **Add to shim**: Include the file in `shim.c`
4. **Add FFI binding**: Add extern declaration in `FFI.lean`
5. **Add helper function**: Add convenience wrapper in `FFI.lean`

### Example Template
```c
// command :: UInt64 -> ByteArray -> EIO RedisError ReturnType
lean_obj_res l_hiredis_command(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  redisContext* c = (redisContext*)ctx;
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  const char* argv[2] = {"COMMAND", k};
  size_t argvlen[2] = {7, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("COMMAND returned NULL");
    return lean_io_result_mk_error(error);
  }

  // Process response based on expected type
  // Handle errors appropriately
  // Free reply object
  // Return result
}
```

## Build Integration

The wrappers are compiled as part of the Lean package build system. The `shim.c` file serves as the main compilation unit that includes all individual wrapper files, ensuring they're compiled together with proper header dependencies.
