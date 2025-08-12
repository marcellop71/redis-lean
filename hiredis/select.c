// select :: UInt64 -> UInt64 -> EIO Error Unit
// Select the Redis logical database
lean_obj_res l_hiredis_select(uint64_t ctx, uint64_t index, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  char index_str[32];
  snprintf(index_str, sizeof(index_str), "%lu", (unsigned long)index);

  const char* argv[2] = {"SELECT", index_str};
  size_t argvlen[2] = {6, strlen(index_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SELECT returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "SELECT returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
