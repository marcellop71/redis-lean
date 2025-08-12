// copy :: UInt64 -> ByteArray -> ByteArray -> Bool -> EIO Error Bool
// Copy a key to another key
// replace: if true, remove destination key before copying
lean_obj_res l_hiredis_copy(uint64_t ctx, b_lean_obj_arg src, b_lean_obj_arg dst, uint8_t replace, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* s = (const char*)lean_sarray_cptr(src);
  size_t s_len = lean_sarray_size(src);
  const char* d = (const char*)lean_sarray_cptr(dst);
  size_t d_len = lean_sarray_size(dst);

  const char* argv[4];
  size_t argvlen[4];
  int argc = 3;

  argv[0] = "COPY";
  argvlen[0] = 4;
  argv[1] = s;
  argvlen[1] = s_len;
  argv[2] = d;
  argvlen[2] = d_len;

  if (replace) {
    argv[argc] = "REPLACE";
    argvlen[argc] = 7;
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("COPY returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint8_t result = r->integer == 1 ? 1 : 0;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "COPY returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
