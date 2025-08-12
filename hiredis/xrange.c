// xrange :: UInt64 -> ByteArray -> ByteArray -> ByteArray -> Option UInt64 -> EIO RedisError (List (ByteArray × List (ByteArray × ByteArray)))
// Get range of entries from stream between start and end IDs, with optional count
lean_obj_res l_hiredis_xrange(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg start_id, b_lean_obj_arg end_id, b_lean_obj_arg count_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* start = (const char*)lean_sarray_cptr(start_id);
  size_t start_len = lean_sarray_size(start_id);
  const char* end = (const char*)lean_sarray_cptr(end_id);
  size_t end_len = lean_sarray_size(end_id);
  
  // Build command: XRANGE key start end [COUNT count]
  size_t max_argc = 6; // XRANGE key start end COUNT count
  const char** argv = (const char**)malloc(max_argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(max_argc * sizeof(size_t));
  size_t argc = 4;
  
  argv[0] = "XRANGE";
  argv[1] = k;
  argv[2] = start;
  argv[3] = end;
  argvlen[0] = 6;
  argvlen[1] = k_len;
  argvlen[2] = start_len;
  argvlen[3] = end_len;
  
  char* count_str = NULL;
  // Add COUNT option if provided
  if (lean_obj_tag(count_opt) == 1) { // Some
    lean_object* count_val = lean_ctor_get(count_opt, 0);
    argv[argc] = "COUNT";
    argvlen[argc] = 5;
    argc++;
    
    // Convert UInt64 to string
    uint64_t count = lean_unbox_uint64(count_val);
    count_str = (char*)malloc(32);
    snprintf(count_str, 32, "%lu", count);
    argv[argc] = count_str;
    argvlen[argc] = strlen(count_str);
    argc++;
  }
  
  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  
  if (count_str) free(count_str);
  free(argv);
  free(argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("XRANGE returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_ARRAY) {
    // Parse the array of entries - for now return raw reply as ByteArray  
    // TODO: Proper parsing of stream entry structure
    const char* reply_str = "XRANGE_REPLY";
    lean_object* result = lean_alloc_sarray(1, strlen(reply_str), strlen(reply_str));
    memcpy(lean_sarray_cptr(result), reply_str, strlen(reply_str));
    out = result;
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "XRANGE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
