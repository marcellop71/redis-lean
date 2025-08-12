// Async support for redis-lean
// Implements basic async patterns without full event loop integration
// For full async, consider using with external event loop

#include <poll.h>

// Non-blocking connect
lean_obj_res l_hiredis_connect_nonblock(b_lean_obj_arg host, uint32_t port, lean_obj_arg w) {
    const char* h = lean_string_cstr(host);

    redisContext* c = redisConnectNonBlock(h, (int)port);

    if (c == NULL) {
        lean_object* error = mk_redis_connect_error_other("Non-blocking connection allocation failed");
        return lean_io_result_mk_error(error);
    }

    // Note: For non-blocking, c->err might be set temporarily
    // during connection establishment
    if (c->err && c->err != REDIS_ERR_IO) {
        lean_object* error = mk_redis_error_from_context(c);
        redisFree(c);
        return lean_io_result_mk_error(error);
    }

    RedisConnection* conn = create_redis_connection(c, NULL);
    if (!conn) {
        redisFree(c);
        lean_object* error = mk_redis_connect_error_other("Failed to allocate connection wrapper");
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)conn));
}

// Check if there's data available to read (non-blocking check)
lean_obj_res l_hiredis_can_read(uint64_t ctx, uint64_t timeout_ms, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    if (c->fd <= 0) {
        lean_object* error = mk_redis_connect_error_other("Invalid file descriptor");
        return lean_io_result_mk_error(error);
    }

    struct pollfd pfd;
    pfd.fd = c->fd;
    pfd.events = POLLIN;
    pfd.revents = 0;

    int result = poll(&pfd, 1, (int)timeout_ms);

    if (result < 0) {
        lean_object* error = mk_redis_connect_error_io("poll failed");
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(result > 0 && (pfd.revents & POLLIN)));
}

// Check if we can write (non-blocking check)
lean_obj_res l_hiredis_can_write(uint64_t ctx, uint64_t timeout_ms, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    if (c->fd <= 0) {
        lean_object* error = mk_redis_connect_error_other("Invalid file descriptor");
        return lean_io_result_mk_error(error);
    }

    struct pollfd pfd;
    pfd.fd = c->fd;
    pfd.events = POLLOUT;
    pfd.revents = 0;

    int result = poll(&pfd, 1, (int)timeout_ms);

    if (result < 0) {
        lean_object* error = mk_redis_connect_error_io("poll failed");
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(result > 0 && (pfd.revents & POLLOUT)));
}

// Buffer write - send pending data in output buffer
lean_obj_res l_hiredis_buffer_write(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    int done = 0;
    int result = redisBufferWrite(c, &done);

    if (result == REDIS_ERR) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(done));
}

// Buffer read - read data into input buffer
lean_obj_res l_hiredis_buffer_read(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    int result = redisBufferRead(c);

    if (result == REDIS_ERR) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

// Try to get a reply from the input buffer (non-blocking)
lean_obj_res l_hiredis_get_reply_nonblock(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);
    redisReply* reply = NULL;

    // First try to read from buffer
    if (redisGetReplyFromReader(c, (void**)&reply) == REDIS_ERR) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    if (reply == NULL) {
        // No complete reply in buffer - return None
        return lean_io_result_mk_ok(lean_box(0)); // None
    }

    // Convert reply to ByteArray
    lean_object* result_obj;

    if (reply->type == REDIS_REPLY_ERROR) {
        lean_object* error = mk_redis_reply_error(reply->str);
        freeReplyObject(reply);
        return lean_io_result_mk_error(error);
    }

    switch (reply->type) {
        case REDIS_REPLY_STRING:
        case REDIS_REPLY_STATUS:
            result_obj = lean_mk_empty_byte_array(lean_box(reply->len));
            memcpy(lean_sarray_cptr(result_obj), reply->str, reply->len);
            break;

        case REDIS_REPLY_INTEGER: {
            char buf[32];
            int len = snprintf(buf, sizeof(buf), "%lld", reply->integer);
            result_obj = lean_mk_empty_byte_array(lean_box(len));
            memcpy(lean_sarray_cptr(result_obj), buf, len);
            break;
        }

        case REDIS_REPLY_NIL:
            result_obj = lean_mk_empty_byte_array(lean_box(0));
            break;

        default:
            result_obj = lean_mk_empty_byte_array(lean_box(0));
            break;
    }

    freeReplyObject(reply);

    // Return Some result
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, result_obj);
    return lean_io_result_mk_ok(some);
}

// Set non-blocking mode
lean_obj_res l_hiredis_set_nonblock(uint64_t ctx, uint8_t nonblock, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    int flags = c->flags;
    if (nonblock) {
        flags |= REDIS_BLOCK;  // Actually this disables blocking
    } else {
        flags &= ~REDIS_BLOCK;
    }
    c->flags = flags;

    return lean_io_result_mk_ok(lean_box(0));
}
