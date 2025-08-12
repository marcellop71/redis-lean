// pfadd :: UInt64 -> ByteArray -> List ByteArray -> EIO Error Bool
// Add elements to a HyperLogLog (returns true if internal registers changed)
lean_obj_res l_hiredis_pfadd(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg elements, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  // Count elements
  size_t elem_count = 0;
  lean_object* tmp = elements;
  while (!lean_is_scalar(tmp)) {
    elem_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  // Build argv: PFADD key element [element ...]
  int argc = 2 + (int)elem_count;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "PFADD";
  argvlen[0] = 5;
  argv[1] = k;
  argvlen[1] = k_len;

  tmp = elements;
  int idx = 2;
  while (!lean_is_scalar(tmp)) {
    lean_object* elem = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(elem);
    argvlen[idx] = lean_sarray_size(elem);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("PFADD returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint8_t changed = r->integer != 0 ? 1 : 0;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(changed));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "PFADD returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
