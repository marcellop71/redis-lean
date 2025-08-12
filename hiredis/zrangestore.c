// zrangestore :: UInt64 -> ByteArray -> ByteArray -> ByteArray -> ByteArray -> Bool -> EIO Error UInt64
// Store the result of ZRANGE in a new sorted set
// src: source key, dst: destination key, min/max: range bounds
// rangeType: "BYSCORE", "BYLEX", or "" for index range
lean_obj_res l_hiredis_zrangestore(uint64_t ctx, b_lean_obj_arg dst, b_lean_obj_arg src, b_lean_obj_arg min, b_lean_obj_arg max, b_lean_obj_arg range_type, uint8_t rev, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* d = (const char*)lean_sarray_cptr(dst);
  size_t d_len = lean_sarray_size(dst);
  const char* s = (const char*)lean_sarray_cptr(src);
  size_t s_len = lean_sarray_size(src);
  const char* min_str = (const char*)lean_sarray_cptr(min);
  size_t min_len = lean_sarray_size(min);
  const char* max_str = (const char*)lean_sarray_cptr(max);
  size_t max_len = lean_sarray_size(max);
  const char* rt = (const char*)lean_sarray_cptr(range_type);
  size_t rt_len = lean_sarray_size(range_type);

  const char* argv[7];
  size_t argvlen[7];
  int argc = 5;

  argv[0] = "ZRANGESTORE";
  argvlen[0] = 11;
  argv[1] = d;
  argvlen[1] = d_len;
  argv[2] = s;
  argvlen[2] = s_len;
  argv[3] = min_str;
  argvlen[3] = min_len;
  argv[4] = max_str;
  argvlen[4] = max_len;

  if (rt_len > 0) {
    argv[argc] = rt;
    argvlen[argc] = rt_len;
    argc++;
  }

  if (rev) {
    argv[argc] = "REV";
    argvlen[argc] = 3;
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZRANGESTORE returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "ZRANGESTORE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
