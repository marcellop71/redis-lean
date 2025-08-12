// incr :: UInt64 -> ByteArray -> EIO RedisError UInt64
lean_obj_res l_hiredis_incr(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  const char* argv[2] = {"INCR", k};
  size_t argvlen[2] = {4, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("redisCommand returned NULL");
    return lean_io_result_mk_error(error);
  }

  int64_t result = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    result = r->integer;
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "INCR returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }
  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64((uint64_t)result));
}

// incrby :: UInt64 -> ByteArray -> Int64 -> EIO RedisError UInt64
// Increment the integer value of a key by the given amount
lean_obj_res l_hiredis_incrby(uint64_t ctx, b_lean_obj_arg key, int64_t increment, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  // Convert increment to string for the command
  char incr_str[32];
  snprintf(incr_str, sizeof(incr_str), "%lld", (long long)increment);
  
  const char* argv[3] = {"INCRBY", k, incr_str};
  size_t argvlen[3] = {6, k_len, strlen(incr_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("redisCommand returned NULL");
    return lean_io_result_mk_error(error);
  }

  int64_t result = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    result = r->integer;
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "INCRBY returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64((uint64_t)result));
}
