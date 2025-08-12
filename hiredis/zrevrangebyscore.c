// zrevrangebyscore :: UInt64 -> ByteArray -> ByteArray -> ByteArray -> Bool -> Option UInt64 -> Option UInt64 -> EIO Error (List ByteArray)
// Get members with scores between max and min (high to low)
lean_obj_res l_hiredis_zrevrangebyscore(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg max, b_lean_obj_arg min, uint8_t withscores, b_lean_obj_arg offset_opt, b_lean_obj_arg count_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* max_str = (const char*)lean_sarray_cptr(max);
  size_t max_len = lean_sarray_size(max);
  const char* min_str = (const char*)lean_sarray_cptr(min);
  size_t min_len = lean_sarray_size(min);

  const char* argv[9];
  size_t argvlen[9];
  int argc = 4;

  argv[0] = "ZREVRANGEBYSCORE";
  argvlen[0] = 16;
  argv[1] = k;
  argvlen[1] = k_len;
  argv[2] = max_str;
  argvlen[2] = max_len;
  argv[3] = min_str;
  argvlen[3] = min_len;

  if (withscores) {
    argv[argc] = "WITHSCORES";
    argvlen[argc] = 10;
    argc++;
  }

  char offset_str[32];
  char count_str[32];
  if (!lean_is_scalar(offset_opt) && !lean_is_scalar(count_opt)) {
    uint64_t offset = lean_unbox_uint64(lean_ctor_get(offset_opt, 0));
    uint64_t count = lean_unbox_uint64(lean_ctor_get(count_opt, 0));
    argv[argc] = "LIMIT";
    argvlen[argc] = 5;
    argc++;
    snprintf(offset_str, sizeof(offset_str), "%lu", (unsigned long)offset);
    argv[argc] = offset_str;
    argvlen[argc] = strlen(offset_str);
    argc++;
    snprintf(count_str, sizeof(count_str), "%lu", (unsigned long)count);
    argv[argc] = count_str;
    argvlen[argc] = strlen(count_str);
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZREVRANGEBYSCORE returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "ZREVRANGEBYSCORE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
