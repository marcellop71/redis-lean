// zscore :: UInt64 -> ByteArray -> ByteArray -> EIO Error (Option Float)
// Get the score of a member in a sorted set
lean_obj_res l_hiredis_zscore(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg member, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* m = (const char*)lean_sarray_cptr(member);
  size_t m_len = lean_sarray_size(member);

  const char* argv[3] = {"ZSCORE", k, m};
  size_t argvlen[3] = {6, k_len, m_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZSCORE returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_NIL) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0)); // none
  } else if (r->type == REDIS_REPLY_STRING && r->str) {
    double score = strtod(r->str, NULL);
    freeReplyObject(r);
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, lean_box_float(score));
    return lean_io_result_mk_ok(some);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZSCORE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
