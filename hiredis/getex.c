// getex :: UInt64 -> ByteArray -> Option UInt64 -> Option UInt64 -> Bool -> EIO Error ByteArray
// Get the value and optionally set expiration
// exSeconds: EX option (seconds)
// pxMillis: PX option (milliseconds)
// persist: PERSIST option (remove TTL)
lean_obj_res l_hiredis_getex(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg ex_opt, b_lean_obj_arg px_opt, uint8_t persist, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  const char* argv[5];
  size_t argvlen[5];
  int argc = 2;

  argv[0] = "GETEX";
  argvlen[0] = 5;
  argv[1] = k;
  argvlen[1] = k_len;

  char ex_str[32], px_str[32];

  if (!lean_is_scalar(ex_opt)) {
    uint64_t ex = lean_unbox_uint64(lean_ctor_get(ex_opt, 0));
    snprintf(ex_str, sizeof(ex_str), "%lu", (unsigned long)ex);
    argv[argc] = "EX";
    argvlen[argc] = 2;
    argc++;
    argv[argc] = ex_str;
    argvlen[argc] = strlen(ex_str);
    argc++;
  } else if (!lean_is_scalar(px_opt)) {
    uint64_t px = lean_unbox_uint64(lean_ctor_get(px_opt, 0));
    snprintf(px_str, sizeof(px_str), "%lu", (unsigned long)px);
    argv[argc] = "PX";
    argvlen[argc] = 2;
    argc++;
    argv[argc] = px_str;
    argvlen[argc] = strlen(px_str);
    argc++;
  } else if (persist) {
    argv[argc] = "PERSIST";
    argvlen[argc] = 7;
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("GETEX returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    lean_object* error = mk_redis_key_not_found_error(k);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
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
    snprintf(error_msg, sizeof(error_msg), "GETEX returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
