// geohash :: UInt64 -> ByteArray -> List ByteArray -> EIO Error (List (Option ByteArray))
// Get the geohash strings for one or more members
lean_obj_res l_hiredis_geohash(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg members, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  // Count members
  size_t member_count = 0;
  lean_object* tmp = members;
  while (!lean_is_scalar(tmp)) {
    member_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  if (member_count == 0) {
    return lean_io_result_mk_ok(lean_box(0)); // empty list
  }

  // Build argv: GEOHASH key member [member ...]
  int argc = 2 + (int)member_count;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));

  argv[0] = "GEOHASH";
  argvlen[0] = 7;
  argv[1] = k;
  argvlen[1] = k_len;

  tmp = members;
  int idx = 2;
  while (!lean_is_scalar(tmp)) {
    lean_object* member = lean_ctor_get(tmp, 0);
    argv[idx] = (const char*)lean_sarray_cptr(member);
    argvlen[idx] = lean_sarray_size(member);
    idx++;
    tmp = lean_ctor_get(tmp, 1);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("GEOHASH returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_ARRAY) {
    lean_object* result_list = lean_box(0);
    for (int i = (int)r->elements - 1; i >= 0; i--) {
      redisReply* element = r->element[i];
      lean_object* opt_hash;
      if (element->type == REDIS_REPLY_NIL) {
        opt_hash = lean_box(0); // none
      } else if (element->type == REDIS_REPLY_STRING && element->str) {
        lean_object* byte_array = lean_alloc_sarray(1, element->len, element->len);
        memcpy(lean_sarray_cptr(byte_array), element->str, element->len);
        opt_hash = lean_alloc_ctor(1, 1, 0);
        lean_ctor_set(opt_hash, 0, byte_array);
      } else {
        opt_hash = lean_box(0); // none for unexpected
      }
      lean_object* list_node = lean_alloc_ctor(1, 2, 0);
      lean_ctor_set(list_node, 0, opt_hash);
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
    snprintf(error_msg, sizeof(error_msg), "GEOHASH returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
