// zunionstore :: UInt64 -> ByteArray -> List ByteArray -> EIO Error UInt64
// Store the union of multiple sorted sets
lean_obj_res l_hiredis_zunionstore(uint64_t ctx, b_lean_obj_arg dest, b_lean_obj_arg keys, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* d = (const char*)lean_sarray_cptr(dest);
  size_t d_len = lean_sarray_size(dest);

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

  // Build argv: ZUNIONSTORE dest numkeys key [key ...]
  int argc = 3 + (int)key_count;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "ZUNIONSTORE";
  argvlen[0] = 11;
  argv[1] = d;
  argvlen[1] = d_len;

  char numkeys_str[32];
  snprintf(numkeys_str, sizeof(numkeys_str), "%zu", key_count);
  argv[2] = numkeys_str;
  argvlen[2] = strlen(numkeys_str);

  tmp = keys;
  int idx = 3;
  while (!lean_is_scalar(tmp)) {
    lean_object* key = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(key);
    argvlen[idx] = lean_sarray_size(key);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZUNIONSTORE returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "ZUNIONSTORE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
