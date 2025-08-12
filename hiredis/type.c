// type :: UInt64 -> ByteArray -> EIO RedisError String
lean_obj_res l_hiredis_type(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  const char* argv[2] = {"TYPE", k};
  size_t argvlen[2] = {4, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("TYPE returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* type_string;
  if (r->type == REDIS_REPLY_STATUS && r->str) {
    type_string = lean_mk_string(r->str);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "TYPE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(type_string);
}
