// bitcount :: UInt64 -> ByteArray -> Option Int64 -> Option Int64 -> EIO Error UInt64
// Count the number of set bits in a string
lean_obj_res l_hiredis_bitcount(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg start_opt, b_lean_obj_arg end_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  const char* argv[4];
  size_t argvlen[4];
  int argc = 2;

  argv[0] = "BITCOUNT";
  argvlen[0] = 8;
  argv[1] = k;
  argvlen[1] = k_len;

  char start_str[32];
  char end_str[32];
  if (!lean_is_scalar(start_opt) && !lean_is_scalar(end_opt)) {
    int64_t start = (int64_t)lean_unbox_uint64(lean_ctor_get(start_opt, 0));
    int64_t end = (int64_t)lean_unbox_uint64(lean_ctor_get(end_opt, 0));
    snprintf(start_str, sizeof(start_str), "%ld", (long)start);
    snprintf(end_str, sizeof(end_str), "%ld", (long)end);
    argv[argc] = start_str;
    argvlen[argc] = strlen(start_str);
    argc++;
    argv[argc] = end_str;
    argvlen[argc] = strlen(end_str);
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("BITCOUNT returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t count = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(count));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "BITCOUNT returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
