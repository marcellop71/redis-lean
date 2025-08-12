// hsetnx :: UInt64 -> ByteArray -> ByteArray -> ByteArray -> EIO Error Bool
// Set field only if it doesn't exist
lean_obj_res l_hiredis_hsetnx(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg field, b_lean_obj_arg value, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* f = (const char*)lean_sarray_cptr(field);
  size_t f_len = lean_sarray_size(field);
  const char* v = (const char*)lean_sarray_cptr(value);
  size_t v_len = lean_sarray_size(value);

  const char* argv[4] = {"HSETNX", k, f, v};
  size_t argvlen[4] = {6, k_len, f_len, v_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("HSETNX returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint8_t result = r->integer == 1 ? 1 : 0;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "HSETNX returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
