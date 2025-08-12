// hello :: UInt64 -> UInt64 -> EIO RedisError ByteArray
lean_obj_res l_hiredis_hello(uint64_t ctx, uint64_t protocol_version, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  
  redisReply* r = (redisReply*)redisCommand(c, "HELLO %" PRIu64, protocol_version);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("HELLO returned NULL");
    return lean_io_result_mk_error(error);
  }
  
  lean_object* result = NULL;
  
  if (r->type == REDIS_REPLY_ARRAY) {
    // HELLO returns an array of server information
    // For simplicity, we'll serialize it as a string representation
    char* response_str = malloc(4096);
    if (!response_str) {
      freeReplyObject(r);
      lean_object* error = mk_redis_null_reply_error("Failed to allocate memory for HELLO response");
      return lean_io_result_mk_error(error);
    }
    
    snprintf(response_str, 4096, "HELLO response with %zu elements", r->elements);
    
    // Create ByteArray from the response string
    size_t len = strlen(response_str);
    result = lean_alloc_sarray(1, len, len);
    memcpy(lean_sarray_cptr(result), response_str, len);
    
    free(response_str);
  } else if (r->type == REDIS_REPLY_ERROR) {
    char error_msg[512];
    snprintf(error_msg, sizeof(error_msg), "HELLO error: %s", r->str);
    freeReplyObject(r);
    lean_object* error = mk_redis_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "HELLO returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(result);
}
