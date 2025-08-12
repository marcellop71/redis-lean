// rpushx :: UInt64 -> ByteArray -> List ByteArray -> EIO Error UInt64
// Push elements to tail only if list exists, returns new length
lean_obj_res l_hiredis_rpushx(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg elements, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  size_t num_elements = 0;
  lean_object* current = elements;
  while (!lean_is_scalar(current)) {
    num_elements++;
    current = lean_ctor_get(current, 1);
  }

  if (num_elements == 0) {
    lean_object* error = mk_redis_reply_error("RPUSHX requires at least one element");
    return lean_io_result_mk_error(error);
  }

  size_t argc = 2 + num_elements;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "RPUSHX";
  argvlen[0] = 6;
  argv[1] = k;
  argvlen[1] = k_len;

  current = elements;
  size_t i = 2;
  while (!lean_is_scalar(current)) {
    lean_object* elem = lean_ctor_get(current, 0);
    argv[i] = (const char*)lean_sarray_cptr(elem);
    argvlen[i] = lean_sarray_size(elem);
    current = lean_ctor_get(current, 1);
    i++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, (int)argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("RPUSHX returned NULL");
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
    snprintf(error_msg, sizeof(error_msg), "RPUSHX returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
