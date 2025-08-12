// blmove :: UInt64 -> ByteArray -> ByteArray -> UInt8 -> UInt8 -> Float -> EIO Error (Option ByteArray)
// Blocking move element from source to destination
// srcDir: 0 = LEFT, 1 = RIGHT
// dstDir: 0 = LEFT, 1 = RIGHT
// timeout: seconds to wait (0 = wait indefinitely)
lean_obj_res l_hiredis_blmove(uint64_t ctx, b_lean_obj_arg src, b_lean_obj_arg dst, uint8_t srcDir, uint8_t dstDir, double timeout, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* s = (const char*)lean_sarray_cptr(src);
  size_t s_len = lean_sarray_size(src);
  const char* d = (const char*)lean_sarray_cptr(dst);
  size_t d_len = lean_sarray_size(dst);

  const char* src_dir = srcDir == 0 ? "LEFT" : "RIGHT";
  const char* dst_dir = dstDir == 0 ? "LEFT" : "RIGHT";
  size_t src_dir_len = srcDir == 0 ? 4 : 5;
  size_t dst_dir_len = dstDir == 0 ? 4 : 5;

  char timeout_str[32];
  snprintf(timeout_str, sizeof(timeout_str), "%.3f", timeout);

  const char* argv[6] = {"BLMOVE", s, d, src_dir, dst_dir, timeout_str};
  size_t argvlen[6] = {6, s_len, d_len, src_dir_len, dst_dir_len, strlen(timeout_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 6, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("BLMOVE returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "BLMOVE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
