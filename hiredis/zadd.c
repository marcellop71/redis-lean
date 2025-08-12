// zadd :: UInt64 -> ByteArray -> Float -> ByteArray -> EIO RedisError UInt64
// Add a member with score to the sorted set stored at key. Returns the number of elements added (0 if member already exists with updated score, 1 if new)
// NOTE: Redis returns an error if the value stored at key is not a sorted set
lean_obj_res l_hiredis_zadd(uint64_t ctx, b_lean_obj_arg key, double score, b_lean_obj_arg member, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* m = (const char*)lean_sarray_cptr(member);
  size_t m_len = lean_sarray_size(member);
  
  // Convert score to string for the command
  char score_str[64];
  snprintf(score_str, sizeof(score_str), "%.17g", score);
  
  const char* argv[4] = {"ZADD", k, score_str, m};
  size_t argvlen[4] = {4, k_len, strlen(score_str), m_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZADD returned NULL");
    return lean_io_result_mk_error(error);
  }
  
  uint64_t added = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    added = (uint64_t)r->integer;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    // Redis returns an error if the key exists but is not a sorted set
    if (strstr(r->str, "WRONGTYPE") != NULL) {
      lean_object* error = mk_redis_null_reply_error("WRONGTYPE - key is not a sorted set");
      freeReplyObject(r);
      return lean_io_result_mk_error(error);
    }
    // Redis returns an error if the score is not a valid float
    if (strstr(r->str, "not a valid float") != NULL || strstr(r->str, "invalid") != NULL) {
      lean_object* error = mk_redis_null_reply_error("score is not a valid float");
      freeReplyObject(r);
      return lean_io_result_mk_error(error);
    }
    // Other Redis errors
    lean_object* error = mk_redis_null_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZADD returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64(added));
}
