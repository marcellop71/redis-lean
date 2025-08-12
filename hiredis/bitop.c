// bitop :: UInt64 -> ByteArray -> ByteArray -> List ByteArray -> EIO Error UInt64
// Perform bitwise operations between strings
// operation: AND, OR, XOR, NOT
lean_obj_res l_hiredis_bitop(uint64_t ctx, b_lean_obj_arg operation, b_lean_obj_arg destkey, b_lean_obj_arg keys, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* op = (const char*)lean_sarray_cptr(operation);
  size_t op_len = lean_sarray_size(operation);
  const char* d = (const char*)lean_sarray_cptr(destkey);
  size_t d_len = lean_sarray_size(destkey);

  // Count keys
  size_t key_count = 0;
  lean_object* tmp = keys;
  while (!lean_is_scalar(tmp)) {
    key_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  // Build argv: BITOP operation destkey key [key ...]
  int argc = 3 + (int)key_count;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "BITOP";
  argvlen[0] = 5;
  argv[1] = op;
  argvlen[1] = op_len;
  argv[2] = d;
  argvlen[2] = d_len;

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
    lean_object* error = mk_redis_null_reply_error("BITOP returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t result_len = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(result_len));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "BITOP returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
