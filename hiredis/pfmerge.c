// pfmerge :: UInt64 -> ByteArray -> List ByteArray -> EIO Error Unit
// Merge multiple HyperLogLog keys into a destination key
lean_obj_res l_hiredis_pfmerge(uint64_t ctx, b_lean_obj_arg dest, b_lean_obj_arg sources, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* d = (const char*)lean_sarray_cptr(dest);
  size_t d_len = lean_sarray_size(dest);

  // Count source keys
  size_t src_count = 0;
  lean_object* tmp = sources;
  while (!lean_is_scalar(tmp)) {
    src_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  // Build argv: PFMERGE dest sourcekey [sourcekey ...]
  int argc = 2 + (int)src_count;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "PFMERGE";
  argvlen[0] = 7;
  argv[1] = d;
  argvlen[1] = d_len;

  tmp = sources;
  int idx = 2;
  while (!lean_is_scalar(tmp)) {
    lean_object* src = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(src);
    argvlen[idx] = lean_sarray_size(src);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("PFMERGE returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "PFMERGE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
