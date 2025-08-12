// sscan :: UInt64 -> ByteArray -> UInt64 -> Option ByteArray -> Option UInt64 -> EIO Error (UInt64 × List ByteArray)
// Incrementally iterate set members
// cursor: the cursor position (0 to start)
// pattern: optional MATCH pattern
// count: optional COUNT hint
lean_obj_res l_hiredis_sscan(uint64_t ctx, b_lean_obj_arg key, uint64_t cursor, b_lean_obj_arg pattern_opt, b_lean_obj_arg count_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  const char* argv[8];
  size_t argvlen[8];
  int argc = 3;

  argv[0] = "SSCAN";
  argvlen[0] = 5;
  argv[1] = k;
  argvlen[1] = k_len;

  char cursor_str[32];
  snprintf(cursor_str, sizeof(cursor_str), "%lu", (unsigned long)cursor);
  argv[2] = cursor_str;
  argvlen[2] = strlen(cursor_str);

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

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SSCAN returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_ARRAY && r->elements >= 2) {
    // Reply is [cursor, [members...]]
    redisReply* cursor_reply = r->element[0];
    redisReply* members_reply = r->element[1];

    uint64_t new_cursor = 0;
    if (cursor_reply->type == REDIS_REPLY_STRING && cursor_reply->str) {
      new_cursor = strtoull(cursor_reply->str, NULL, 10);
    }

    lean_object* members_list = lean_box(0);
    if (members_reply->type == REDIS_REPLY_ARRAY) {
      for (int i = (int)members_reply->elements - 1; i >= 0; i--) {
        redisReply* member = members_reply->element[i];
        if (member->type == REDIS_REPLY_STRING && member->str) {
          lean_object* byte_array = lean_alloc_sarray(1, member->len, member->len);
          memcpy(lean_sarray_cptr(byte_array), member->str, member->len);
          lean_object* list_node = lean_alloc_ctor(1, 2, 0);
          lean_ctor_set(list_node, 0, byte_array);
          lean_ctor_set(list_node, 1, members_list);
          members_list = list_node;
        }
      }
    }

    lean_object* tuple = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(tuple, 0, lean_box_uint64(new_cursor));
    lean_ctor_set(tuple, 1, members_list);

    freeReplyObject(r);
    return lean_io_result_mk_ok(tuple);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SSCAN returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
