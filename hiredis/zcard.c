// zcard :: UInt64 -> ByteArray -> EIO RedisError UInt64
// Get the number of elements in the sorted set stored at key. Returns the cardinality (number of elements) of the sorted set
// NOTE: Redis returns an error if the value stored at key is not a sorted set
lean_obj_res l_hiredis_zcard(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  const char* argv[2] = {"ZCARD", k};
  size_t argvlen[2] = {5, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZCARD returned NULL");
    return lean_io_result_mk_error(error);
  }
  
  uint64_t count = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    count = (uint64_t)r->integer;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    // Redis returns an error if the key exists but is not a sorted set
    if (strstr(r->str, "WRONGTYPE") != NULL) {
      lean_object* error = mk_redis_null_reply_error("WRONGTYPE - key is not a sorted set");
      freeReplyObject(r);
      return lean_io_result_mk_error(error);
    }
    // Other Redis errors
    lean_object* error = mk_redis_null_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZCARD returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64(count));
}
