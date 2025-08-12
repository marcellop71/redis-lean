// lpos :: UInt64 -> ByteArray -> ByteArray -> Option UInt64 -> Option UInt64 -> EIO Error (Option Int64)
// Find the position of an element in a list
// rank: if provided, return the Nth match
// count: if provided, return up to count matches
lean_obj_res l_hiredis_lpos(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg element, b_lean_obj_arg rank_opt, b_lean_obj_arg count_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* e = (const char*)lean_sarray_cptr(element);
  size_t e_len = lean_sarray_size(element);

  // Build command dynamically based on options
  const char* argv[8];
  size_t argvlen[8];
  int argc = 3;

  argv[0] = "LPOS";
  argvlen[0] = 4;
  argv[1] = k;
  argvlen[1] = k_len;
  argv[2] = e;
  argvlen[2] = e_len;

  char rank_str[32], count_str[32];

  // Add RANK if provided
  if (!lean_is_scalar(rank_opt)) {
    int64_t rank = (int64_t)lean_unbox_uint64(lean_ctor_get(rank_opt, 0));
    snprintf(rank_str, sizeof(rank_str), "%ld", (long)rank);
    argv[argc] = "RANK";
    argvlen[argc] = 4;
    argc++;
    argv[argc] = rank_str;
    argvlen[argc] = strlen(rank_str);
    argc++;
  }

  // Add COUNT if provided
  if (!lean_is_scalar(count_opt)) {
    uint64_t count = lean_unbox_uint64(lean_ctor_get(count_opt, 0));
    snprintf(count_str, sizeof(count_str), "%lu", (unsigned long)count);
    argv[argc] = "COUNT";
    argvlen[argc] = 5;
    argc++;
    argv[argc] = count_str;
    argvlen[argc] = strlen(count_str);
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("LPOS returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    // Element not found - return None
    out = lean_box(0); // Option.none
  } else if (r->type == REDIS_REPLY_INTEGER) {
    // Found - return Some position
    int64_t pos = (int64_t)r->integer;
    lean_object* some = lean_alloc_ctor(1, 1, 0); // Option.some
    lean_ctor_set(some, 0, lean_box_uint64((uint64_t)pos));
    out = some;
  } else if (r->type == REDIS_REPLY_ARRAY) {
    // COUNT was specified - return first match or None
    if (r->elements > 0 && r->element[0]->type == REDIS_REPLY_INTEGER) {
      int64_t pos = (int64_t)r->element[0]->integer;
      lean_object* some = lean_alloc_ctor(1, 1, 0);
      lean_ctor_set(some, 0, lean_box_uint64((uint64_t)pos));
      out = some;
    } else {
      out = lean_box(0);
    }
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "LPOS returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
