// info :: UInt64 -> Option ByteArray -> EIO Error ByteArray
// Get server information and statistics
lean_obj_res l_hiredis_info(uint64_t ctx, b_lean_obj_arg section_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  redisReply* r;
  if (lean_is_scalar(section_opt)) {
    r = (redisReply*)redisCommand(c, "INFO");
  } else {
    lean_object* section = lean_ctor_get(section_opt, 0);
    const char* s = (const char*)lean_sarray_cptr(section);
    size_t s_len = lean_sarray_size(section);
    const char* argv[2] = {"INFO", s};
    size_t argvlen[2] = {4, s_len};
    r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  }

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("INFO returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STRING && r->str) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    freeReplyObject(r);
    return lean_io_result_mk_ok(byte_array);
  } else if (r->type == REDIS_REPLY_VERB && r->str) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    freeReplyObject(r);
    return lean_io_result_mk_ok(byte_array);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "INFO returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
