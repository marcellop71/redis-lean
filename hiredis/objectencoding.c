// objectencoding :: UInt64 -> ByteArray -> EIO Error (Option ByteArray)
// Get the internal encoding of a Redis object
lean_obj_res l_hiredis_objectencoding(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  const char* argv[3] = {"OBJECT", "ENCODING", k};
  size_t argvlen[3] = {6, 8, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 3, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("OBJECT ENCODING returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_NIL) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0)); // none
  } else if (r->type == REDIS_REPLY_STRING && r->str) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    freeReplyObject(r);
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, byte_array);
    return lean_io_result_mk_ok(some);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "OBJECT ENCODING returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
