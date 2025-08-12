// flushall :: UInt64 -> String -> EIO RedisError Bool
lean_obj_res l_hiredis_flushall(uint64_t ctx, b_lean_obj_arg mode, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* mode_str = lean_string_cstr(mode);
  
  // Validate mode parameter
  if (strcmp(mode_str, "SYNC") != 0 && strcmp(mode_str, "ASYNC") != 0) {
    lean_object* error = mk_redis_null_reply_error("FLUSHALL mode must be 'SYNC' or 'ASYNC'");
    return lean_io_result_mk_error(error);
  }
  
  // Prepare command arguments
  const char* argv[2] = {"FLUSHALL", mode_str};
  size_t argvlen[2] = {8, strlen(mode_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("redisCommand returned NULL");
    return lean_io_result_mk_error(error);
  }

  int success = 0;
  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    success = 1;
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "FLUSHALL returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box(success));
}
