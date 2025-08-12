// xtrim :: UInt64 -> ByteArray -> String -> UInt64 -> EIO RedisError UInt64
// Trim stream to approximately the specified max length
lean_obj_res l_hiredis_xtrim(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg strategy, uint64_t max_len, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* strat = (const char*)lean_sarray_cptr(strategy);
  size_t strat_len = lean_sarray_size(strategy);
  
  // Convert max_len to string
  char max_len_str[32];
  snprintf(max_len_str, sizeof(max_len_str), "%lu", max_len);
  
  // Build command: XTRIM key strategy count
  // Strategy can be "MAXLEN" or "MINID" (we'll support MAXLEN for now)
  const char* argv[4] = {"XTRIM", k, strat, max_len_str};
  size_t argvlen[4] = {5, k_len, strat_len, strlen(max_len_str)};
  
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("XTRIM returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_INTEGER) {
    out = lean_box_uint64((uint64_t)r->integer);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "XTRIM returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
