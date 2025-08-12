// subscribe :: UInt64 -> String -> EIO RedisError Bool
lean_obj_res l_hiredis_subscribe(uint64_t ctx, b_lean_obj_arg channel, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* ch = lean_string_cstr(channel);
  
  redisReply* r = (redisReply*)redisCommand(c, "SUBSCRIBE %s", ch);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SUBSCRIBE returned NULL");
    return lean_io_result_mk_error(error);
  }
  
  // SUBSCRIBE returns an array reply with subscription confirmation
  // [0] = "subscribe", [1] = channel name, [2] = number of subscriptions
  uint8_t success = 0;
  if (r->type == REDIS_REPLY_ARRAY && r->elements >= 3) {
    if (r->element[0]->type == REDIS_REPLY_STRING && 
        strcmp(r->element[0]->str, "subscribe") == 0) {
      success = 1;
    }
  } else if (r->type == REDIS_REPLY_ERROR) {
    char error_msg[512];
    snprintf(error_msg, sizeof(error_msg), "SUBSCRIBE error: %s", r->str);
    freeReplyObject(r);
    lean_object* error = mk_redis_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SUBSCRIBE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_null_reply_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(lean_box(success));
}
