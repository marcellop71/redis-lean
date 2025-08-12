// SSL context wrapper structure for redis-lean
// Holds both redisContext and redisSSLContext together
// Includes safety features: freed flag, GC finalizer, validation

typedef struct {
    redisContext* redis;
    redisSSLContext* ssl;  // NULL for non-SSL connections
    int freed;             // Safety: track if connection has been freed
} RedisConnection;

// ============================================================================
// GC Finalizer Registration
// ============================================================================

// Destructor called by Lean's GC when object is collected
static void redis_connection_finalizer(void* ptr) {
    if (ptr) {
        RedisConnection* conn = (RedisConnection*)ptr;
        if (!conn->freed) {
            conn->freed = 1;
            if (conn->redis) {
                redisFree(conn->redis);
                conn->redis = NULL;
            }
            if (conn->ssl) {
                redisFreeSSLContext(conn->ssl);
                conn->ssl = NULL;
            }
        }
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

static lean_external_class* get_redis_connection_class(void) {
    if (!g_redis_connection_class) {
        g_redis_connection_class = lean_register_external_class(
            redis_connection_finalizer,
            redis_connection_foreach
        );
    }
    return g_redis_connection_class;
}

// ============================================================================
// Validation Macro
// ============================================================================

// Use this macro at the start of every FFI function that takes a context
// It validates the pointer and checks if the connection has been freed
#define VALIDATE_REDIS_CTX(ctx_var, conn_ptr) \
    if ((conn_ptr) == 0) { \
        return lean_io_result_mk_error( \
            mk_redis_connect_error_other("Invalid context: null pointer")); \
    } \
    RedisConnection* ctx_var##_conn = (RedisConnection*)(conn_ptr); \
    if (ctx_var##_conn->freed) { \
        return lean_io_result_mk_error( \
            mk_redis_connect_error_other("Connection already freed")); \
    } \
    if (ctx_var##_conn->redis == NULL) { \
        return lean_io_result_mk_error( \
            mk_redis_connect_error_other("Invalid context: redis context is null")); \
    } \
    redisContext* ctx_var = ctx_var##_conn->redis;

// Simpler validation that just gets the connection struct
#define GET_REDIS_CONN(conn_var, conn_ptr) \
    if ((conn_ptr) == 0) { \
        return lean_io_result_mk_error( \
            mk_redis_connect_error_other("Invalid context: null pointer")); \
    } \
    RedisConnection* conn_var = (RedisConnection*)(conn_ptr); \
    if (conn_var->freed) { \
        return lean_io_result_mk_error( \
            mk_redis_connect_error_other("Connection already freed")); \
    }

// ============================================================================
// Helper Functions
// ============================================================================

// Helper to extract redis context from wrapper (legacy, use VALIDATE_REDIS_CTX instead)
static inline redisContext* get_redis_ctx(uint64_t conn_ptr) {
    if (conn_ptr == 0) return NULL;
    RedisConnection* conn = (RedisConnection*)conn_ptr;
    if (conn->freed) return NULL;
    return conn->redis;
}

// Helper to check if connection is SSL
static inline int is_ssl_connection(uint64_t conn_ptr) {
    if (conn_ptr == 0) return 0;
    RedisConnection* conn = (RedisConnection*)conn_ptr;
    if (conn->freed) return 0;
    return conn->ssl != NULL;
}

// Create a new RedisConnection wrapper
static RedisConnection* create_redis_connection(redisContext* redis, redisSSLContext* ssl) {
    RedisConnection* conn = (RedisConnection*)malloc(sizeof(RedisConnection));
    if (conn) {
        conn->redis = redis;
        conn->ssl = ssl;
        conn->freed = 0;  // Initialize as not freed
    }
    return conn;
}

// Free a RedisConnection wrapper and its contents (manual free, also used by finalizer)
static void free_redis_connection(RedisConnection* conn) {
    if (conn) {
        if (!conn->freed) {
            conn->freed = 1;
            if (conn->redis) {
                redisFree(conn->redis);
                conn->redis = NULL;
            }
            if (conn->ssl) {
                redisFreeSSLContext(conn->ssl);
                conn->ssl = NULL;
            }
        }
        free(conn);
    }
}

// Create a Lean external object wrapping a RedisConnection
// This registers the connection with Lean's GC for automatic cleanup
static lean_object* mk_redis_connection_external(RedisConnection* conn) {
    return lean_alloc_external(get_redis_connection_class(), (void*)conn);
}

// Extract RedisConnection from Lean external object
static inline RedisConnection* get_redis_connection_from_external(lean_object* obj) {
    return (RedisConnection*)lean_get_external_data(obj);
}
