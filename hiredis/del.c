// del :: UInt64 -> List ByteArray -> EIO RedisError UInt64
lean_obj_res l_hiredis_del(uint64_t ctx, b_lean_obj_arg keys, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  
  lean_object* current = keys;
  size_t key_count = 0;
  while (!lean_is_scalar(current)) {
    key_count++;
    current = lean_ctor_get(current, 1); // tail of the list
  }
  if (key_count == 0) {
    return lean_io_result_mk_ok(lean_box_uint64(0));
  }
  
  const char** argv = (const char**)malloc((key_count + 1) * sizeof(char*));
  size_t* argvlen = (size_t*)malloc((key_count + 1) * sizeof(size_t));
  
  if (!argv || !argvlen) {
    if (argv) free(argv);
    if (argvlen) free(argvlen);
    lean_object* error = mk_redis_null_reply_error("memory allocation failed");
    return lean_io_result_mk_error(error);
  }

  argv[0] = "DEL";
  argvlen[0] = 3;
  
  current = keys;
  for (size_t i = 0; i < key_count; i++) {
    lean_object* key = lean_ctor_get(current, 0); // head of the list
    argv[i + 1] = (const char*)lean_sarray_cptr(key);
    argvlen[i + 1] = lean_sarray_size(key);
    current = lean_ctor_get(current, 1); // tail of the list
  }
  
  redisReply* r = (redisReply*)redisCommandArgv(c, (int)(key_count + 1), argv, argvlen);
  
  free(argv);
  free(argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("redisCommand returned NULL");
    return lean_io_result_mk_error(error);
  }
  
  uint64_t deleted = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    deleted = (uint64_t)r->integer;
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "DEL returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64(deleted));
}
