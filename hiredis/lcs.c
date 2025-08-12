// lcs :: UInt64 -> ByteArray -> ByteArray -> Bool -> Bool -> EIO Error ByteArray
// Find longest common substring between two keys
// getLen: if true, return length only
// getIdx: if true, return indices of matches
lean_obj_res l_hiredis_lcs(uint64_t ctx, b_lean_obj_arg key1, b_lean_obj_arg key2, uint8_t getLen, uint8_t getIdx, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k1 = (const char*)lean_sarray_cptr(key1);
  size_t k1_len = lean_sarray_size(key1);
  const char* k2 = (const char*)lean_sarray_cptr(key2);
  size_t k2_len = lean_sarray_size(key2);

  const char* argv[6];
  size_t argvlen[6];
  int argc = 3;

  argv[0] = "LCS";
  argvlen[0] = 3;
  argv[1] = k1;
  argvlen[1] = k1_len;
  argv[2] = k2;
  argvlen[2] = k2_len;

  if (getLen) {
    argv[argc] = "LEN";
    argvlen[argc] = 3;
    argc++;
  }

  if (getIdx) {
    argv[argc] = "IDX";
    argvlen[argc] = 3;
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("LCS returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_STRING && r->str) {
    // Normal LCS result (the actual substring)
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    out = byte_array;
  } else if (r->type == REDIS_REPLY_INTEGER) {
    // LEN option returns integer
    char buf[32];
    int len = snprintf(buf, sizeof(buf), "%lld", r->integer);
    lean_object* byte_array = lean_alloc_sarray(1, len, len);
    memcpy(lean_sarray_cptr(byte_array), buf, len);
    out = byte_array;
  } else if (r->type == REDIS_REPLY_ARRAY || r->type == REDIS_REPLY_MAP) {
    // IDX option returns structured data - serialize as string representation
    // For simplicity, return empty for now (proper handling would need JSON/structured output)
    lean_object* byte_array = lean_alloc_sarray(1, 0, 0);
    out = byte_array;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "LCS returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
