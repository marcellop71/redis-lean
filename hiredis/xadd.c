// xadd :: UInt64 -> ByteArray -> ByteArray -> List (ByteArray × ByteArray) -> EIO RedisError ByteArray
// Adds entry to stream with specified ID (or "*" for auto-generation)
lean_obj_res l_hiredis_xadd(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg stream_id, b_lean_obj_arg field_values, lean_obj_arg w) {
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
  
  // Prepare command: XADD key id field1 value1 field2 value2 ...
  size_t argc = 3 + (pair_count * 2);
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));
  
  argv[0] = "XADD";
  argv[1] = k;
  argv[2] = id;
  argvlen[0] = 4;
  argvlen[1] = k_len;
  argvlen[2] = id_len;
  
  // Add field-value pairs
  fv_list = field_values;
  size_t arg_idx = 3;
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
