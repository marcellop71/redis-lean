// zremrangebylex :: UInt64 -> ByteArray -> ByteArray -> ByteArray -> EIO Error UInt64
// Remove members by lexicographical range
lean_obj_res l_hiredis_zremrangebylex(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg min, b_lean_obj_arg max, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* min_str = (const char*)lean_sarray_cptr(min);
  size_t min_len = lean_sarray_size(min);
  const char* max_str = (const char*)lean_sarray_cptr(max);
  size_t max_len = lean_sarray_size(max);

  const char* argv[4] = {"ZREMRANGEBYLEX", k, min_str, max_str};
  size_t argvlen[4] = {14, k_len, min_len, max_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZREMRANGEBYLEX returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t removed = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(removed));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZREMRANGEBYLEX returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
