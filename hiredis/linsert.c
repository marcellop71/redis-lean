// linsert :: UInt64 -> ByteArray -> UInt8 -> ByteArray -> ByteArray -> EIO Error Int64
// Insert element before or after pivot
// position: 0 = BEFORE, 1 = AFTER
lean_obj_res l_hiredis_linsert(uint64_t ctx, b_lean_obj_arg key, uint8_t position, b_lean_obj_arg pivot, b_lean_obj_arg value, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* p = (const char*)lean_sarray_cptr(pivot);
  size_t p_len = lean_sarray_size(pivot);
  const char* v = (const char*)lean_sarray_cptr(value);
  size_t v_len = lean_sarray_size(value);

  const char* pos_str = position == 0 ? "BEFORE" : "AFTER";
  size_t pos_len = position == 0 ? 6 : 5;

  const char* argv[5] = {"LINSERT", k, pos_str, p, v};
  size_t argvlen[5] = {7, k_len, pos_len, p_len, v_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 5, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("LINSERT returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    int64_t result = (int64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64((uint64_t)result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "LINSERT returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
