// exec :: UInt64 -> EIO Error (Option (List ByteArray))
// Execute all commands issued after MULTI
// Returns none if WATCH triggered an abort, some list of results otherwise
lean_obj_res l_hiredis_exec(uint64_t ctx, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  redisReply* r = (redisReply*)redisCommand(c, "EXEC");

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("EXEC returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_NIL) {
    // WATCH detected a change - transaction aborted
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0)); // none
  } else if (r->type == REDIS_REPLY_ARRAY) {
    // Transaction executed, return results as raw byte arrays
    lean_object* result_list = lean_box(0);
    for (int i = (int)r->elements - 1; i >= 0; i--) {
      redisReply* element = r->element[i];
      lean_object* byte_array;
      if (element->type == REDIS_REPLY_STRING && element->str) {
        byte_array = lean_alloc_sarray(1, element->len, element->len);
        memcpy(lean_sarray_cptr(byte_array), element->str, element->len);
      } else if (element->type == REDIS_REPLY_STATUS && element->str) {
        size_t len = strlen(element->str);
        byte_array = lean_alloc_sarray(1, len, len);
        memcpy(lean_sarray_cptr(byte_array), element->str, len);
      } else if (element->type == REDIS_REPLY_INTEGER) {
        char int_str[32];
        int len = snprintf(int_str, sizeof(int_str), "%lld", element->integer);
        byte_array = lean_alloc_sarray(1, len, len);
        memcpy(lean_sarray_cptr(byte_array), int_str, len);
      } else if (element->type == REDIS_REPLY_NIL) {
        byte_array = lean_alloc_sarray(1, 0, 0); // empty for nil
      } else {
        byte_array = lean_alloc_sarray(1, 0, 0); // empty for unknown
      }
      lean_object* list_node = lean_alloc_ctor(1, 2, 0);
      lean_ctor_set(list_node, 0, byte_array);
      lean_ctor_set(list_node, 1, result_list);
      result_list = list_node;
    }
    freeReplyObject(r);
    lean_object* some = lean_alloc_ctor(1, 1, 0);
    lean_ctor_set(some, 0, result_list);
    return lean_io_result_mk_ok(some);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "EXEC returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
