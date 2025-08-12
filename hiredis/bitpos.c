// bitpos :: UInt64 -> ByteArray -> UInt8 -> Option Int64 -> Option Int64 -> EIO Error Int64
// Find first bit set or clear in a string
lean_obj_res l_hiredis_bitpos(uint64_t ctx, b_lean_obj_arg key, uint8_t bit, b_lean_obj_arg start_opt, b_lean_obj_arg end_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  const char* argv[5];
  size_t argvlen[5];
  int argc = 3;

  argv[0] = "BITPOS";
  argvlen[0] = 6;
  argv[1] = k;
  argvlen[1] = k_len;

  char bit_str[2];
  bit_str[0] = bit ? '1' : '0';
  bit_str[1] = '\0';
  argv[2] = bit_str;
  argvlen[2] = 1;

  char start_str[32];
  char end_str[32];
  if (!lean_is_scalar(start_opt)) {
    int64_t start = (int64_t)lean_unbox_uint64(lean_ctor_get(start_opt, 0));
    snprintf(start_str, sizeof(start_str), "%ld", (long)start);
    argv[argc] = start_str;
    argvlen[argc] = strlen(start_str);
    argc++;

    if (!lean_is_scalar(end_opt)) {
      int64_t end = (int64_t)lean_unbox_uint64(lean_ctor_get(end_opt, 0));
      snprintf(end_str, sizeof(end_str), "%ld", (long)end);
      argv[argc] = end_str;
      argvlen[argc] = strlen(end_str);
      argc++;
    }
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("BITPOS returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    int64_t pos = r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)pos));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "BITPOS returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
