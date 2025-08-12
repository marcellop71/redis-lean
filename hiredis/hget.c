// hget :: UInt64 -> ByteArray -> ByteArray -> EIO RedisError ByteArray
// Redis returns an error if the value stored at key is not a hash
lean_obj_res l_hiredis_hget(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg field, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* f = (const char*)lean_sarray_cptr(field);
  size_t f_len = lean_sarray_size(field);
  
  const char* argv[3] = {"HGET", k, f};
  size_t argvlen[3] = {4, k_len, f_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("HGET returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    lean_object* error = mk_redis_key_not_found_error(k);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else if (r->type == REDIS_REPLY_STRING && r->str) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    out = byte_array;
  } else if (r->type == REDIS_REPLY_STATUS && r->str) {
    // handling status reply as normal reply
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    out = byte_array;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    // Redis returns an error if the key exists but is not a hash
    if (strstr(r->str, "WRONGTYPE") != NULL) {
      lean_object* error = mk_redis_null_reply_error("WRONGTYPE - key is not a hash");
      freeReplyObject(r);
      return lean_io_result_mk_error(error);
    }
    // Other Redis errors
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "HGET returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
