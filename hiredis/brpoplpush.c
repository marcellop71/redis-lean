// brpoplpush :: UInt64 -> ByteArray -> ByteArray -> Float -> EIO Error (Option ByteArray)
// Blocking pop from tail of source and push to head of destination (deprecated, use BLMOVE)
lean_obj_res l_hiredis_brpoplpush(uint64_t ctx, b_lean_obj_arg src, b_lean_obj_arg dst, double timeout, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* s = (const char*)lean_sarray_cptr(src);
  size_t s_len = lean_sarray_size(src);
  const char* d = (const char*)lean_sarray_cptr(dst);
  size_t d_len = lean_sarray_size(dst);

  char timeout_str[32];
  snprintf(timeout_str, sizeof(timeout_str), "%.3f", timeout);

  const char* argv[4] = {"BRPOPLPUSH", s, d, timeout_str};
  size_t argvlen[4] = {10, s_len, d_len, strlen(timeout_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("BRPOPLPUSH returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    // Timeout - return None
    out = lean_box(0);
  } else if (r->type == REDIS_REPLY_STRING && r->str) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, byte_array);
    out = some;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "BRPOPLPUSH returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
