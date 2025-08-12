// hset :: UInt64 -> ByteArray -> ByteArray -> ByteArray -> EIO RedisError UInt64
// Redis returns an error if the value stored at key is not a hash
lean_obj_res l_hiredis_hset(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg field, b_lean_obj_arg value, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* f = (const char*)lean_sarray_cptr(field);
  size_t f_len = lean_sarray_size(field);
  const char* v = (const char*)lean_sarray_cptr(value);
  size_t v_len = lean_sarray_size(value);
  
  const char* argv[4] = {"HSET", k, f, v};
  size_t argvlen[4] = {4, k_len, f_len, v_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("HSET returned NULL");
    return lean_io_result_mk_error(error);
  }
  
  uint64_t added = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    added = (uint64_t)r->integer;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    // Redis returns an error if the key exists but is not a hash
    if (strstr(r->str, "WRONGTYPE") != NULL) {
      lean_object* error = mk_redis_null_reply_error("WRONGTYPE - key is not a hash");
      freeReplyObject(r);
      return lean_io_result_mk_error(error);
    }
    // Other Redis errors
    lean_object* error = mk_redis_null_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "HSET returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64(added));
}
