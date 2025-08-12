// dbsize :: UInt64 -> EIO Error UInt64
// Get the number of keys in the current database
lean_obj_res l_hiredis_dbsize(uint64_t ctx, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  redisReply* r = (redisReply*)redisCommand(c, "DBSIZE");

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("DBSIZE returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t size = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(size));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "DBSIZE returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
