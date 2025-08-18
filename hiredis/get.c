// get :: UInt64 -> ByteArray -> EIO RedisError ByteArray
lean_obj_res l_hiredis_get(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  redisContext* c = (redisContext*)ctx;
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  const char* argv[2] = {"GET", k};
  size_t argvlen[2] = {3, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("GET returned NULL");
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
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "GET returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
