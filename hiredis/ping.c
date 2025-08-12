// ping :: UInt64 -> ByteArray -> EIO RedisError Bool
lean_obj_res l_hiredis_ping(uint64_t ctx, b_lean_obj_arg msg, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* m = (const char*)lean_sarray_cptr(msg);
  size_t m_len = lean_sarray_size(msg);
  
  const char* argv[2] = {"PING", m};
  size_t argvlen[2] = {4, m_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("PING returned NULL");
    return lean_io_result_mk_error(error);
  }

  int ok = 0;
  if (r->type == REDIS_REPLY_STRING && r->str && r->len == m_len && memcmp(r->str, m, m_len) == 0) {
    ok = 1;
  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box(ok));
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "PING returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
