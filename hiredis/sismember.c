// sismember :: UInt64 -> ByteArray -> ByteArray -> EIO RedisError Bool
lean_obj_res l_hiredis_sismember(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg member, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* m = (const char*)lean_sarray_cptr(member);
  size_t m_len = lean_sarray_size(member);
  
  const char* argv[3] = {"SISMEMBER", k, m};
  size_t argvlen[3] = {9, k_len, m_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SISMEMBER returned NULL");
    return lean_io_result_mk_error(error);
  }

  int is_member = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    is_member = (r->integer > 0) ? 1 : 0;
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SISMEMBER returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box(is_member));
}
