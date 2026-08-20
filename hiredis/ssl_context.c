// Connection wrapper for redis-lean.
//
// A connection is handed to Lean as an *external object*, not as a raw pointer
// boxed in a UInt64. That matters for two reasons:
//
//   * Lean code cannot fabricate one. A `Redis.FFI.Ctx` can only come from a
//     successful connect, so there is no way to hand these functions an
//     arbitrary integer and have it dereferenced.
//
//   * Lifetime is the GC's job. `l_hiredis_close` releases the socket and the
//     SSL context but never frees the wrapper struct itself, so the `closed`
//     flag stays readable for as long as any Lean reference survives. The
//     struct is freed by the finalizer, once the last reference is gone.
//
// Closing is therefore idempotent and safe to interleave with use: a call on a
// closed connection returns a proper error instead of touching freed memory.

#include <pthread.h>

typedef struct {
    redisContext* redis;
    redisSSLContext* ssl;  // NULL for non-SSL connections
    int closed;            // socket + SSL context released; struct still alive
} RedisConnection;

// ============================================================================
// GC Finalizer Registration
// ============================================================================

// Release the socket and SSL context. Idempotent. Does NOT free `conn`.
static void redis_connection_close(RedisConnection* conn) {
    if (conn && !conn->closed) {
        conn->closed = 1;
        if (conn->redis) {
            redisFree(conn->redis);
            conn->redis = NULL;
        }
        if (conn->ssl) {
            redisFreeSSLContext(conn->ssl);
            conn->ssl = NULL;
        }
    }
}

// Called by Lean's GC when the last reference to the connection is dropped.
static void redis_connection_finalizer(void* ptr) {
    if (ptr) {
        RedisConnection* conn = (RedisConnection*)ptr;
        redis_connection_close(conn);
        free(conn);
    }
}

// No nested Lean objects to traverse
static void redis_connection_foreach(void* ptr, b_lean_obj_arg f) {
    (void)ptr;
    (void)f;
}

// Singleton external class for RedisConnection
static lean_external_class* g_redis_connection_class = NULL;
static pthread_once_t g_redis_connection_class_once = PTHREAD_ONCE_INIT;

static void register_redis_connection_class(void) {
    g_redis_connection_class = lean_register_external_class(
        redis_connection_finalizer,
        redis_connection_foreach
    );
}

static lean_external_class* get_redis_connection_class(void) {
    pthread_once(&g_redis_connection_class_once, register_redis_connection_class);
    return g_redis_connection_class;
}

// ============================================================================
// Validation Macros
// ============================================================================

// Use at the start of every FFI function that takes a connection. `ctx_obj` is
// the borrowed Lean external object; `ctx_var` is bound to the live
// `redisContext*`.
#define VALIDATE_REDIS_CTX(ctx_var, ctx_obj) \
    RedisConnection* ctx_var##_conn = \
        (RedisConnection*)lean_get_external_data(ctx_obj); \
    if (ctx_var##_conn == NULL) { \
        return lean_io_result_mk_error( \
            mk_redis_connect_error_other("Invalid context: null connection")); \
    } \
    if (ctx_var##_conn->closed) { \
        return lean_io_result_mk_error( \
            mk_redis_connect_error_other("Connection is closed")); \
    } \
    if (ctx_var##_conn->redis == NULL) { \
        return lean_io_result_mk_error( \
            mk_redis_connect_error_other("Invalid context: redis context is null")); \
    } \
    redisContext* ctx_var = ctx_var##_conn->redis;

// Same, but binds the wrapper rather than the redisContext, and tolerates a
// closed connection (for operations that only inspect state).
#define GET_REDIS_CONN(conn_var, ctx_obj) \
    RedisConnection* conn_var = \
        (RedisConnection*)lean_get_external_data(ctx_obj); \
    if (conn_var == NULL) { \
        return lean_io_result_mk_error( \
            mk_redis_connect_error_other("Invalid context: null connection")); \
    }

// ============================================================================
// Helper Functions
// ============================================================================

// Create a new RedisConnection wrapper
static RedisConnection* create_redis_connection(redisContext* redis, redisSSLContext* ssl) {
    RedisConnection* conn = (RedisConnection*)malloc(sizeof(RedisConnection));
    if (conn) {
        conn->redis = redis;
        conn->ssl = ssl;
        conn->closed = 0;
    }
    return conn;
}

// Wrap a RedisConnection in a Lean external object, registering it with the GC.
static lean_object* mk_redis_connection_external(RedisConnection* conn) {
    return lean_alloc_external(get_redis_connection_class(), (void*)conn);
}
