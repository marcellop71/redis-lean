// zintercard :: UInt64 -> List ByteArray -> Option UInt64 -> EIO Error UInt64
// Get the cardinality of the intersection of multiple sorted sets
lean_obj_res l_hiredis_zintercard(uint64_t ctx, b_lean_obj_arg keys, b_lean_obj_arg limit_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  // Count keys
  size_t key_count = 0;
  lean_object* tmp = keys;
  while (!lean_is_scalar(tmp)) {
    key_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  if (key_count == 0) {
    return lean_io_result_mk_ok(lean_box_uint64(0));
  }

  // Build argv: ZINTERCARD numkeys key [key ...] [LIMIT limit]
  int has_limit = !lean_is_scalar(limit_opt);
  int argc = 2 + (int)key_count + (has_limit ? 2 : 0);
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "ZINTERCARD";
  argvlen[0] = 10;

  char numkeys_str[32];
  snprintf(numkeys_str, sizeof(numkeys_str), "%zu", key_count);
  argv[1] = numkeys_str;
  argvlen[1] = strlen(numkeys_str);

  tmp = keys;
  int idx = 2;
  while (!lean_is_scalar(tmp)) {
    lean_object* key = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(key);
    argvlen[idx] = lean_sarray_size(key);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  char limit_str[32];
  if (has_limit) {
    uint64_t limit = lean_unbox_uint64(lean_ctor_get(limit_opt, 0));
    argv[idx] = "LIMIT";
    argvlen[idx] = 5;
    idx++;
    snprintf(limit_str, sizeof(limit_str), "%lu", (unsigned long)limit);
    argv[idx] = limit_str;
    argvlen[idx] = strlen(limit_str);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZINTERCARD returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t count = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(count));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZINTERCARD returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
