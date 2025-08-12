// time :: UInt64 -> EIO Error (UInt64 × UInt64)
// Get the current server time (seconds, microseconds)
lean_obj_res l_hiredis_time(uint64_t ctx, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  redisReply* r = (redisReply*)redisCommand(c, "TIME");

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("TIME returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_ARRAY && r->elements >= 2) {
    uint64_t seconds = 0;
    uint64_t microseconds = 0;

    redisReply* sec_reply = r->element[0];
    redisReply* usec_reply = r->element[1];

    if (sec_reply->type == REDIS_REPLY_STRING && sec_reply->str) {
      seconds = strtoull(sec_reply->str, NULL, 10);
    }
    if (usec_reply->type == REDIS_REPLY_STRING && usec_reply->str) {
      microseconds = strtoull(usec_reply->str, NULL, 10);
    }

    lean_object* tuple = lean_alloc_ctor(0, 2, 0);
    lean_ctor_set(tuple, 0, lean_box_uint64(seconds));
    lean_ctor_set(tuple, 1, lean_box_uint64(microseconds));
    freeReplyObject(r);
    return lean_io_result_mk_ok(tuple);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "TIME returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
