// connect :: String -> UInt32 -> EIO RedisError UInt64
lean_obj_res l_hiredis_connect(b_lean_obj_arg host, uint32_t port, lean_obj_arg w) {
  const char* h = lean_string_cstr(host);
  redisContext* c = redisConnect(h, (int)port);
  if (c == NULL) {
    lean_object* error = mk_redis_connect_error_other("alloc/connect returned NULL");
    return lean_io_result_mk_error(error);
  }
  if (c->err) {
    lean_object* error = mk_redis_error_from_context(c);
    redisFree(c);
    return lean_io_result_mk_error(error);
  }
  return lean_io_result_mk_ok(lean_box_uint64((uint64_t)c));
}

// free :: UInt64 -> EIO RedisError Unit
lean_obj_res l_hiredis_free(uint64_t ctx, lean_obj_arg w) {
  redisContext* c = (redisContext*)ctx;
  if (c) redisFree(c);
  return lean_io_result_mk_ok(lean_box(0));
}
