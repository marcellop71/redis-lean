// expiretime :: UInt64 -> ByteArray -> EIO Error Int64
// Get the expiration Unix timestamp for a key (seconds)
// Returns -1 if key has no expiry, -2 if key does not exist
lean_obj_res l_hiredis_expiretime(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  const char* argv[2] = {"EXPIRETIME", k};
  size_t argvlen[2] = {10, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("EXPIRETIME returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    int64_t result = (int64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "EXPIRETIME returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
