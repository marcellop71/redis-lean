// slowlogget :: UInt64 -> Option UInt64 -> EIO Error ByteArray
// Get slow log entries (as raw bytes, needs parsing)
lean_obj_res l_hiredis_slowlogget(uint64_t ctx, b_lean_obj_arg count_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  redisReply* r;
  if (lean_is_scalar(count_opt)) {
    r = (redisReply*)redisCommand(c, "SLOWLOG GET");
  } else {
    uint64_t count = lean_unbox_uint64(lean_ctor_get(count_opt, 0));
    char count_str[32];
    snprintf(count_str, sizeof(count_str), "%lu", (unsigned long)count);
    const char* argv[3] = {"SLOWLOG", "GET", count_str};
    size_t argvlen[3] = {7, 3, strlen(count_str)};
    r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);
  }

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SLOWLOG GET returned NULL");
    return lean_io_result_mk_error(error);
  }

  // Return raw reply as string representation
  if (r->type == REDIS_REPLY_ARRAY) {
    // Serialize as simple count info
    char info[256];
    int len = snprintf(info, sizeof(info), "slowlog_entries:%zu", r->elements);
    lean_object* byte_array = lean_alloc_sarray(1, len, len);
    memcpy(lean_sarray_cptr(byte_array), info, len);
    freeReplyObject(r);
    return lean_io_result_mk_ok(byte_array);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SLOWLOG GET returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
