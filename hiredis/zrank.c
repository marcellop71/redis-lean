// zrank :: UInt64 -> ByteArray -> ByteArray -> EIO Error (Option UInt64)
// Get the rank of a member in a sorted set (0-based, low to high)
lean_obj_res l_hiredis_zrank(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg member, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* m = (const char*)lean_sarray_cptr(member);
  size_t m_len = lean_sarray_size(member);

  const char* argv[3] = {"ZRANK", k, m};
  size_t argvlen[3] = {5, k_len, m_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZRANK returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_NIL) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0)); // none
  } else if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t rank = (uint64_t)r->integer;
    freeReplyObject(r);
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, lean_box_uint64(rank));
    return lean_io_result_mk_ok(some);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZRANK returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
