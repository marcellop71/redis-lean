// Pipeline support for redis-lean
// Implements true pipelining with redisAppendCommand and redisGetReply

// Append a whole command line to the output buffer (no network round-trip yet).
//
// The line is split into arguments here rather than handed to hiredis as a
// format string. Both of the obvious shortcuts are wrong:
//
//   redisAppendCommand(c, "%s", line)  -- hiredis only splits arguments in the
//       *format*, so `%s` makes the entire line a single argument and Redis
//       answers `ERR unknown command 'SET k v'`.
//
//   redisAppendCommand(c, line)        -- splits correctly, but then a `%` in
//       user data is read as a conversion specifier against an empty va_list.
//
// Prefer l_hiredis_append_command_argv: it is binary-safe and needs no quoting.
lean_obj_res l_hiredis_append_command(b_lean_obj_arg ctx, b_lean_obj_arg command, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);
    const char* cmd = lean_string_cstr(command);

    char** argv = NULL;
    size_t* argvlen = NULL;
    int argc = parse_command_args(cmd, &argv, &argvlen);
    if (argc <= 0) {
        lean_object* error = mk_redis_null_reply_error("failed to parse command arguments");
        return lean_io_result_mk_error(error);
    }

    int result = redisAppendCommandArgv(c, argc, (const char**)argv, argvlen);

    free_parsed_args(argv, argc);
    free(argvlen);

    if (result != REDIS_OK) {
        lean_object* error = mk_redis_error_from_context(c);
        return lean_io_result_mk_error(error);
    }

    return lean_io_result_mk_ok(lean_box(0));
}

// Append a command with format string and arguments
lean_obj_res l_hiredis_append_command_argv(b_lean_obj_arg ctx, b_lean_obj_arg args, lean_obj_arg w) {
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
lean_obj_res l_hiredis_get_reply(b_lean_obj_arg ctx, lean_obj_arg w) {
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
            result_obj = lean_alloc_sarray(1, reply->len, reply->len);
            memcpy(lean_sarray_cptr(result_obj), reply->str, reply->len);
            break;

        case REDIS_REPLY_INTEGER: {
            char buf[32];
            int len = snprintf(buf, sizeof(buf), "%lld", reply->integer);
            result_obj = lean_alloc_sarray(1, len, len);
            memcpy(lean_sarray_cptr(result_obj), buf, len);
            break;
        }

        case REDIS_REPLY_NIL:
            result_obj = lean_alloc_sarray(1, 0, 0);
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
                result_obj = lean_alloc_sarray(1, len, len);
                memcpy(lean_sarray_cptr(result_obj), buf, len);
            }
            break;

        case REDIS_REPLY_DOUBLE: {
            char buf[64];
            int len = snprintf(buf, sizeof(buf), "%.17g", reply->dval);
            result_obj = lean_alloc_sarray(1, len, len);
            memcpy(lean_sarray_cptr(result_obj), buf, len);
            break;
        }

        case REDIS_REPLY_BOOL:
            result_obj = lean_alloc_sarray(1, 1, 1);
            ((uint8_t*)lean_sarray_cptr(result_obj))[0] = reply->integer ? '1' : '0';
            break;

        case REDIS_REPLY_BIGNUM:
            result_obj = lean_alloc_sarray(1, reply->len, reply->len);
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
lean_obj_res l_hiredis_get_pending_count(b_lean_obj_arg ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);

    // The output buffer length indicates pending commands
    // This is an approximation - hiredis doesn't expose exact count
    size_t pending = c->obuf ? sdslen(c->obuf) : 0;

    return lean_io_result_mk_ok(lean_box_uint64(pending > 0 ? 1 : 0));
}

