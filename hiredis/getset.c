// getset :: UInt64 -> ByteArray -> ByteArray -> EIO Error ByteArray
// Set value and return old value (deprecated, use SET with GET option)
lean_obj_res l_hiredis_getset(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg value, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* v = (const char*)lean_sarray_cptr(value);
  size_t v_len = lean_sarray_size(value);

  const char* argv[3] = {"GETSET", k, v};
  size_t argvlen[3] = {6, k_len, v_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("GETSET returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    // Key didn't exist before - return empty ByteArray
    lean_object* byte_array = lean_alloc_sarray(1, 0, 0);
    out = byte_array;
  } else if (r->type == REDIS_REPLY_STRING && r->str) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    out = byte_array;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "GETSET returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
