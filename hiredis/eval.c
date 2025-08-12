// eval :: UInt64 -> ByteArray -> List ByteArray -> List ByteArray -> EIO Error ByteArray
// Execute a Lua script server side
lean_obj_res l_hiredis_eval(uint64_t ctx, b_lean_obj_arg script, b_lean_obj_arg keys, b_lean_obj_arg args, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* s = (const char*)lean_sarray_cptr(script);
  size_t s_len = lean_sarray_size(script);

  // Count keys and args
  size_t key_count = 0;
  lean_object* tmp = keys;
  while (!lean_is_scalar(tmp)) {
    key_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  size_t arg_count = 0;
  tmp = args;
  while (!lean_is_scalar(tmp)) {
    arg_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  // Build argv: EVAL script numkeys key [key ...] arg [arg ...]
  int argc = 3 + (int)key_count + (int)arg_count;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "EVAL";
  argvlen[0] = 4;
  argv[1] = s;
  argvlen[1] = s_len;

  char numkeys_str[32];
  snprintf(numkeys_str, sizeof(numkeys_str), "%zu", key_count);
  argv[2] = numkeys_str;
  argvlen[2] = strlen(numkeys_str);

  int idx = 3;
  tmp = keys;
  while (!lean_is_scalar(tmp)) {
    lean_object* key = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(key);
    argvlen[idx] = lean_sarray_size(key);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  tmp = args;
  while (!lean_is_scalar(tmp)) {
    lean_object* arg = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(arg);
    argvlen[idx] = lean_sarray_size(arg);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("EVAL returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STRING && r->str) {
    lean_object* byte_array = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(byte_array), r->str, r->len);
    freeReplyObject(r);
    return lean_io_result_mk_ok(byte_array);
  } else if (r->type == REDIS_REPLY_STATUS && r->str) {
    size_t len = strlen(r->str);
    lean_object* byte_array = lean_alloc_sarray(1, len, len);
    memcpy(lean_sarray_cptr(byte_array), r->str, len);
    freeReplyObject(r);
    return lean_io_result_mk_ok(byte_array);
  } else if (r->type == REDIS_REPLY_INTEGER) {
    char int_str[32];
    int len = snprintf(int_str, sizeof(int_str), "%lld", r->integer);
    lean_object* byte_array = lean_alloc_sarray(1, len, len);
    memcpy(lean_sarray_cptr(byte_array), int_str, len);
    freeReplyObject(r);
    return lean_io_result_mk_ok(byte_array);
  } else if (r->type == REDIS_REPLY_NIL) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_alloc_sarray(1, 0, 0));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "EVAL returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
