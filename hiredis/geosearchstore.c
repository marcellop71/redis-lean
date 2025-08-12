// geosearchstore :: UInt64 -> ByteArray -> ByteArray -> ByteArray -> ByteArray -> ByteArray -> Float -> ByteArray -> Option UInt64 -> Bool -> EIO Error UInt64
// Store the result of GEOSEARCH in a new key
lean_obj_res l_hiredis_geosearchstore(uint64_t ctx, b_lean_obj_arg dest, b_lean_obj_arg src, b_lean_obj_arg from_type, b_lean_obj_arg from_value, b_lean_obj_arg by_type, double radius, b_lean_obj_arg unit, b_lean_obj_arg count_opt, uint8_t storedist, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* d = (const char*)lean_sarray_cptr(dest);
  size_t d_len = lean_sarray_size(dest);
  const char* s = (const char*)lean_sarray_cptr(src);
  size_t s_len = lean_sarray_size(src);
  const char* ft = (const char*)lean_sarray_cptr(from_type);
  size_t ft_len = lean_sarray_size(from_type);
  const char* fv = (const char*)lean_sarray_cptr(from_value);
  size_t fv_len = lean_sarray_size(from_value);
  const char* bt = (const char*)lean_sarray_cptr(by_type);
  size_t bt_len = lean_sarray_size(by_type);
  const char* u = (const char*)lean_sarray_cptr(unit);
  size_t u_len = lean_sarray_size(unit);

  const char* argv[12];
  size_t argvlen[12];
  int argc = 8;

  argv[0] = "GEOSEARCHSTORE";
  argvlen[0] = 14;
  argv[1] = d;
  argvlen[1] = d_len;
  argv[2] = s;
  argvlen[2] = s_len;
  argv[3] = ft;
  argvlen[3] = ft_len;
  argv[4] = fv;
  argvlen[4] = fv_len;
  argv[5] = bt;
  argvlen[5] = bt_len;

  char radius_str[64];
  snprintf(radius_str, sizeof(radius_str), "%.17g", radius);
  argv[6] = radius_str;
  argvlen[6] = strlen(radius_str);
  argv[7] = u;
  argvlen[7] = u_len;

  char count_str[32];
  if (!lean_is_scalar(count_opt)) {
    uint64_t count = lean_unbox_uint64(lean_ctor_get(count_opt, 0));
    argv[argc] = "COUNT";
    argvlen[argc] = 5;
    argc++;
    snprintf(count_str, sizeof(count_str), "%lu", (unsigned long)count);
    argv[argc] = count_str;
    argvlen[argc] = strlen(count_str);
    argc++;
  }

  if (storedist) {
    argv[argc] = "STOREDIST";
    argvlen[argc] = 9;
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("GEOSEARCHSTORE returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t stored = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(stored));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "GEOSEARCHSTORE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
