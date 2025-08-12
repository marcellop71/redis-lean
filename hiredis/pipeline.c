// Pipeline support for redis-lean
// Implements true pipelining with redisAppendCommand and redisGetReply

// Append a command to the output buffer (no network round-trip yet)
// Returns 0 on success, error code on failure
lean_obj_res l_hiredis_append_command(uint64_t ctx, b_lean_obj_arg command, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);
    const char* cmd = lean_string_cstr(command);

    int result = redisAppendCommand(c, "%s", cmd);

    if (result != REDIS_OK) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

// Append a command with format string and arguments
lean_obj_res l_hiredis_append_command_argv(uint64_t ctx, b_lean_obj_arg args, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    // Count arguments
    lean_object* list = args;
    int argc = 0;
    while (!lean_is_scalar(list)) {
        argc++;
        list = lean_ctor_get(list, 1);
    }

    if (argc == 0) {
        lean_object* error = mk_redis_connect_error_other("Empty command");
        return lean_io_result_mk_error(error);
    }

    // Allocate arrays for argv
    const char** argv = (const char**)malloc(argc * sizeof(char*));
    size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

    if (!argv || !argvlen) {
        if (argv) free(argv);
        if (argvlen) free(argvlen);
        lean_object* error = mk_redis_connect_error_other("Memory allocation failed");
        return lean_io_result_mk_error(error);
    }

    // Fill argv from list
    list = args;
    for (int i = 0; i < argc; i++) {
        lean_object* elem = lean_ctor_get(list, 0);
        argv[i] = (const char*)lean_sarray_cptr(elem);
        argvlen[i] = lean_sarray_size(elem);
        list = lean_ctor_get(list, 1);
    }

    int result = redisAppendCommandArgv(c, argc, argv, argvlen);

    free(argv);
    free(argvlen);

    if (result != REDIS_OK) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

// Get the next reply from the pipeline
// Returns the reply as ByteArray (serialized)
lean_obj_res l_hiredis_get_reply(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);
    redisReply* reply = NULL;

    int result = redisGetReply(c, (void**)&reply);

    if (result != REDIS_OK || reply == NULL) {
        if (reply) freeReplyObject(reply);
        lean_object* error = c->err ? mk_redis_error_from_context(c)
                                    : mk_redis_null_reply_error("No reply available");
        return lean_io_result_mk_error(error);
    }

    // Convert reply to ByteArray based on type
    lean_object* result_obj;

    switch (reply->type) {
        case REDIS_REPLY_STRING:
        case REDIS_REPLY_STATUS:
        case REDIS_REPLY_VERB:
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

        case REDIS_REPLY_ERROR: {
            lean_object* err = mk_redis_reply_error(reply->str);
            freeReplyObject(reply);
            return lean_io_result_mk_error(err);
        }

        case REDIS_REPLY_ARRAY:
        case REDIS_REPLY_SET:
        case REDIS_REPLY_MAP:
        case REDIS_REPLY_PUSH:
            // For arrays, return count as string (caller should use get_reply_array)
            {
                char buf[32];
                int len = snprintf(buf, sizeof(buf), "ARRAY:%zu", reply->elements);
                result_obj = lean_mk_empty_byte_array(lean_box(len));
                memcpy(lean_sarray_cptr(result_obj), buf, len);
            }
            break;

        case REDIS_REPLY_DOUBLE: {
            char buf[64];
            int len = snprintf(buf, sizeof(buf), "%.17g", reply->dval);
            result_obj = lean_mk_empty_byte_array(lean_box(len));
            memcpy(lean_sarray_cptr(result_obj), buf, len);
            break;
        }

        case REDIS_REPLY_BOOL:
            result_obj = lean_mk_empty_byte_array(lean_box(1));
            ((uint8_t*)lean_sarray_cptr(result_obj))[0] = reply->integer ? '1' : '0';
            break;

        case REDIS_REPLY_BIGNUM:
            result_obj = lean_mk_empty_byte_array(lean_box(reply->len));
            memcpy(lean_sarray_cptr(result_obj), reply->str, reply->len);
            break;

        default: {
            freeReplyObject(reply);
            lean_object* err2 = mk_redis_unexpected_reply_type_error("Unknown reply type");
            return lean_io_result_mk_error(err2);
        }
    }

    freeReplyObject(reply);
    return lean_io_result_mk_ok(result_obj);
}

// Get pending reply count (commands sent but not yet read)
lean_obj_res l_hiredis_get_pending_count(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    // The output buffer length indicates pending commands
    // This is an approximation - hiredis doesn't expose exact count
    size_t pending = c->obuf ? sdslen(c->obuf) : 0;

    return lean_io_result_mk_ok(lean_box_uint64(pending > 0 ? 1 : 0));
}

// Flush the output buffer (send all pending commands)
lean_obj_res l_hiredis_flush_pipeline(uint64_t ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    // redisBufferWrite sends pending data
    int done = 0;
    while (!done) {
        if (redisBufferWrite(c, &done) == REDIS_ERR) {
            lean_object* error = mk_redis_error_from_context(c);
            return lean_io_result_mk_error(error);
        }
    }

    return lean_io_result_mk_ok(lean_box(0));
}
