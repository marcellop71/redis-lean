// sinter :: UInt64 -> List ByteArray -> EIO Error (List ByteArray)
// Get the intersection of all given sets
lean_obj_res l_hiredis_sinter(uint64_t ctx, b_lean_obj_arg keys, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  size_t num_keys = 0;
  lean_object* current = keys;
  while (!lean_is_scalar(current)) {
    num_keys++;
    current = lean_ctor_get(current, 1);
  }

  if (num_keys == 0) {
    return lean_io_result_mk_ok(lean_box(0));
  }

  size_t argc = 1 + num_keys;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "SINTER";
  argvlen[0] = 6;

  current = keys;
  size_t i = 1;
  while (!lean_is_scalar(current)) {
    lean_object* key = lean_ctor_get(current, 0);
    argv[i] = (const char*)lean_sarray_cptr(key);
    argvlen[i] = lean_sarray_size(key);
    current = lean_ctor_get(current, 1);
    i++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, (int)argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SINTER returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* result_list;
  if (r->type == REDIS_REPLY_ARRAY) {
    result_list = lean_box(0);
    for (int j = (int)r->elements - 1; j >= 0; j--) {
      redisReply* element = r->element[j];
      if (element->type == REDIS_REPLY_STRING && element->str) {
        lean_object* byte_array = lean_alloc_sarray(1, element->len, element->len);
        memcpy(lean_sarray_cptr(byte_array), element->str, element->len);
        lean_object* list_node = lean_alloc_ctor(1, 2, 0);
        lean_ctor_set(list_node, 0, byte_array);
        lean_ctor_set(list_node, 1, result_list);
        result_list = list_node;
      }
    }
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SINTER returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(result_list);
}
