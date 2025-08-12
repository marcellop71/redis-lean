// publish :: UInt64 -> String -> ByteArray -> EIO RedisError UInt64
lean_obj_res l_hiredis_publish(uint64_t ctx, b_lean_obj_arg channel, b_lean_obj_arg message, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* ch = lean_string_cstr(channel);
  size_t ch_len = strlen(ch);
  const char* msg = (const char*)lean_sarray_cptr(message);
  size_t msg_len = lean_sarray_size(message);
  
  const char* argv[3] = {"PUBLISH", ch, msg};
  size_t argvlen[3] = {7, ch_len, msg_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("PUBLISH returned NULL");
    return lean_io_result_mk_error(error);
  }
  
  uint64_t subscribers = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    subscribers = (uint64_t)r->integer;
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "PUBLISH returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64(subscribers));
}
