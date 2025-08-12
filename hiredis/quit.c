// quit :: UInt64 -> EIO Error Unit
// Close the connection
lean_obj_res l_hiredis_quit(uint64_t ctx, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  redisReply* r = (redisReply*)redisCommand(c, "QUIT");

  if (!r) {
    // Connection may have closed already, which is expected
    return lean_io_result_mk_ok(lean_box(0));
  }

  if (r->type == REDIS_REPLY_STATUS && r->str && strcmp(r->str, "OK") == 0) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0));
  }
}
