// echo :: UInt64 -> ByteArray -> EIO Error ByteArray
// Echo the given message
lean_obj_res l_hiredis_echo(uint64_t ctx, b_lean_obj_arg message, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* m = (const char*)lean_sarray_cptr(message);
  size_t m_len = lean_sarray_size(message);

  const char* argv[2] = {"ECHO", m};
  size_t argvlen[2] = {4, m_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ECHO returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STRING && r->str) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    freeReplyObject(r);
    return lean_io_result_mk_ok(byte_array);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ECHO returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
