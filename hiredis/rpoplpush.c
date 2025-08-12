// rpoplpush :: UInt64 -> ByteArray -> ByteArray -> EIO Error ByteArray
// Pop from tail of source and push to head of destination (deprecated, use LMOVE)
lean_obj_res l_hiredis_rpoplpush(uint64_t ctx, b_lean_obj_arg src, b_lean_obj_arg dst, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* s = (const char*)lean_sarray_cptr(src);
  size_t s_len = lean_sarray_size(src);
  const char* d = (const char*)lean_sarray_cptr(dst);
  size_t d_len = lean_sarray_size(dst);

  const char* argv[3] = {"RPOPLPUSH", s, d};
  size_t argvlen[3] = {9, s_len, d_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("RPOPLPUSH returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "RPOPLPUSH returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
