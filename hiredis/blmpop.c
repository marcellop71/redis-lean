// blmpop :: UInt64 -> Float -> List ByteArray -> UInt8 -> Option UInt64 -> EIO Error (Option (ByteArray × List ByteArray))
// Blocking pop elements from multiple lists
// timeout: seconds to wait (0 = wait indefinitely)
// direction: 0 = LEFT, 1 = RIGHT
// count: optional count of elements to pop
lean_obj_res l_hiredis_blmpop(uint64_t ctx, double timeout, b_lean_obj_arg keys, uint8_t direction, b_lean_obj_arg count_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  // Count keys
  size_t num_keys = 0;
  lean_object* current = keys;
  while (!lean_is_scalar(current)) {
    num_keys++;
    current = lean_ctor_get(current, 1);
  }

  if (num_keys == 0) {
    lean_object* error = mk_redis_reply_error("BLMPOP requires at least one key");
    return lean_io_result_mk_error(error);
  }

  // Build argv: BLMPOP timeout numkeys key1 key2 ... LEFT|RIGHT [COUNT count]
  size_t max_argc = 6 + num_keys;
  const char** argv = (const char**)malloc(max_argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(max_argc * sizeof(size_t));
  int argc = 0;

  argv[argc] = "BLMPOP";
  argvlen[argc] = 6;
  argc++;

  char timeout_str[32];
  snprintf(timeout_str, sizeof(timeout_str), "%.3f", timeout);
  argv[argc] = timeout_str;
  argvlen[argc] = strlen(timeout_str);
  argc++;

  char numkeys_str[32];
  snprintf(numkeys_str, sizeof(numkeys_str), "%zu", num_keys);
  argv[argc] = numkeys_str;
  argvlen[argc] = strlen(numkeys_str);
  argc++;

  // Add keys
  current = keys;
  while (!lean_is_scalar(current)) {
    lean_object* key = lean_ctor_get(current, 0);
    argv[argc] = (const char*)lean_sarray_cptr(key);
    argvlen[argc] = lean_sarray_size(key);
    argc++;
    current = lean_ctor_get(current, 1);
  }

  // Add direction
  const char* dir = direction == 0 ? "LEFT" : "RIGHT";
  argv[argc] = dir;
  argvlen[argc] = direction == 0 ? 4 : 5;
  argc++;

  // Add COUNT if provided
  char count_str[32];
  if (!lean_is_scalar(count_opt)) {
    uint64_t count = lean_unbox_uint64(lean_ctor_get(count_opt, 0));
    argv[argc] = "COUNT";
    argvlen[argc] = 5;
    argc++;
    snprintf(count_str, sizeof(count_str), "%lu", (unsigned long)count);
    argv[argc] = count_str;
    argvlen[argc] = strlen(count_str);
    argc++;
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("BLMPOP returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    // Timeout - return None
    out = lean_box(0);
  } else if (r->type == REDIS_REPLY_ARRAY && r->elements >= 2) {
    // Reply is [key, [elements...]]
    redisReply* key_reply = r->element[0];
    redisReply* elements_reply = r->element[1];

    if (key_reply->type == REDIS_REPLY_STRING && elements_reply->type == REDIS_REPLY_ARRAY) {
      lean_object* key_ba = lean_alloc_sarray(1, key_reply->len, key_reply->len);
      memcpy(lean_sarray_cptr(key_ba), key_reply->str, key_reply->len);

      lean_object* elem_list = lean_box(0);
      for (int i = (int)elements_reply->elements - 1; i >= 0; i--) {
        redisReply* elem = elements_reply->element[i];
        if (elem->type == REDIS_REPLY_STRING && elem->str) {
          lean_object* elem_ba = lean_alloc_sarray(1, elem->len, elem->len);
          memcpy(lean_sarray_cptr(elem_ba), elem->str, elem->len);
          lean_object* node = lean_alloc_ctor(1, 2, 0);
          lean_ctor_set(node, 0, elem_ba);
          lean_ctor_set(node, 1, elem_list);
          elem_list = node;
        }
      }

      lean_object* tuple = lean_alloc_ctor(0, 2, 0);
      lean_ctor_set(tuple, 0, key_ba);
      lean_ctor_set(tuple, 1, elem_list);

      lean_object* some = lean_alloc_ctor(1, 1, 0);
      lean_ctor_set(some, 0, tuple);
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
    snprintf(error_msg, sizeof(error_msg), "BLMPOP returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
