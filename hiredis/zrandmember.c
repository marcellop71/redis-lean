// zrandmember :: UInt64 -> ByteArray -> Option Int64 -> Bool -> EIO Error (List ByteArray)
// Get random members from a sorted set
// count: if provided, return count members; if negative, can return duplicates
// withscores: if true, return member-score pairs as flat list
lean_obj_res l_hiredis_zrandmember(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg count_opt, uint8_t withscores, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  const char* argv[4];
  size_t argvlen[4];
  int argc = 2;

  argv[0] = "ZRANDMEMBER";
  argvlen[0] = 11;
  argv[1] = k;
  argvlen[1] = k_len;

  char count_str[32];
  if (!lean_is_scalar(count_opt)) {
    int64_t count = (int64_t)lean_unbox_uint64(lean_ctor_get(count_opt, 0));
    snprintf(count_str, sizeof(count_str), "%ld", (long)count);
    argv[argc] = count_str;
    argvlen[argc] = strlen(count_str);
    argc++;

    if (withscores) {
      argv[argc] = "WITHSCORES";
      argvlen[argc] = 10;
      argc++;
    }
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZRANDMEMBER returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* result_list;

  if (r->type == REDIS_REPLY_NIL) {
    result_list = lean_box(0);
  } else if (r->type == REDIS_REPLY_STRING && r->str) {
    // Single member (no count specified)
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    lean_object* list_node = lean_alloc_ctor(1, 2, 0);
    lean_ctor_set(list_node, 0, byte_array);
    lean_ctor_set(list_node, 1, lean_box(0));
    result_list = list_node;
  } else if (r->type == REDIS_REPLY_ARRAY) {
    result_list = lean_box(0);
    for (int i = (int)r->elements - 1; i >= 0; i--) {
      redisReply* element = r->element[i];
      if (element->type == REDIS_REPLY_STRING && element->str) {
        lean_object* byte_array = lean_alloc_sarray(1, element->len, element->len);
        memcpy(lean_sarray_cptr(byte_array), element->str, element->len);
        lean_object* list_node = lean_alloc_ctor(1, 2, 0);
        lean_ctor_set(list_node, 0, byte_array);
        lean_ctor_set(list_node, 1, result_list);
        result_list = list_node;
      }
    }
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZRANDMEMBER returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(result_list);
}
