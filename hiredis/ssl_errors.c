// SSL error constructors for redis-lean
// Maps to RedisLean.Error.SSLError

// SSLError constructor indices:
// 0 = initFailed
// 1 = contextCreationFailed
// 2 = handshakeFailed

// Error.sslError is at index 1 in the Error enum

static lean_object* mk_ssl_init_failed(const char* msg) {
    lean_object* msg_obj = lean_mk_string(msg);
    lean_object* ssl_err = lean_alloc_ctor(0, 1, 0); // initFailed
    lean_ctor_set(ssl_err, 0, msg_obj);
    lean_object* redis_err = lean_alloc_ctor(1, 1, 0); // sslError (index 1)
    lean_ctor_set(redis_err, 0, ssl_err);
    return redis_err;
}

static lean_object* mk_ssl_context_creation_failed(const char* msg) {
    lean_object* msg_obj = lean_mk_string(msg);
    lean_object* ssl_err = lean_alloc_ctor(1, 1, 0); // contextCreationFailed
    lean_ctor_set(ssl_err, 0, msg_obj);
    lean_object* redis_err = lean_alloc_ctor(1, 1, 0); // sslError (index 1)
    lean_ctor_set(redis_err, 0, ssl_err);
    return redis_err;
}

static lean_object* mk_ssl_handshake_failed(const char* msg) {
    lean_object* msg_obj = lean_mk_string(msg);
    lean_object* ssl_err = lean_alloc_ctor(2, 1, 0); // handshakeFailed
    lean_ctor_set(ssl_err, 0, msg_obj);
    lean_object* redis_err = lean_alloc_ctor(1, 1, 0); // sslError (index 1)
    lean_ctor_set(redis_err, 0, ssl_err);
    return redis_err;
}

// Convert hiredis SSL error code to human-readable message
static const char* ssl_ctx_error_string(redisSSLContextError err) {
    switch (err) {
        case REDIS_SSL_CTX_NONE:
            return "No error";
        case REDIS_SSL_CTX_CREATE_FAILED:
            return "Failed to create SSL_CTX";
        case REDIS_SSL_CTX_CERT_KEY_REQUIRED:
            return "Client certificate and key must both be specified";
        case REDIS_SSL_CTX_CA_CERT_LOAD_FAILED:
            return "Failed to load CA certificate";
        case REDIS_SSL_CTX_CLIENT_CERT_LOAD_FAILED:
            return "Failed to load client certificate";
        case REDIS_SSL_CTX_PRIVATE_KEY_LOAD_FAILED:
            return "Failed to load private key";
        case REDIS_SSL_CTX_OS_CERTSTORE_OPEN_FAILED:
            return "Failed to open OS certificate store";
        case REDIS_SSL_CTX_OS_CERT_ADD_FAILED:
            return "Failed to add certificate from OS store";
        default:
            return "Unknown SSL context error";
    }
}
