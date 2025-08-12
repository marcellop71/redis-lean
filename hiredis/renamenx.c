// renamenx :: UInt64 -> ByteArray -> ByteArray -> EIO Error Bool
// Rename a key only if the new key does not exist
lean_obj_res l_hiredis_renamenx(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg newkey, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* n = (const char*)lean_sarray_cptr(newkey);
  size_t n_len = lean_sarray_size(newkey);

  const char* argv[3] = {"RENAMENX", k, n};
  size_t argvlen[3] = {8, k_len, n_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("RENAMENX returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "RENAMENX returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
