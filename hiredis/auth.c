// auth :: Ctx -> String -> EIO RedisError Bool
lean_obj_res l_hiredis_auth(b_lean_obj_arg ctx, b_lean_obj_arg password, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* pwd = lean_string_cstr(password);
  
  redisReply* r = (redisReply*)redisCommand(c, "AUTH %s", pwd);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("AUTH returned NULL");
    return lean_io_result_mk_error(error);
  }
  
  uint8_t success = 0;
  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    success = 1;
  } else if (r->type == REDIS_REPLY_ERROR) {
    char error_msg[512];
    snprintf(error_msg, sizeof(error_msg), "AUTH error: %s", r->str);
    freeReplyObject(r);
    lean_object* error = mk_redis_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "AUTH returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box(success));
}

// AUTH <username> <password> (Redis 6+ ACL users). Returns true on OK; errors (wrong
// credentials, unknown user) are raised as reply errors.
lean_obj_res l_hiredis_auth_user(b_lean_obj_arg ctx, b_lean_obj_arg username, b_lean_obj_arg password, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* argv[3] = { "AUTH", lean_string_cstr(username), lean_string_cstr(password) };
  size_t argvlen[3] = { 4, lean_string_size(username) - 1, lean_string_size(password) - 1 };
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("AUTH returned NULL");
    return lean_io_result_mk_error(error);
  }
  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(1));
  }
  char error_msg[512];
  if (r->type == REDIS_REPLY_ERROR) {
    snprintf(error_msg, sizeof(error_msg), "AUTH error: %s", r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(mk_redis_reply_error(error_msg));
  }
  snprintf(error_msg, sizeof(error_msg), "AUTH returned unexpected reply type %d", r->type);
  freeReplyObject(r);
  return lean_io_result_mk_error(mk_redis_null_reply_error(error_msg));
}
