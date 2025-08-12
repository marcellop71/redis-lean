// Connection timeout support for redis-lean
// Implements redisConnectWithTimeout and redisSetTimeout

// Connect with timeout (in milliseconds)
lean_obj_res l_hiredis_connect_with_timeout(b_lean_obj_arg host, uint32_t port, uint64_t timeout_ms, lean_obj_arg w) {
    const char* h = lean_string_cstr(host);

    struct timeval tv;
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;

    redisContext* c = redisConnectWithTimeout(h, (int)port, tv);

    if (c == NULL) {
        lean_object* error = mk_redis_connect_error_other("Connection allocation failed");
        return lean_io_result_mk_error(error);
    }

    if (c->err) {
        lean_object* error = mk_redis_error_from_context(c);
        redisFree(c);
        return lean_io_result_mk_error(error);
    }

    // Wrap in connection struct (no SSL)
    RedisConnection* conn = create_redis_connection(c, NULL);
    if (!conn) {
        redisFree(c);
        lean_object* error = mk_redis_connect_error_other("Failed to allocate connection wrapper");
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)conn));
}

// Set command timeout on existing connection (in milliseconds)
lean_obj_res l_hiredis_set_timeout(uint64_t ctx, uint64_t timeout_ms, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    struct timeval tv;
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;

    int result = redisSetTimeout(c, tv);

    if (result != REDIS_OK) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

// Enable TCP keepalive
lean_obj_res l_hiredis_enable_keepalive(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    int result = redisEnableKeepAlive(c);

    if (result != REDIS_OK) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

// Set TCP keepalive interval (seconds)
lean_obj_res l_hiredis_set_keepalive_interval(uint64_t ctx, int32_t interval_sec, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    int result = redisEnableKeepAliveWithInterval(c, interval_sec);

    if (result != REDIS_OK) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(0));
}
