// scan :: UInt64 -> UInt64 -> Option ByteArray -> Option UInt64 -> Option ByteArray -> EIO Error (UInt64 × List ByteArray)
// Incrementally iterate keys
// cursor: the cursor position (0 to start)
// pattern: optional MATCH pattern
// count: optional COUNT hint
// type: optional TYPE filter
lean_obj_res l_hiredis_scan(uint64_t ctx, uint64_t cursor, b_lean_obj_arg pattern_opt, b_lean_obj_arg count_opt, b_lean_obj_arg type_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  const char* argv[8];
  size_t argvlen[8];
  int argc = 2;

  argv[0] = "SCAN";
  argvlen[0] = 4;

  char cursor_str[32];
  snprintf(cursor_str, sizeof(cursor_str), "%lu", (unsigned long)cursor);
  argv[1] = cursor_str;
  argvlen[1] = strlen(cursor_str);

  if (!lean_is_scalar(pattern_opt)) {
    lean_object* pattern = lean_ctor_get(pattern_opt, 0);
    argv[argc] = "MATCH";
    argvlen[argc] = 5;
    argc++;
    argv[argc] = (const char*)lean_sarray_cptr(pattern);
    argvlen[argc] = lean_sarray_size(pattern);
    argc++;
  }

  char count_str[32];
  if (!lean_is_scalar(count_opt)) {
    uint64_t count = lean_unbox_uint64(lean_ctor_get(count_opt, 0));
    argv[argc] = "COUNT";
    argvlen[argc] = 5;
    argc++;
    snprintf(count_str, sizeof(count_str), "%lu", (unsigned long)count);
    argv[argc] = count_str;
    argvlen[argc] = strlen(count_str);
    argc++;
  }

  if (!lean_is_scalar(type_opt)) {
    lean_object* type = lean_ctor_get(type_opt, 0);
    argv[argc] = "TYPE";
    argvlen[argc] = 4;
    argc++;
    argv[argc] = (const char*)lean_sarray_cptr(type);
    argvlen[argc] = lean_sarray_size(type);
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SCAN returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_ARRAY && r->elements >= 2) {
    redisReply* cursor_reply = r->element[0];
    redisReply* keys_reply = r->element[1];

    uint64_t new_cursor = 0;
    if (cursor_reply->type == REDIS_REPLY_STRING && cursor_reply->str) {
      new_cursor = strtoull(cursor_reply->str, NULL, 10);
    }

    lean_object* keys_list = lean_box(0);
    if (keys_reply->type == REDIS_REPLY_ARRAY) {
      for (int i = (int)keys_reply->elements - 1; i >= 0; i--) {
        redisReply* key = keys_reply->element[i];
        if (key->type == REDIS_REPLY_STRING && key->str) {
          lean_object* byte_array = lean_alloc_sarray(1, key->len, key->len);
          memcpy(lean_sarray_cptr(byte_array), key->str, key->len);
          lean_object* list_node = lean_alloc_ctor(1, 2, 0);
          lean_ctor_set(list_node, 0, byte_array);
          lean_ctor_set(list_node, 1, keys_list);
          keys_list = list_node;
        }
      }
    }

    lean_object* tuple = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(tuple, 0, lean_box_uint64(new_cursor));
    lean_ctor_set(tuple, 1, keys_list);

    freeReplyObject(r);
    return lean_io_result_mk_ok(tuple);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SCAN returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
