// hmget :: UInt64 -> ByteArray -> List ByteArray -> EIO Error (List (Option ByteArray))
// Get values for multiple fields
lean_obj_res l_hiredis_hmget(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg fields, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  size_t num_fields = 0;
  lean_object* current = fields;
  while (!lean_is_scalar(current)) {
    num_fields++;
    current = lean_ctor_get(current, 1);
  }

  if (num_fields == 0) {
    return lean_io_result_mk_ok(lean_box(0));
  }

  size_t argc = 2 + num_fields;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "HMGET";
  argvlen[0] = 5;
  argv[1] = k;
  argvlen[1] = k_len;

  current = fields;
  size_t i = 2;
  while (!lean_is_scalar(current)) {
    lean_object* field = lean_ctor_get(current, 0);
    argv[i] = (const char*)lean_sarray_cptr(field);
    argvlen[i] = lean_sarray_size(field);
    current = lean_ctor_get(current, 1);
    i++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, (int)argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("HMGET returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* result_list;
  if (r->type == REDIS_REPLY_ARRAY) {
    result_list = lean_box(0);
    for (int j = (int)r->elements - 1; j >= 0; j--) {
      redisReply* element = r->element[j];
      lean_object* opt_value;

      if (element->type == REDIS_REPLY_NIL) {
        opt_value = lean_box(0); // None
      } else if (element->type == REDIS_REPLY_STRING && element->str) {
        lean_object* byte_array = lean_alloc_sarray(1, element->len, element->len);
        memcpy(lean_sarray_cptr(byte_array), element->str, element->len);
        lean_object* some = lean_alloc_ctor(1, 1, 0);
        lean_ctor_set(some, 0, byte_array);
        opt_value = some;
      } else {
        opt_value = lean_box(0);
      }

      lean_object* list_node = lean_alloc_ctor(1, 2, 0);
      lean_ctor_set(list_node, 0, opt_value);
      lean_ctor_set(list_node, 1, result_list);
      result_list = list_node;
    }
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "HMGET returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(result_list);
}
