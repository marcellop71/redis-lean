// incrbyfloat :: UInt64 -> ByteArray -> Float -> EIO Error Float
// Increment the float value of a key
lean_obj_res l_hiredis_incrbyfloat(uint64_t ctx, b_lean_obj_arg key, double increment, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  char incr_str[64];
  snprintf(incr_str, sizeof(incr_str), "%.17g", increment);

  const char* argv[3] = {"INCRBYFLOAT", k, incr_str};
  size_t argvlen[3] = {11, k_len, strlen(incr_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("INCRBYFLOAT returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STRING && r->str) {
    double result = strtod(r->str, NULL);
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_float(result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "INCRBYFLOAT returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
