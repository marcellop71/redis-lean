// blpop :: UInt64 -> List ByteArray -> Float -> EIO Error (Option (ByteArray × ByteArray))
// Blocking pop from the head of lists
// timeout: seconds to wait (0 = wait indefinitely)
lean_obj_res l_hiredis_blpop(uint64_t ctx, b_lean_obj_arg keys, double timeout, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  // Count keys
  size_t num_keys = 0;
  lean_object* current = keys;
  while (!lean_is_scalar(current)) {
    num_keys++;
    current = lean_ctor_get(current, 1);
  }

  if (num_keys == 0) {
    lean_object* error = mk_redis_reply_error("BLPOP requires at least one key");
    return lean_io_result_mk_error(error);
  }

  // Build argv: BLPOP key1 key2 ... timeout
  size_t argc = 2 + num_keys;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "BLPOP";
  argvlen[0] = 5;

  current = keys;
  size_t i = 1;
  while (!lean_is_scalar(current)) {
    lean_object* key = lean_ctor_get(current, 0);
    argv[i] = (const char*)lean_sarray_cptr(key);
    argvlen[i] = lean_sarray_size(key);
    current = lean_ctor_get(current, 1);
    i++;
  }

  char timeout_str[32];
  snprintf(timeout_str, sizeof(timeout_str), "%.3f", timeout);
  argv[i] = timeout_str;
  argvlen[i] = strlen(timeout_str);

  redisReply* r = (redisReply*)redisCommandArgv(c, (int)argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("BLPOP returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    // Timeout - return None
    out = lean_box(0);
  } else if (r->type == REDIS_REPLY_ARRAY && r->elements >= 2) {
    // Reply is [key, value]
    redisReply* key_reply = r->element[0];
    redisReply* value_reply = r->element[1];

    if (key_reply->type == REDIS_REPLY_STRING && value_reply->type == REDIS_REPLY_STRING) {
      lean_object* key_ba = lean_alloc_sarray(1, key_reply->len, key_reply->len);
      memcpy(lean_sarray_cptr(key_ba), key_reply->str, key_reply->len);

      lean_object* value_ba = lean_alloc_sarray(1, value_reply->len, value_reply->len);
      memcpy(lean_sarray_cptr(value_ba), value_reply->str, value_reply->len);

      lean_object* tuple = lean_alloc_ctor(0, 2, 0);
      lean_ctor_set(tuple, 0, key_ba);
      lean_ctor_set(tuple, 1, value_ba);

      lean_object* some = lean_alloc_ctor(1, 1, 0);
      lean_ctor_set(some, 0, tuple);
      out = some;
    } else {
      out = lean_box(0);
    }
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "BLPOP returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
