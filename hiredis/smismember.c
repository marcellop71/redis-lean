// smismember :: UInt64 -> ByteArray -> List ByteArray -> EIO Error (List Bool)
// Check if multiple members exist in a set
lean_obj_res l_hiredis_smismember(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg members, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  size_t num_members = 0;
  lean_object* current = members;
  while (!lean_is_scalar(current)) {
    num_members++;
    current = lean_ctor_get(current, 1);
  }

  if (num_members == 0) {
    return lean_io_result_mk_ok(lean_box(0));
  }

  size_t argc = 2 + num_members;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "SMISMEMBER";
  argvlen[0] = 10;
  argv[1] = k;
  argvlen[1] = k_len;

  current = members;
  size_t i = 2;
  while (!lean_is_scalar(current)) {
    lean_object* member = lean_ctor_get(current, 0);
    argv[i] = (const char*)lean_sarray_cptr(member);
    argvlen[i] = lean_sarray_size(member);
    current = lean_ctor_get(current, 1);
    i++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, (int)argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SMISMEMBER returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* result_list;
  if (r->type == REDIS_REPLY_ARRAY) {
    result_list = lean_box(0);
    for (int j = (int)r->elements - 1; j >= 0; j--) {
      redisReply* element = r->element[j];
      uint8_t is_member = (element->type == REDIS_REPLY_INTEGER && element->integer == 1) ? 1 : 0;
      lean_object* list_node = lean_alloc_ctor(1, 2, 0);
      lean_ctor_set(list_node, 0, lean_box(is_member));
      lean_ctor_set(list_node, 1, result_list);
      result_list = list_node;
    }
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SMISMEMBER returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(result_list);
}
