// psetex :: UInt64 -> ByteArray -> UInt64 -> ByteArray -> EIO Error Unit
// Set value with millisecond expiration (deprecated, use SET with PX)
lean_obj_res l_hiredis_psetex(uint64_t ctx, b_lean_obj_arg key, uint64_t millis, b_lean_obj_arg value, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* v = (const char*)lean_sarray_cptr(value);
  size_t v_len = lean_sarray_size(value);

  char millis_str[32];
  snprintf(millis_str, sizeof(millis_str), "%lu", (unsigned long)millis);

  const char* argv[4] = {"PSETEX", k, millis_str, v};
  size_t argvlen[4] = {6, k_len, strlen(millis_str), v_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("PSETEX returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STATUS || r->type == REDIS_REPLY_STRING) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0)); // Unit
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "PSETEX returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
