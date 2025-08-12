// Reconnection support for redis-lean

// Reconnect using the same connection parameters
lean_obj_res l_hiredis_reconnect(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    int result = redisReconnect(c);

    if (result != REDIS_OK) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

// Check if connection is still alive (using PING)
lean_obj_res l_hiredis_is_connected(uint64_t ctx, lean_obj_arg w) {
    if (ctx == 0) {
        return lean_io_result_mk_ok(lean_box(0)); // false
    }

    VALIDATE_REDIS_CTX(c, ctx);

    // Check for errors on the context
    if (c->err) {
        return lean_io_result_mk_ok(lean_box(0)); // false
    }

    // Check file descriptor
    if (c->fd <= 0) {
        return lean_io_result_mk_ok(lean_box(0)); // false
    }

    return lean_io_result_mk_ok(lean_box(1)); // true
}

// Get the file descriptor for the connection
lean_obj_res l_hiredis_get_fd(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);
    return lean_io_result_mk_ok(lean_box_uint32((uint32_t)c->fd));
}

// Get the connection error string (if any)
lean_obj_res l_hiredis_get_error(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    if (c->err) {
        lean_object* str = lean_mk_string(c->errstr);
        lean_object* some = lean_alloc_ctor(1, 1, 0);
        lean_ctor_set(some, 0, str);
        return lean_io_result_mk_ok(some);
    }

    // none
    return lean_io_result_mk_ok(lean_box(0));
}

// Clear the error state
lean_obj_res l_hiredis_clear_error(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);
    c->err = 0;
    c->errstr[0] = '\0';
    return lean_io_result_mk_ok(lean_box(0));
}
