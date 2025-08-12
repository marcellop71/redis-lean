// spop :: UInt64 -> ByteArray -> Option UInt64 -> EIO Error (List ByteArray)
// Remove and return random members from a set
lean_obj_res l_hiredis_spop(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg count_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  redisReply* r;

  if (lean_is_scalar(count_opt)) {
    const char* argv[2] = {"SPOP", k};
    size_t argvlen[2] = {4, k_len};
    r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  } else {
    uint64_t count = lean_unbox_uint64(lean_ctor_get(count_opt, 0));
    char count_str[32];
    snprintf(count_str, sizeof(count_str), "%lu", (unsigned long)count);

    const char* argv[3] = {"SPOP", k, count_str};
    size_t argvlen[3] = {4, k_len, strlen(count_str)};
    r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);
  }

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SPOP returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* result_list;

  if (r->type == REDIS_REPLY_NIL) {
    result_list = lean_box(0);
  } else if (r->type == REDIS_REPLY_STRING && r->str) {
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
    snprintf(error_msg, sizeof(error_msg), "SPOP returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(result_list);
}
