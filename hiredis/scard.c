// scard :: UInt64 -> ByteArray -> EIO RedisError UInt64
lean_obj_res l_hiredis_scard(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  const char* argv[2] = {"SCARD", k};
  size_t argvlen[2] = {5, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SCARD returned NULL");
    return lean_io_result_mk_error(error);
  }
  
  uint64_t count = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    count = (uint64_t)r->integer;
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SCARD returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64(count));
}
