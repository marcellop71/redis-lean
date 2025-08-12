// ttl :: UInt64 -> ByteArray -> EIO RedisError Int64
// Throws noExpiryDefinedError if the key exists but has no associated expire
// Throws keyNotFoundError if the key does not exist
lean_obj_res l_hiredis_ttl(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  const char* argv[2] = {"TTL", k};
  size_t argvlen[2] = {3, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("redisCommand returned NULL");
    return lean_io_result_mk_error(error);
  }

  int64_t result = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    result = r->integer;
    
    // Check if key does not exist (-2)
    if (result == -2) {
      freeReplyObject(r);
      lean_object* error = mk_redis_key_not_found_error(k);
      return lean_io_result_mk_error(error);
    }
    
    // Check if key exists but has no expiry (-1)
    if (result == -1) {
      freeReplyObject(r);
      lean_object* error = mk_redis_no_expiry_defined_error(k);
      return lean_io_result_mk_error(error);
    }
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "TTL returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64(result));
}

// pttl :: UInt64 -> ByteArray -> EIO RedisError Int64
// Returns the remaining time to live of a key that has a timeout (in milliseconds)
// Throws noExpiryDefinedError if the key exists but has no associated expire
// Throws keyNotFoundError if the key does not exist
lean_obj_res l_hiredis_pttl(uint64_t ctx, b_lean_obj_arg key, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  
  const char* argv[2] = {"PTTL", k};
  size_t argvlen[2] = {4, k_len};
  redisReply* r = (redisReply*)redisCommandArgv(c, 2, argv, argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("redisCommand returned NULL");
    return lean_io_result_mk_error(error);
  }

  int64_t result = 0;
  if (r->type == REDIS_REPLY_INTEGER) {
    result = r->integer;
    
    // Check if key does not exist (-2)
    if (result == -2) {
      freeReplyObject(r);
      lean_object* error = mk_redis_key_not_found_error(k);
      return lean_io_result_mk_error(error);
    }
    
    // Check if key exists but has no expiry (-1)
    if (result == -1) {
      freeReplyObject(r);
      lean_object* error = mk_redis_no_expiry_defined_error(k);
      return lean_io_result_mk_error(error);
    }
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "PTTL returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box_uint64(result));
}