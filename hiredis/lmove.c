// lmove :: UInt64 -> ByteArray -> ByteArray -> UInt8 -> UInt8 -> EIO Error ByteArray
// Move element from source to destination
// srcDir: 0 = LEFT, 1 = RIGHT
// dstDir: 0 = LEFT, 1 = RIGHT
lean_obj_res l_hiredis_lmove(uint64_t ctx, b_lean_obj_arg src, b_lean_obj_arg dst, uint8_t srcDir, uint8_t dstDir, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* s = (const char*)lean_sarray_cptr(src);
  size_t s_len = lean_sarray_size(src);
  const char* d = (const char*)lean_sarray_cptr(dst);
  size_t d_len = lean_sarray_size(dst);

  const char* src_dir = srcDir == 0 ? "LEFT" : "RIGHT";
  const char* dst_dir = dstDir == 0 ? "LEFT" : "RIGHT";
  size_t src_dir_len = srcDir == 0 ? 4 : 5;
  size_t dst_dir_len = dstDir == 0 ? 4 : 5;

  const char* argv[5] = {"LMOVE", s, d, src_dir, dst_dir};
  size_t argvlen[5] = {5, s_len, d_len, src_dir_len, dst_dir_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 5, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("LMOVE returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    lean_object* error = mk_redis_key_not_found_error(s);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else if (r->type == REDIS_REPLY_STRING && r->str) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    out = byte_array;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "LMOVE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
