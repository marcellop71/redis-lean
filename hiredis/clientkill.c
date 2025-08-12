// clientkill :: UInt64 -> ByteArray -> ByteArray -> EIO Error UInt64
// Kill client connections (filterType: ID, ADDR, TYPE, USER, etc., filterValue: the value)
lean_obj_res l_hiredis_clientkill(uint64_t ctx, b_lean_obj_arg filter_type, b_lean_obj_arg filter_value, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* ft = (const char*)lean_sarray_cptr(filter_type);
  size_t ft_len = lean_sarray_size(filter_type);
  const char* fv = (const char*)lean_sarray_cptr(filter_value);
  size_t fv_len = lean_sarray_size(filter_value);

  const char* argv[4] = {"CLIENT", "KILL", ft, fv};
  size_t argvlen[4] = {6, 4, ft_len, fv_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("CLIENT KILL returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t killed = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(killed));
  } else if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(1));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "CLIENT KILL returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
