// zremrangebyrank :: UInt64 -> ByteArray -> Int64 -> Int64 -> EIO Error UInt64
// Remove members by rank range
lean_obj_res l_hiredis_zremrangebyrank(uint64_t ctx, b_lean_obj_arg key, int64_t start, int64_t stop, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  char start_str[32];
  char stop_str[32];
  snprintf(start_str, sizeof(start_str), "%ld", (long)start);
  snprintf(stop_str, sizeof(stop_str), "%ld", (long)stop);

  const char* argv[4] = {"ZREMRANGEBYRANK", k, start_str, stop_str};
  size_t argvlen[4] = {15, k_len, strlen(start_str), strlen(stop_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZREMRANGEBYRANK returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "ZREMRANGEBYRANK returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
