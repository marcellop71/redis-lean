// setex :: UInt64 -> ByteArray -> ByteArray -> UInt64 -> UInt8 -> EIO RedisError Unit
// msec: expiration time in milliseconds
// exists_option: 0 = none, 1 = NX (only if not exists), 2 = XX (only if exists)
lean_obj_res l_hiredis_setex(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg val, uint64_t msec, uint8_t exists_option, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* v = (const char*)lean_sarray_cptr(val);
  size_t v_len = lean_sarray_size(val);
  
  // Convert milliseconds to string for PX option
  char msec_str[32];
  snprintf(msec_str, sizeof(msec_str), "%llu", (unsigned long long)msec);
  
  // Prepare command arguments: SET key value PX msec [NX|XX]
  const char* argv[6];
  size_t argvlen[6];
  int argc = 5;
  
  argv[0] = "SET";
  argv[1] = k;
  argv[2] = v;
  argv[3] = "PX";
  argv[4] = msec_str;
  argvlen[0] = 3;
  argvlen[1] = k_len;
  argvlen[2] = v_len;
  argvlen[3] = 2;
  argvlen[4] = strlen(msec_str);
  
  // Add NX or XX option if specified
  if (exists_option == SET_EXISTS_OPTION_NX) {
    argv[5] = "NX";
    argvlen[5] = 2;
    argc = 6;
  } else if (exists_option == SET_EXISTS_OPTION_XX) {
    argv[5] = "XX";
    argvlen[5] = 2;
    argc = 6;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SETEX returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0));
  } else if (r->type == REDIS_REPLY_NIL) {
    // When NX or XX condition is not met, Redis returns NIL - treat as error
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error("SETEX condition not met (NX/XX)");
    return lean_io_result_mk_error(error);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SETEX returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
