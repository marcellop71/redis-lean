// zincrby :: UInt64 -> ByteArray -> Float -> ByteArray -> EIO Error Float
// Increment the score of a member in a sorted set
lean_obj_res l_hiredis_zincrby(uint64_t ctx, b_lean_obj_arg key, double increment, b_lean_obj_arg member, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* m = (const char*)lean_sarray_cptr(member);
  size_t m_len = lean_sarray_size(member);

  char incr_str[64];
  snprintf(incr_str, sizeof(incr_str), "%.17g", increment);

  const char* argv[4] = {"ZINCRBY", k, incr_str, m};
  size_t argvlen[4] = {7, k_len, strlen(incr_str), m_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZINCRBY returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STRING && r->str) {
    double new_score = strtod(r->str, NULL);
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_float(new_score));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZINCRBY returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
