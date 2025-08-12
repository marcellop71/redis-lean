// geodist :: UInt64 -> ByteArray -> ByteArray -> ByteArray -> Option ByteArray -> EIO Error (Option Float)
// Get the distance between two members (unit: m, km, ft, mi)
lean_obj_res l_hiredis_geodist(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg member1, b_lean_obj_arg member2, b_lean_obj_arg unit_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* m1 = (const char*)lean_sarray_cptr(member1);
  size_t m1_len = lean_sarray_size(member1);
  const char* m2 = (const char*)lean_sarray_cptr(member2);
  size_t m2_len = lean_sarray_size(member2);

  const char* argv[5];
  size_t argvlen[5];
  int argc = 4;

  argv[0] = "GEODIST";
  argvlen[0] = 7;
  argv[1] = k;
  argvlen[1] = k_len;
  argv[2] = m1;
  argvlen[2] = m1_len;
  argv[3] = m2;
  argvlen[3] = m2_len;

  if (!lean_is_scalar(unit_opt)) {
    lean_object* unit = lean_ctor_get(unit_opt, 0);
    argv[argc] = (const char*)lean_sarray_cptr(unit);
    argvlen[argc] = lean_sarray_size(unit);
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("GEODIST returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_NIL) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0)); // none
  } else if (r->type == REDIS_REPLY_STRING && r->str) {
    double dist = strtod(r->str, NULL);
    freeReplyObject(r);
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, lean_box_float(dist));
    return lean_io_result_mk_ok(some);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "GEODIST returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
