// smembers :: UInt64 -> ByteArray -> EIO Error (List ByteArray)
lean_obj_res l_hiredis_smembers(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  const char* argv[2] = {"SMEMBERS", k};
  size_t argvlen[2] = {8, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SMEMBERS returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* result_list;
  if (r->type == REDIS_REPLY_ARRAY) {
    // Build a Lean list from the array reply
    result_list = lean_box(0); // Start with empty list (nil)
    
    // Process array elements in reverse order to build list correctly
    for (int i = (int)r->elements - 1; i >= 0; i--) {
      redisReply* element = r->element[i];
      if (element->type == REDIS_REPLY_STRING && element->str) {
        lean_object* byte_array = lean_alloc_sarray(1, element->len, element->len);
        memcpy(lean_sarray_cptr(byte_array), element->str, element->len);
        
        lean_object* list_node = lean_alloc_ctor(1, 2, 0); // cons constructor
        lean_ctor_set(list_node, 0, byte_array);
        lean_ctor_set(list_node, 1, result_list);
        result_list = list_node;
      } else {
        char error_msg[256];
        snprintf(error_msg, sizeof(error_msg), "SMEMBERS array element %d has unexpected type %d", i, element->type);
        freeReplyObject(r);
        lean_object* error = mk_redis_null_reply_error(error_msg);
        return lean_io_result_mk_error(error);
      }
    }
  } else if (r->type == REDIS_REPLY_ERROR) {
    char error_msg[512];
    snprintf(error_msg, sizeof(error_msg), "SMEMBERS error: %s", r->str);
    freeReplyObject(r);
    lean_object* error = mk_redis_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SMEMBERS returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(result_list);
}
