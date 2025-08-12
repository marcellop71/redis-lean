// zrem :: UInt64 -> ByteArray -> List ByteArray -> EIO Error UInt64
// Remove one or more members from a sorted set
lean_obj_res l_hiredis_zrem(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg members, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  // Count members
  size_t member_count = 0;
  lean_object* tmp = members;
  while (!lean_is_scalar(tmp)) {
    member_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  if (member_count == 0) {
    return lean_io_result_mk_ok(lean_box_uint64(0));
  }

  // Build argv: ZREM key member [member ...]
  int argc = 2 + (int)member_count;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "ZREM";
  argvlen[0] = 4;
  argv[1] = k;
  argvlen[1] = k_len;

  tmp = members;
  int idx = 2;
  while (!lean_is_scalar(tmp)) {
    lean_object* member = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(member);
    argvlen[idx] = lean_sarray_size(member);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZREM returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t removed = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(removed));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZREM returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
