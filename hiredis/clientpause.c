// clientpause :: UInt64 -> UInt64 -> EIO Error Unit
// Pause client connections for timeout milliseconds
lean_obj_res l_hiredis_clientpause(uint64_t ctx, uint64_t timeout, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  char timeout_str[32];
  snprintf(timeout_str, sizeof(timeout_str), "%lu", (unsigned long)timeout);

  const char* argv[3] = {"CLIENT", "PAUSE", timeout_str};
  size_t argvlen[3] = {6, 5, strlen(timeout_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("CLIENT PAUSE returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "CLIENT PAUSE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
