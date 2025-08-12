// clientid :: UInt64 -> EIO Error UInt64
// Get the current connection's ID
lean_obj_res l_hiredis_clientid(uint64_t ctx, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  redisReply* r = (redisReply*)redisCommand(c, "CLIENT ID");

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("CLIENT ID returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t id = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(id));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "CLIENT ID returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
