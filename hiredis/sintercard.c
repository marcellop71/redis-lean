// sintercard :: UInt64 -> List ByteArray -> Option UInt64 -> EIO Error UInt64
// Get the cardinality of the intersection of sets
lean_obj_res l_hiredis_sintercard(uint64_t ctx, b_lean_obj_arg keys, b_lean_obj_arg limit_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  size_t num_keys = 0;
  lean_object* current = keys;
  while (!lean_is_scalar(current)) {
    num_keys++;
    current = lean_ctor_get(current, 1);
  }

  if (num_keys == 0) {
    return lean_io_result_mk_ok(lean_box_uint64(0));
  }

  size_t max_argc = 4 + num_keys;
  const char** argv = (const char**)malloc(max_argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(max_argc * sizeof(size_t));
  int argc = 0;

  argv[argc] = "SINTERCARD";
  argvlen[argc] = 10;
  argc++;

  char numkeys_str[32];
  snprintf(numkeys_str, sizeof(numkeys_str), "%zu", num_keys);
  argv[argc] = numkeys_str;
  argvlen[argc] = strlen(numkeys_str);
  argc++;

  current = keys;
  while (!lean_is_scalar(current)) {
    lean_object* key = lean_ctor_get(current, 0);
    argv[argc] = (const char*)lean_sarray_cptr(key);
    argvlen[argc] = lean_sarray_size(key);
    argc++;
    current = lean_ctor_get(current, 1);
  }

  char limit_str[32];
  if (!lean_is_scalar(limit_opt)) {
    uint64_t limit = lean_unbox_uint64(lean_ctor_get(limit_opt, 0));
    argv[argc] = "LIMIT";
    argvlen[argc] = 5;
    argc++;
    snprintf(limit_str, sizeof(limit_str), "%lu", (unsigned long)limit);
    argv[argc] = limit_str;
    argvlen[argc] = strlen(limit_str);
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SINTERCARD returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t result = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SINTERCARD returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
