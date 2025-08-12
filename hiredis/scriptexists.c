// scriptexists :: UInt64 -> List ByteArray -> EIO Error (List Bool)
// Check existence of scripts in the script cache
lean_obj_res l_hiredis_scriptexists(uint64_t ctx, b_lean_obj_arg sha1s, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  // Count SHA1s
  size_t sha_count = 0;
  lean_object* tmp = sha1s;
  while (!lean_is_scalar(tmp)) {
    sha_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  if (sha_count == 0) {
    return lean_io_result_mk_ok(lean_box(0)); // empty list
  }

  // Build argv: SCRIPT EXISTS sha1 [sha1 ...]
  int argc = 2 + (int)sha_count;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "SCRIPT";
  argvlen[0] = 6;
  argv[1] = "EXISTS";
  argvlen[1] = 6;

  tmp = sha1s;
  int idx = 2;
  while (!lean_is_scalar(tmp)) {
    lean_object* sha = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(sha);
    argvlen[idx] = lean_sarray_size(sha);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SCRIPT EXISTS returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_ARRAY) {
    lean_object* result_list = lean_box(0);
    for (int i = (int)r->elements - 1; i >= 0; i--) {
      redisReply* element = r->element[i];
      uint8_t exists = (element->type == REDIS_REPLY_INTEGER && element->integer != 0) ? 1 : 0;
      lean_object* list_node = lean_alloc_ctor(1, 2, 0);
      lean_ctor_set(list_node, 0, lean_box(exists));
      lean_ctor_set(list_node, 1, result_list);
      result_list = list_node;
    }
    freeReplyObject(r);
    return lean_io_result_mk_ok(result_list);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SCRIPT EXISTS returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
