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

The library provides comprehensive coverage of ~155 Redis commands:

### String Operations (21 commands)
- `set.c`, `get.c`, `setex.c`, `psetex.c`: Basic key-value operations
- `append.c`, `getdel.c`, `getex.c`, `getrange.c`, `getset.c`: Extended get/set
- `incr.c`, `decr.c`, `incrbyfloat.c`: Numeric operations
- `mget.c`, `mset.c`, `msetnx.c`: Multi-key operations
- `setnx.c`, `setrange.c`, `strlen.c`, `lcs.c`: Additional string operations

### Key Operations (19 commands)
- `exists.c`, `type.c`, `del.c`: Basic key operations
- `ttl.c`, `keys.c`, `scan.c`: Key introspection
- `expire.c`, `expireat.c`, `pexpire.c`, `pexpireat.c`: Expiration management
- `persist.c`, `expiretime.c`: TTL management
- `rename.c`, `renamenx.c`, `copy.c`: Key manipulation
- `unlink.c`, `touch.c`, `randomkey.c`: Additional key operations

### List Operations (22 commands)
- `lpush.c`, `rpush.c`, `lpushx.c`, `rpushx.c`: Push operations
- `lpop.c`, `rpop.c`: Pop operations
- `lrange.c`, `lindex.c`, `llen.c`: List access
- `lset.c`, `linsert.c`, `ltrim.c`, `lrem.c`: List modification
- `lpos.c`, `lmove.c`, `lmpop.c`: Advanced list operations
- `blpop.c`, `brpop.c`, `blmove.c`, `blmpop.c`: Blocking operations
- `rpoplpush.c`, `brpoplpush.c`: Atomic move operations

### Set Operations (17 commands)
- `sadd.c`, `scard.c`, `sismember.c`, `smembers.c`: Basic set operations
- `srem.c`, `spop.c`, `srandmember.c`: Set removal/random
- `smove.c`, `smismember.c`: Member management
- `sdiff.c`, `sdiffstore.c`: Set difference
- `sinter.c`, `sinterstore.c`, `sintercard.c`: Set intersection
- `sunion.c`, `sunionstore.c`: Set union
- `sscan.c`: Set iteration

### Hash Operations (16 commands)
- `hset.c`, `hget.c`, `hgetall.c`: Basic hash operations
- `hdel.c`, `hexists.c`: Hash field management
- `hincrby.c`, `hincrbyfloat.c`: Numeric operations
- `hkeys.c`, `hvals.c`, `hlen.c`: Hash introspection
- `hsetnx.c`, `hmget.c`, `hmset.c`: Extended operations
- `hstrlen.c`, `hrandfield.c`, `hscan.c`: Advanced operations

### Sorted Set Operations (33 commands)
- `zadd.c`, `zcard.c`, `zrange.c`: Basic sorted set operations
- `zscore.c`, `zrank.c`, `zrevrank.c`: Member scoring/ranking
- `zcount.c`, `zlexcount.c`: Counting operations
- `zincrby.c`, `zrem.c`: Member modification
- `zrangebyscore.c`, `zrevrange.c`, `zrevrangebyscore.c`: Range queries
- `zrangebylex.c`, `zrevrangebylex.c`: Lexicographic queries
- `zremrangebyrank.c`, `zremrangebyscore.c`, `zremrangebylex.c`: Range removal
- `zpopmin.c`, `zpopmax.c`, `bzpopmin.c`, `bzpopmax.c`: Pop operations
- `zunionstore.c`, `zinterstore.c`, `zdiffstore.c`: Set operations
- `zunion.c`, `zinter.c`, `zdiff.c`, `zintercard.c`: In-memory set operations
- `zmscore.c`, `zrandmember.c`, `zscan.c`, `zrangestore.c`: Advanced operations

### Stream Operations (7 commands)
- `xadd.c`, `xread.c`, `xreadgroup.c`: Stream write/read
- `xrange.c`, `xlen.c`: Stream access
- `xdel.c`, `xtrim.c`: Stream management

### HyperLogLog Operations (3 commands)
- `pfadd.c`, `pfcount.c`, `pfmerge.c`: Probabilistic counting

### Geospatial Operations (6 commands)
- `geoadd.c`, `geodist.c`, `geohash.c`, `geopos.c`: Basic geo operations
- `geosearch.c`, `geosearchstore.c`: Geo search operations

### Bitmap Operations (5 commands)
- `setbit.c`, `getbit.c`: Bit manipulation
- `bitcount.c`, `bitop.c`, `bitpos.c`: Bitmap operations

### Transaction Operations (5 commands)
- `multi.c`, `exec.c`, `discard.c`: Transaction control
- `watch.c`, `unwatch.c`: Optimistic locking

### Scripting Operations (6 commands)
- `eval.c`, `evalsha.c`: Script execution
- `scriptload.c`, `scriptexists.c`, `scriptflush.c`, `scriptkill.c`: Script management

### Pub/Sub Operations (2 commands)
- `publish.c`, `subscribe.c`: Messaging

### Connection Operations (15 commands)
- `auth.c`, `hello.c`, `ping.c`: Authentication/protocol
- `clientid.c`, `clientgetname.c`, `clientsetname.c`: Client identification
- `clientlist.c`, `clientinfo.c`, `clientkill.c`: Client management
- `clientpause.c`, `clientunpause.c`: Client control
- `select.c`, `echo.c`, `quit.c`, `reset.c`: Connection control

### Server Operations (19 commands)
- `info.c`, `dbsize.c`, `flushall.c`: Database info
- `lastsave.c`, `bgsave.c`, `bgrewriteaof.c`: Persistence
- `time.c`: Server time
- `configget.c`, `configset.c`, `configrewrite.c`, `configresetstat.c`: Configuration
- `memoryusage.c`: Memory analysis
- `objectencoding.c`, `objectidletime.c`, `objectfreq.c`: Object inspection
- `slowlogget.c`, `slowloglen.c`, `slowlogreset.c`: Slow log
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
