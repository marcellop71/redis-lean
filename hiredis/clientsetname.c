// clientsetname :: UInt64 -> ByteArray -> EIO Error Unit
// Set the current connection's name
lean_obj_res l_hiredis_clientsetname(uint64_t ctx, b_lean_obj_arg name, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* n = (const char*)lean_sarray_cptr(name);
  size_t n_len = lean_sarray_size(name);

  const char* argv[3] = {"CLIENT", "SETNAME", n};
  size_t argvlen[3] = {6, 7, n_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("CLIENT SETNAME returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "CLIENT SETNAME returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
