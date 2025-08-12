// setrange :: UInt64 -> ByteArray -> UInt64 -> ByteArray -> EIO Error UInt64
// Overwrite part of a string at key starting at the specified offset
// Returns the length of the string after modification
lean_obj_res l_hiredis_setrange(uint64_t ctx, b_lean_obj_arg key, uint64_t offset, b_lean_obj_arg value, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* v = (const char*)lean_sarray_cptr(value);
  size_t v_len = lean_sarray_size(value);

  char offset_str[32];
  snprintf(offset_str, sizeof(offset_str), "%lu", (unsigned long)offset);

  const char* argv[4] = {"SETRANGE", k, offset_str, v};
  size_t argvlen[4] = {8, k_len, strlen(offset_str), v_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SETRANGE returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t result = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SETRANGE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