// Flush the output buffer (send all pending commands)
lean_obj_res l_hiredis_flush_pipeline(b_lean_obj_arg ctx, lean_obj_arg w) {
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

// Get the next pipelined reply, decoding array-shaped replies.
//
// This is the `get_reply_array` companion that l_hiredis_get_reply's
// ARRAY branch has always pointed at. Returns List (Option ByteArray):
//
//   ARRAY / SET / MAP reply  -> one entry per element, in order:
//       NIL                  -> none
//       STRING/STATUS/VERB   -> some bytes
//       INTEGER              -> some (decimal ASCII)
//       DOUBLE               -> some ("%.17g" ASCII)
//       BIGNUM               -> some bytes
//       nested ARRAY         -> error (flat replies only: HGETALL,
//                               SMEMBERS, HMGET, ZRANGE, LRANGE, ...)
//   scalar reply             -> singleton list (NIL -> [none]), so one
//                               drain loop can read a mixed pipeline.
//   ERROR reply              -> Lean error (consume-and-raise; the
//                               caller's drain must keep reading the
//                               remaining replies, same contract as
//                               l_hiredis_get_reply).
static lean_object* pipeline_element_to_option(redisReply* element, int* err) {
    lean_object* payload = NULL;
    char buf[64];
    switch (element->type) {
        case REDIS_REPLY_NIL:
            return lean_box(0); // none
        case REDIS_REPLY_STRING:
        case REDIS_REPLY_STATUS:
        case REDIS_REPLY_VERB:
        case REDIS_REPLY_BIGNUM:
            payload = lean_alloc_sarray(1, element->len, element->len);
            memcpy(lean_sarray_cptr(payload), element->str, element->len);
            break;
        case REDIS_REPLY_INTEGER: {
            int len = snprintf(buf, sizeof(buf), "%lld", element->integer);
            payload = lean_alloc_sarray(1, len, len);
            memcpy(lean_sarray_cptr(payload), buf, len);
            break;
        }
        case REDIS_REPLY_DOUBLE: {
            int len = snprintf(buf, sizeof(buf), "%.17g", element->dval);
            payload = lean_alloc_sarray(1, len, len);
            memcpy(lean_sarray_cptr(payload), buf, len);
            break;
        }
        case REDIS_REPLY_BOOL: {
            payload = lean_alloc_sarray(1, 1, 1);
            ((uint8_t*)lean_sarray_cptr(payload))[0] = element->integer ? '1' : '0';
            break;
        }
        default:
            *err = 1; // nested array or unknown: unsupported
            return lean_box(0);
    }
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, payload);
    return some;
}

lean_obj_res l_hiredis_get_reply_array(b_lean_obj_arg ctx, lean_obj_arg w) {
    VALIDATE_REDIS_CTX(c, ctx);
    redisReply* reply = NULL;

    int result = redisGetReply(c, (void**)&reply);
    if (result != REDIS_OK || reply == NULL) {
        if (reply) freeReplyObject(reply);
        lean_object* error = c->err ? mk_redis_error_from_context(c)
                                    : mk_redis_null_reply_error("No reply available");
        return lean_io_result_mk_error(error);
    }

    if (reply->type == REDIS_REPLY_ERROR) {
        lean_object* err = mk_redis_reply_error(reply->str);
        freeReplyObject(reply);
        return lean_io_result_mk_error(err);
    }

    lean_object* result_list = lean_box(0); // []
    int bad = 0;

    if (reply->type == REDIS_REPLY_ARRAY || reply->type == REDIS_REPLY_SET ||
        reply->type == REDIS_REPLY_MAP  || reply->type == REDIS_REPLY_PUSH) {
        for (int j = (int)reply->elements - 1; j >= 0 && !bad; j--) {
            lean_object* opt = pipeline_element_to_option(reply->element[j], &bad);
            if (bad) { lean_dec(opt); break; }
            lean_object* cons = lean_alloc_ctor(1, 2, 0);
            lean_ctor_set(cons, 0, opt);
            lean_ctor_set(cons, 1, result_list);
            result_list = cons;
        }
    } else {
        // Scalar reply: singleton, so a mixed pipeline drains uniformly.
        lean_object* opt = pipeline_element_to_option(reply, &bad);
        if (!bad) {
            lean_object* cons = lean_alloc_ctor(1, 2, 0);
            lean_ctor_set(cons, 0, opt);
            lean_ctor_set(cons, 1, result_list);
            result_list = cons;
        }
    }

    freeReplyObject(reply);

    if (bad) {
        lean_dec(result_list);
        lean_object* err = mk_redis_unexpected_reply_type_error(
            "get_reply_array: nested array replies are not supported");
        return lean_io_result_mk_error(err);
    }

    return lean_io_result_mk_ok(result_list);
}
