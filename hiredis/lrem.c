// lrem :: UInt64 -> ByteArray -> Int64 -> ByteArray -> EIO Error UInt64
// Remove elements from a list
// count > 0: remove count elements from head
// count < 0: remove |count| elements from tail
// count = 0: remove all elements equal to value
lean_obj_res l_hiredis_lrem(uint64_t ctx, b_lean_obj_arg key, int64_t count, b_lean_obj_arg value, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* v = (const char*)lean_sarray_cptr(value);
  size_t v_len = lean_sarray_size(value);

  char count_str[32];
  snprintf(count_str, sizeof(count_str), "%ld", (long)count);

  const char* argv[4] = {"LREM", k, count_str, v};
  size_t argvlen[4] = {4, k_len, strlen(count_str), v_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("LREM returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "LREM returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
