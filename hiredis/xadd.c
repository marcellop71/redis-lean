// xadd :: UInt64 -> ByteArray -> ByteArray -> List (ByteArray × ByteArray) -> Option UInt64 -> EIO RedisError ByteArray
// Adds entry to stream with specified ID (or "*" for auto-generation)
// When maxlen_opt is Some n, uses XADD key MAXLEN ~ n * field value ...
lean_obj_res l_hiredis_xadd(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg stream_id, b_lean_obj_arg field_values, b_lean_obj_arg maxlen_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* id = (const char*)lean_sarray_cptr(stream_id);
  size_t id_len = lean_sarray_size(stream_id);

  // Count field-value pairs
  lean_object* fv_list = field_values;
  size_t pair_count = 0;
  while (lean_obj_tag(fv_list) != 0) { // while not Nil
    pair_count++;
    fv_list = lean_ctor_get(fv_list, 1); // get tail
  }

  // Check if MAXLEN is requested
  int has_maxlen = !lean_is_scalar(maxlen_opt);

  // Prepare command: XADD key [MAXLEN ~ N] id field1 value1 field2 value2 ...
  size_t argc = 3 + (pair_count * 2) + (has_maxlen ? 3 : 0);
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  size_t arg_idx = 0;
  argv[arg_idx] = "XADD";
  argvlen[arg_idx] = 4;
  arg_idx++;

  argv[arg_idx] = k;
  argvlen[arg_idx] = k_len;
  arg_idx++;

  char maxlen_str[32];
  if (has_maxlen) {
    uint64_t maxlen = lean_unbox_uint64(lean_ctor_get(maxlen_opt, 0));
    argv[arg_idx] = "MAXLEN";
    argvlen[arg_idx] = 6;
    arg_idx++;
    argv[arg_idx] = "~";
    argvlen[arg_idx] = 1;
    arg_idx++;
    snprintf(maxlen_str, sizeof(maxlen_str), "%lu", (unsigned long)maxlen);
    argv[arg_idx] = maxlen_str;
    argvlen[arg_idx] = strlen(maxlen_str);
    arg_idx++;
  }

  argv[arg_idx] = id;
  argvlen[arg_idx] = id_len;
  arg_idx++;

  // Add field-value pairs
  fv_list = field_values;
  while (lean_obj_tag(fv_list) != 0) {
    lean_object* pair = lean_ctor_get(fv_list, 0); // get head (field, value)
    lean_object* field = lean_ctor_get(pair, 0);
    lean_object* value = lean_ctor_get(pair, 1);

    argv[arg_idx] = (const char*)lean_sarray_cptr(field);
    argvlen[arg_idx] = lean_sarray_size(field);
    arg_idx++;

    argv[arg_idx] = (const char*)lean_sarray_cptr(value);
    argvlen[arg_idx] = lean_sarray_size(value);
    arg_idx++;

    fv_list = lean_ctor_get(fv_list, 1); // get tail
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("XADD returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_STRING && r->str) {
    // Return the generated stream entry ID
    lean_object* result_id = lean_alloc_sarray(1, r->len, r->len);
    memcpy(lean_sarray_cptr(result_id), r->str, r->len);
    out = result_id;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "XADD returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
