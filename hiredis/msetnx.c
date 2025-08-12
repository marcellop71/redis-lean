// msetnx :: UInt64 -> List (ByteArray × ByteArray) -> EIO Error Bool
// Set multiple key-value pairs only if none exist
// Returns true if all keys were set, false if no keys were set
lean_obj_res l_hiredis_msetnx(uint64_t ctx, b_lean_obj_arg pairs, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  // Count pairs
  size_t num_pairs = 0;
  lean_object* current = pairs;
  while (!lean_is_scalar(current)) {
    num_pairs++;
    current = lean_ctor_get(current, 1);
  }

  if (num_pairs == 0) {
    lean_object* error = mk_redis_reply_error("MSETNX requires at least one key-value pair");
    return lean_io_result_mk_error(error);
  }

  // Build argv: MSETNX key1 val1 key2 val2 ...
  size_t argc = 1 + num_pairs * 2;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "MSETNX";
  argvlen[0] = 6;

  current = pairs;
  size_t i = 1;
  while (!lean_is_scalar(current)) {
    lean_object* pair = lean_ctor_get(current, 0);
    lean_object* key = lean_ctor_get(pair, 0);
    lean_object* value = lean_ctor_get(pair, 1);

    argv[i] = (const char*)lean_sarray_cptr(key);
    argvlen[i] = lean_sarray_size(key);
    i++;
    argv[i] = (const char*)lean_sarray_cptr(value);
    argvlen[i] = lean_sarray_size(value);
    i++;

    current = lean_ctor_get(current, 1);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, (int)argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("MSETNX returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint8_t result = r->integer == 1 ? 1 : 0;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "MSETNX returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
