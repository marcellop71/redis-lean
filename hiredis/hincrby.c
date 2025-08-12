// hincrby :: UInt64 -> ByteArray -> ByteArray -> Int64 -> EIO RedisError UInt64
// Redis returns an error if the value stored at key is not a hash or if the field contains a non-integer value
lean_obj_res l_hiredis_hincrby(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg field, int64_t increment, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* f = (const char*)lean_sarray_cptr(field);
  size_t f_len = lean_sarray_size(field);
  
  char incr_str[32];
  snprintf(incr_str, sizeof(incr_str), "%lld", (long long)increment);
  
  const char* argv[4] = {"HINCRBY", k, f, incr_str};
  size_t argvlen[4] = {7, k_len, f_len, strlen(incr_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("HINCRBY returned NULL");
    return lean_io_result_mk_error(error);
  }

  int64_t result = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    result = r->integer;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    if (strstr(r->str, "WRONGTYPE") != NULL) {
      lean_object* error = mk_redis_null_reply_error("WRONGTYPE - key is not a hash");
      freeReplyObject(r);
      return lean_io_result_mk_error(error);
    }
    if (strstr(r->str, "not an integer") != NULL || strstr(r->str, "invalid") != NULL) {
      lean_object* error = mk_redis_null_reply_error("field value is not an integer or out of range");
      freeReplyObject(r);
      return lean_io_result_mk_error(error);
    }
    lean_object* error = mk_redis_null_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "HINCRBY returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64((uint64_t)result));
}
