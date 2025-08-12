// sunionstore :: UInt64 -> ByteArray -> List ByteArray -> EIO Error UInt64
// Store the union of sets in a destination key
lean_obj_res l_hiredis_sunionstore(uint64_t ctx, b_lean_obj_arg dst, b_lean_obj_arg keys, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* d = (const char*)lean_sarray_cptr(dst);
  size_t d_len = lean_sarray_size(dst);

  size_t num_keys = 0;
  lean_object* current = keys;
  while (!lean_is_scalar(current)) {
    num_keys++;
    current = lean_ctor_get(current, 1);
  }

  size_t argc = 2 + num_keys;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "SUNIONSTORE";
  argvlen[0] = 11;
  argv[1] = d;
  argvlen[1] = d_len;

  current = keys;
  size_t i = 2;
  while (!lean_is_scalar(current)) {
    lean_object* key = lean_ctor_get(current, 0);
    argv[i] = (const char*)lean_sarray_cptr(key);
    argvlen[i] = lean_sarray_size(key);
    current = lean_ctor_get(current, 1);
    i++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, (int)argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SUNIONSTORE returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "SUNIONSTORE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
