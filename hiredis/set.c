// Enum for SET command existence options
typedef enum {
  SET_EXISTS_OPTION_NONE = 0,
  SET_EXISTS_OPTION_NX = 1,
  SET_EXISTS_OPTION_XX = 2
} set_exists_option_t;

// set :: UInt64 -> ByteArray -> ByteArray -> UInt8 -> EIO RedisError Unit
// exists_option: 0 = none, 1 = NX (only if not exists), 2 = XX (only if exists)
lean_obj_res l_hiredis_set(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg val, uint8_t exists_option, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* v = (const char*)lean_sarray_cptr(val);
  size_t v_len = lean_sarray_size(val);
  
  // Prepare command arguments based on exists_option
  const char* argv[4];
  size_t argvlen[4];
  int argc = 3;
  
  argv[0] = "SET";
  argv[1] = k;
  argv[2] = v;
  argvlen[0] = 3;
  argvlen[1] = k_len;
  argvlen[2] = v_len;
  
  // Add NX or XX option if specified
  if (exists_option == SET_EXISTS_OPTION_NX) {
    argv[3] = "NX";
    argvlen[3] = 2;
    argc = 4;
  } else if (exists_option == SET_EXISTS_OPTION_XX) {
    argv[3] = "XX";
    argvlen[3] = 2;
    argc = 4;
  }
  
  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SET returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0));
  } else if (r->type == REDIS_REPLY_NIL) {
    // When NX or XX condition is not met, Redis returns NIL - treat as error
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error("SET condition not met (NX/XX)");
    return lean_io_result_mk_error(error);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SET returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
