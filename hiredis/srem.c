// srem :: UInt64 -> ByteArray -> List ByteArray -> EIO Error UInt64
// Remove members from a set, returns number removed
lean_obj_res l_hiredis_srem(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg members, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  size_t num_members = 0;
  lean_object* current = members;
  while (!lean_is_scalar(current)) {
    num_members++;
    current = lean_ctor_get(current, 1);
  }

  if (num_members == 0) {
    return lean_io_result_mk_ok(lean_box_uint64(0));
  }

  size_t argc = 2 + num_members;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "SREM";
  argvlen[0] = 4;
  argv[1] = k;
  argvlen[1] = k_len;

  current = members;
  size_t i = 2;
  while (!lean_is_scalar(current)) {
    lean_object* member = lean_ctor_get(current, 0);
    argv[i] = (const char*)lean_sarray_cptr(member);
    argvlen[i] = lean_sarray_size(member);
    current = lean_ctor_get(current, 1);
    i++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, (int)argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SREM returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "SREM returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
