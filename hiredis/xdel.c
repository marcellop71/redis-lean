// xdel :: UInt64 -> ByteArray -> List ByteArray -> EIO RedisError UInt64
// Delete specific entries from a stream by ID
lean_obj_res l_hiredis_xdel(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg entry_ids, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  // Count entry IDs
  lean_object* id_list = entry_ids;
  size_t id_count = 0;
  while (lean_obj_tag(id_list) != 0) { // while not Nil
    id_count++;
    id_list = lean_ctor_get(id_list, 1); // get tail
  }
  
  if (id_count == 0) {
    lean_object* error = mk_redis_reply_error("XDEL: no entry IDs provided");
    return lean_io_result_mk_error(error);
  }
  
  // Build command: XDEL key id1 id2 id3 ...
  size_t argc = 2 + id_count;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));
  
  argv[0] = "XDEL";
  argv[1] = k;
  argvlen[0] = 4;
  argvlen[1] = k_len;
  
  // Add entry IDs
  id_list = entry_ids;
  size_t arg_idx = 2;
  while (lean_obj_tag(id_list) != 0) {
    lean_object* entry_id = lean_ctor_get(id_list, 0); // get head
    argv[arg_idx] = (const char*)lean_sarray_cptr(entry_id);
    argvlen[arg_idx] = lean_sarray_size(entry_id);
    arg_idx++;
    id_list = lean_ctor_get(id_list, 1); // get tail
  }
  
  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  
  free(argv);
  free(argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("XDEL returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_INTEGER) {
    out = lean_box_uint64((uint64_t)r->integer);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "XDEL returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
