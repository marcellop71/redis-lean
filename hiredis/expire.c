// expire :: UInt64 -> ByteArray -> UInt64 -> EIO Error Bool
// Set a key's time to live in seconds
lean_obj_res l_hiredis_expire(uint64_t ctx, b_lean_obj_arg key, uint64_t seconds, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  char seconds_str[32];
  snprintf(seconds_str, sizeof(seconds_str), "%lu", (unsigned long)seconds);

  const char* argv[3] = {"EXPIRE", k, seconds_str};
  size_t argvlen[3] = {6, k_len, strlen(seconds_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("EXPIRE returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint8_t result = r->integer == 1 ? 1 : 0;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "EXPIRE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
