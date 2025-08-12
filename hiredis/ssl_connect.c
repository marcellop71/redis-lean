// SSL connection implementation for redis-lean

// Thread-safe OpenSSL initialization flag
static int ssl_initialized = 0;

// Initialize OpenSSL (call once, thread-safe for single-threaded Lean)
static int ensure_ssl_initialized(void) {
    if (!ssl_initialized) {
        redisInitOpenSSL();
        ssl_initialized = 1;
    }
    return 1;
}

// Helper to extract C string from Lean Option String
// Returns NULL for none, C string pointer for some
static const char* option_string_to_cstr(lean_object* opt) {
    // Check if it's none (scalar/boxed 0)
    if (lean_obj_tag(opt) == 0) {
        // none case
        return NULL;
    }
    // some case - extract the string from constructor field 0
    lean_object* str = lean_ctor_get(opt, 0);
    return lean_string_cstr(str);
}

// Plain (non-SSL) connect - now returns RedisConnection wrapper
lean_obj_res l_hiredis_connect(b_lean_obj_arg host, uint32_t port, lean_obj_arg w) {
    const char* h = lean_string_cstr(host);
    redisContext* c = redisConnect(h, (int)port);

    if (c == NULL) {
        lean_object* error = mk_redis_connect_error_other("alloc/connect returned NULL");
        return lean_io_result_mk_error(error);
    }
    if (c->err) {
        lean_object* error = mk_redis_error_from_context(c);
        redisFree(c);
        return lean_io_result_mk_error(error);
    }

    // Create wrapper struct (NULL ssl for non-SSL connection)
    RedisConnection* conn = create_redis_connection(c, NULL);
    if (!conn) {
        redisFree(c);
        lean_object* error = mk_redis_connect_error_other("Failed to allocate connection wrapper");
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)conn));
}

// SSL connect
lean_obj_res l_hiredis_connect_ssl(
    b_lean_obj_arg host,
    uint32_t port,
    b_lean_obj_arg cacert_path_opt,
    b_lean_obj_arg ca_path_opt,
    b_lean_obj_arg cert_path_opt,
    b_lean_obj_arg key_path_opt,
    b_lean_obj_arg server_name_opt,
    uint8_t verify_mode,
    lean_obj_arg w
) {
    // Initialize OpenSSL
    if (!ensure_ssl_initialized()) {
        return lean_io_result_mk_error(mk_ssl_init_failed("Failed to initialize OpenSSL"));
    }

    const char* h = lean_string_cstr(host);
    const char* cacert = option_string_to_cstr(cacert_path_opt);
    const char* capath = option_string_to_cstr(ca_path_opt);
    const char* cert = option_string_to_cstr(cert_path_opt);
    const char* key = option_string_to_cstr(key_path_opt);
    const char* sni = option_string_to_cstr(server_name_opt);

    // Create SSL context
    redisSSLContextError ssl_error = REDIS_SSL_CTX_NONE;
    redisSSLContext* ssl_ctx = redisCreateSSLContext(
        cacert,     // CA cert file
        capath,     // CA path (directory)
        cert,       // client cert
        key,        // client key
        sni,        // server name for SNI
        &ssl_error
    );

    if (!ssl_ctx) {
        const char* err_msg = ssl_ctx_error_string(ssl_error);
        return lean_io_result_mk_error(mk_ssl_context_creation_failed(err_msg));
    }

    // Connect to Redis
    redisContext* c = redisConnect(h, (int)port);
    if (c == NULL) {
        redisFreeSSLContext(ssl_ctx);
        return lean_io_result_mk_error(mk_redis_connect_error_other("Failed to connect"));
    }
    if (c->err) {
        lean_object* error = mk_redis_error_from_context(c);
        redisFree(c);
        redisFreeSSLContext(ssl_ctx);
        return lean_io_result_mk_error(error);
    }

    // Initiate SSL handshake
    if (redisInitiateSSLWithContext(c, ssl_ctx) != REDIS_OK) {
        char err_buf[512];
        snprintf(err_buf, sizeof(err_buf), "SSL handshake failed: %s", c->errstr);
        redisFree(c);
        redisFreeSSLContext(ssl_ctx);
        return lean_io_result_mk_error(mk_ssl_handshake_failed(err_buf));
    }

    // Create wrapper struct with SSL context
    RedisConnection* conn = create_redis_connection(c, ssl_ctx);
    if (!conn) {
        redisFree(c);
        redisFreeSSLContext(ssl_ctx);
        return lean_io_result_mk_error(mk_redis_connect_error_other("Failed to allocate connection wrapper"));
    }

    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)conn));
}

// Updated free function - handles both plain and SSL connections
// Now idempotent: safe to call multiple times
lean_obj_res l_hiredis_free(uint64_t ctx, lean_obj_arg w) {
    if (ctx == 0) {
        return lean_io_result_mk_ok(lean_box(0));
    }

    RedisConnection* conn = (RedisConnection*)ctx;

    // Check if already freed (idempotent)
    if (conn->freed) {
        return lean_io_result_mk_ok(lean_box(0));
    }

    // Mark as freed FIRST to prevent double-free race
    conn->freed = 1;

    // Free resources
    if (conn->redis) {
        redisFree(conn->redis);
        conn->redis = NULL;
    }
    if (conn->ssl) {
        redisFreeSSLContext(conn->ssl);
        conn->ssl = NULL;
    }

    // Free the wrapper struct
    free(conn);

    return lean_io_result_mk_ok(lean_box(0));
}
