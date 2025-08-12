// slowlogreset :: UInt64 -> EIO Error Unit
// Reset the slow log
lean_obj_res l_hiredis_slowlogreset(uint64_t ctx, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  redisReply* r = (redisReply*)redisCommand(c, "SLOWLOG RESET");

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("SLOWLOG RESET returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "SLOWLOG RESET returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
