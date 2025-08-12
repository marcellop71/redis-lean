// zrange :: UInt64 -> ByteArray -> Int64 -> Int64 -> EIO RedisError (List ByteArray)
// Get a range of elements from the sorted set stored at key, from start to stop (inclusive). Returns a list of members
// NOTE: Redis returns an error if the value stored at key is not a sorted set
lean_obj_res l_hiredis_zrange(uint64_t ctx, b_lean_obj_arg key, int64_t start, int64_t stop, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  // Convert start and stop to strings for the command
  char start_str[32];
  char stop_str[32];
  snprintf(start_str, sizeof(start_str), "%lld", (long long)start);
  snprintf(stop_str, sizeof(stop_str), "%lld", (long long)stop);
  
  const char* argv[4] = {"ZRANGE", k, start_str, stop_str};
  size_t argvlen[4] = {6, k_len, strlen(start_str), strlen(stop_str)};
  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("ZRANGE returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* result_list;
  if (r->type == REDIS_REPLY_ARRAY) {
    // Build a Lean list from the array reply (sorted set members)
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
        snprintf(error_msg, sizeof(error_msg), "ZRANGE array element %d has unexpected type %d", i, element->type);
        freeReplyObject(r);
        lean_object* error = mk_redis_null_reply_error(error_msg);
        return lean_io_result_mk_error(error);
      }
    }
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    // Redis returns an error if the key exists but is not a sorted set
    if (strstr(r->str, "WRONGTYPE") != NULL) {
      lean_object* error = mk_redis_null_reply_error("WRONGTYPE - key is not a sorted set");
      freeReplyObject(r);
      return lean_io_result_mk_error(error);
    }
    // Other Redis errors
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "ZRANGE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(result_list);
}
