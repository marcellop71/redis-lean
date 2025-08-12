// Unix socket connection support for redis-lean

// Connect via Unix socket
lean_obj_res l_hiredis_connect_unix(b_lean_obj_arg path, lean_obj_arg w) {
    const char* p = lean_string_cstr(path);

    redisContext* c = redisConnectUnix(p);

    if (c == NULL) {
        lean_object* error = mk_redis_connect_error_other("Unix socket connection allocation failed");
        return lean_io_result_mk_error(error);
    }

    if (c->err) {
        lean_object* error = mk_redis_error_from_context(c);
        redisFree(c);
        return lean_io_result_mk_error(error);
    }

    // Wrap in connection struct (no SSL for Unix sockets)
    RedisConnection* conn = create_redis_connection(c, NULL);
    if (!conn) {
        redisFree(c);
        lean_object* error = mk_redis_connect_error_other("Failed to allocate connection wrapper");
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)conn));
}

// Connect via Unix socket with timeout (in milliseconds)
lean_obj_res l_hiredis_connect_unix_with_timeout(b_lean_obj_arg path, uint64_t timeout_ms, lean_obj_arg w) {
    const char* p = lean_string_cstr(path);

    struct timeval tv;
    tv.tv_sec = timeout_ms / 1000;
    tv.tv_usec = (timeout_ms % 1000) * 1000;

    redisContext* c = redisConnectUnixWithTimeout(p, tv);

    if (c == NULL) {
        lean_object* error = mk_redis_connect_error_other("Unix socket connection allocation failed");
        return lean_io_result_mk_error(error);
    }

    if (c->err) {
        lean_object* error = mk_redis_error_from_context(c);
        redisFree(c);
        return lean_io_result_mk_error(error);
    }

    // Wrap in connection struct (no SSL for Unix sockets)
    RedisConnection* conn = create_redis_connection(c, NULL);
    if (!conn) {
        redisFree(c);
        lean_object* error = mk_redis_connect_error_other("Failed to allocate connection wrapper");
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)conn));
}

// Connect via Unix socket without blocking (for async patterns)
lean_obj_res l_hiredis_connect_unix_nonblock(b_lean_obj_arg path, lean_obj_arg w) {
    const char* p = lean_string_cstr(path);

    redisContext* c = redisConnectUnixNonBlock(p);

    if (c == NULL) {
        lean_object* error = mk_redis_connect_error_other("Unix socket connection allocation failed");
        return lean_io_result_mk_error(error);
    }

    if (c->err) {
        lean_object* error = mk_redis_error_from_context(c);
        redisFree(c);
        return lean_io_result_mk_error(error);
    }

    // Wrap in connection struct
    RedisConnection* conn = create_redis_connection(c, NULL);
    if (!conn) {
        redisFree(c);
        lean_object* error = mk_redis_connect_error_other("Failed to allocate connection wrapper");
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)conn));
}
