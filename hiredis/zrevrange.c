// zrevrange :: UInt64 -> ByteArray -> Int64 -> Int64 -> Bool -> EIO Error (List ByteArray)
// Get members in a range (high to low)
lean_obj_res l_hiredis_zrevrange(uint64_t ctx, b_lean_obj_arg key, int64_t start, int64_t stop, uint8_t withscores, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  char start_str[32];
  char stop_str[32];
  snprintf(start_str, sizeof(start_str), "%ld", (long)start);
  snprintf(stop_str, sizeof(stop_str), "%ld", (long)stop);

  const char* argv[5];
  size_t argvlen[5];
  int argc = 4;

  argv[0] = "ZREVRANGE";
  argvlen[0] = 9;
  argv[1] = k;
  argvlen[1] = k_len;
  argv[2] = start_str;
  argvlen[2] = strlen(start_str);
  argv[3] = stop_str;
  argvlen[3] = strlen(stop_str);

  if (withscores) {
    argv[argc] = "WITHSCORES";
    argvlen[argc] = 10;
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZREVRANGE returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_ARRAY) {
    lean_object* result_list = lean_box(0);
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
    freeReplyObject(r);
    return lean_io_result_mk_ok(result_list);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZREVRANGE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
