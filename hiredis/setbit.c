// setbit :: UInt64 -> ByteArray -> UInt64 -> UInt8 -> EIO Error UInt8
// Set or clear the bit at offset in the string value stored at key
lean_obj_res l_hiredis_setbit(uint64_t ctx, b_lean_obj_arg key, uint64_t offset, uint8_t value, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  char offset_str[32];
  snprintf(offset_str, sizeof(offset_str), "%lu", (unsigned long)offset);
  char value_str[2];
  value_str[0] = value ? '1' : '0';
  value_str[1] = '\0';

  const char* argv[4] = {"SETBIT", k, offset_str, value_str};
  size_t argvlen[4] = {6, k_len, strlen(offset_str), 1};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SETBIT returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint8_t old_bit = r->integer ? 1 : 0;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(old_bit));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SETBIT returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
