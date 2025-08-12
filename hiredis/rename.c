// rename :: UInt64 -> ByteArray -> ByteArray -> EIO Error Unit
// Rename a key
lean_obj_res l_hiredis_rename(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg newkey, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* n = (const char*)lean_sarray_cptr(newkey);
  size_t n_len = lean_sarray_size(newkey);

  const char* argv[3] = {"RENAME", k, n};
  size_t argvlen[3] = {6, k_len, n_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("RENAME returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STATUS || r->type == REDIS_REPLY_STRING) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "RENAME returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
