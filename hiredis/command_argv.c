// Structured replies.
//
// commandArgv :: Ctx -> List ByteArray -> EIO RedisError Reply
//
// Runs any command given as an argument vector (binary-safe, no quoting) and returns
// the reply tree as a Lean `Redis.Reply` (RedisLean/Reply.lean):
//
//   inductive Reply where
//     | nil                     -- tag 0 (boxed scalar)
//     | int (n : Int)           -- tag 1
//     | str (b : ByteArray)     -- tag 2
//     | status (s : String)     -- tag 3
//     | err (s : String)        -- tag 4
//     | arr (xs : Array Reply)  -- tag 5
//
// A top-level error reply raises (like every other wrapper); error replies nested in
// arrays (e.g. EXEC) become `err`. RESP3-only types are mapped onto the RESP2 shapes:
// double/bignum/verbatim -> str, bool -> int, map/set/push -> arr (maps flattened to
// key, value, key, value, ...).

static lean_object* reply_mk_bytes(const char* s, size_t len) {
  lean_object* b = lean_alloc_sarray(1, len, len);
  if (len > 0) memcpy(lean_sarray_cptr(b), s, len);
  return b;
}

static lean_object* reply_mk_ctor1(unsigned tag, lean_object* field) {
  lean_object* o = lean_alloc_ctor(tag, 1, 0);
  lean_ctor_set(o, 0, field);
  return o;
}

static lean_object* reply_to_lean(redisReply* r) {
  if (!r) return lean_box(0);
  switch (r->type) {
    case REDIS_REPLY_INTEGER:
      return reply_mk_ctor1(1, lean_int64_to_int(r->integer));
    case REDIS_REPLY_STRING:
#ifdef REDIS_REPLY_VERB
    case REDIS_REPLY_VERB:
#endif
#ifdef REDIS_REPLY_DOUBLE
    case REDIS_REPLY_DOUBLE:
#endif
#ifdef REDIS_REPLY_BIGNUM
    case REDIS_REPLY_BIGNUM:
#endif
      return reply_mk_ctor1(2, reply_mk_bytes(r->str, r->len));
    case REDIS_REPLY_STATUS:
      return reply_mk_ctor1(3, lean_mk_string_from_bytes(r->str ? r->str : "", r->str ? r->len : 0));
    case REDIS_REPLY_ERROR:
      return reply_mk_ctor1(4, lean_mk_string_from_bytes(r->str ? r->str : "", r->str ? r->len : 0));
#ifdef REDIS_REPLY_BOOL
    case REDIS_REPLY_BOOL:
      return reply_mk_ctor1(1, lean_int64_to_int(r->integer));
#endif
    case REDIS_REPLY_ARRAY:
#ifdef REDIS_REPLY_MAP
    case REDIS_REPLY_MAP:
#endif
#ifdef REDIS_REPLY_SET
    case REDIS_REPLY_SET:
#endif
#ifdef REDIS_REPLY_PUSH
    case REDIS_REPLY_PUSH:
#endif
    {
      lean_object* arr = lean_alloc_array(r->elements, r->elements);
      for (size_t i = 0; i < r->elements; i++) {
        lean_array_set_core(arr, i, reply_to_lean(r->element[i]));
      }
      return reply_mk_ctor1(5, arr);
    }
    case REDIS_REPLY_NIL:
    default:
      return lean_box(0);
  }
}

lean_obj_res l_hiredis_command_argv(b_lean_obj_arg ctx, b_lean_obj_arg args, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  int argc = 0;
  for (lean_object* l = args; !lean_is_scalar(l); l = lean_ctor_get(l, 1)) argc++;
  if (argc == 0) {
    lean_object* error = mk_redis_connect_error_other("Empty command");
    return lean_io_result_mk_error(error);
  }

  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));
  if (!argv || !argvlen) {
    if (argv) free(argv);
    if (argvlen) free(argvlen);
    lean_object* error = mk_redis_connect_error_other("Out of memory");
    return lean_io_result_mk_error(error);
  }
  int i = 0;
  for (lean_object* l = args; !lean_is_scalar(l); l = lean_ctor_get(l, 1), i++) {
    lean_object* arg = lean_ctor_get(l, 0);
    argv[i] = (const char*)lean_sarray_cptr(arg);
    argvlen[i] = lean_sarray_size(arg);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = c->err ? mk_redis_error_from_context(c)
                                : mk_redis_null_reply_error("command returned NULL");
    return lean_io_result_mk_error(error);
  }
  if (r->type == REDIS_REPLY_ERROR) {
    lean_object* error = mk_redis_reply_error(r->str ? r->str : "");
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  }
  lean_object* out = reply_to_lean(r);
  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
