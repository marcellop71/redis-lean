// hlen :: UInt64 -> ByteArray -> EIO Error UInt64
// Get the number of fields in a hash
lean_obj_res l_hiredis_hlen(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  const char* argv[2] = {"HLEN", k};
  size_t argvlen[2] = {4, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("HLEN returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t result = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "HLEN returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
