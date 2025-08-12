// getrange :: UInt64 -> ByteArray -> Int64 -> Int64 -> EIO Error ByteArray
// Get a substring of the string stored at key
lean_obj_res l_hiredis_getrange(uint64_t ctx, b_lean_obj_arg key, int64_t start, int64_t end, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  char start_str[32], end_str[32];
  snprintf(start_str, sizeof(start_str), "%ld", (long)start);
  snprintf(end_str, sizeof(end_str), "%ld", (long)end);

  const char* argv[4] = {"GETRANGE", k, start_str, end_str};
  size_t argvlen[4] = {8, k_len, strlen(start_str), strlen(end_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("GETRANGE returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_STRING) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    if (r->len > 0 && r->str) {
      memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    }
    out = byte_array;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "GETRANGE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
