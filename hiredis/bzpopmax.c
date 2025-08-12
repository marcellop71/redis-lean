// bzpopmax :: UInt64 -> List ByteArray -> Float -> EIO Error (Option (ByteArray × ByteArray × ByteArray))
// Blocking pop with highest score from multiple sorted sets
// Returns (key, member, score) or none on timeout
lean_obj_res l_hiredis_bzpopmax(uint64_t ctx, b_lean_obj_arg keys, double timeout, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  // Count keys
  size_t key_count = 0;
  lean_object* tmp = keys;
  while (!lean_is_scalar(tmp)) {
    key_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  if (key_count == 0) {
    return lean_io_result_mk_ok(lean_box(0)); // none
  }

  // Build argv: BZPOPMAX key [key ...] timeout
  int argc = 1 + (int)key_count + 1;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "BZPOPMAX";
  argvlen[0] = 8;

  tmp = keys;
  int idx = 1;
  while (!lean_is_scalar(tmp)) {
    lean_object* key = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(key);
    argvlen[idx] = lean_sarray_size(key);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  char timeout_str[64];
  snprintf(timeout_str, sizeof(timeout_str), "%.6f", timeout);
  argv[idx] = timeout_str;
  argvlen[idx] = strlen(timeout_str);

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("BZPOPMAX returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_NIL) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0)); // none (timeout)
  } else if (r->type == REDIS_REPLY_ARRAY && r->elements >= 3) {
    // Build (key, member, score) tuple
    redisReply* key_reply = r->element[0];
    redisReply* member_reply = r->element[1];
    redisReply* score_reply = r->element[2];

    lean_object* key_ba = lean_alloc_sarray(1, key_reply->len, key_reply->len);
    memcpy(lean_sarray_cptr(key_ba), key_reply->str, key_reply->len);

    lean_object* member_ba = lean_alloc_sarray(1, member_reply->len, member_reply->len);
    memcpy(lean_sarray_cptr(member_ba), member_reply->str, member_reply->len);

    lean_object* score_ba = lean_alloc_sarray(1, score_reply->len, score_reply->len);
    memcpy(lean_sarray_cptr(score_ba), score_reply->str, score_reply->len);

    // Inner tuple (member, score)
    lean_object* inner = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(inner, 0, member_ba);
    lean_ctor_set(inner, 1, score_ba);

    // Outer tuple (key, (member, score))
    lean_object* outer = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(outer, 0, key_ba);
    lean_ctor_set(outer, 1, inner);

    // some
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, outer);

    freeReplyObject(r);
    return lean_io_result_mk_ok(some);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "BZPOPMAX returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
