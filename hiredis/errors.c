// Helper functions to create RedisError objects
static lean_object* mk_redis_connect_error_io(const char* msg) {
  lean_object* msg_obj = lean_mk_string(msg);
  lean_object* connect_err = lean_alloc_ctor(0, 1, 0); // IOError constructor
  lean_ctor_set(connect_err, 0, msg_obj);
  lean_object* redis_err = lean_alloc_ctor(0, 1, 0); // connectError constructor
  lean_ctor_set(redis_err, 0, connect_err);
  return redis_err;
}

static lean_object* mk_redis_connect_error_eof(const char* msg) {
  lean_object* msg_obj = lean_mk_string(msg);
  lean_object* connect_err = lean_alloc_ctor(1, 1, 0); // EOFError constructor
  lean_ctor_set(connect_err, 0, msg_obj);
  lean_object* redis_err = lean_alloc_ctor(0, 1, 0); // connectError constructor
  lean_ctor_set(redis_err, 0, connect_err);
  return redis_err;
}

static lean_object* mk_redis_connect_error_protocol(const char* msg) {
  lean_object* msg_obj = lean_mk_string(msg);
  lean_object* connect_err = lean_alloc_ctor(2, 1, 0); // protocolError constructor
  lean_ctor_set(connect_err, 0, msg_obj);
  lean_object* redis_err = lean_alloc_ctor(0, 1, 0); // connectError constructor
  lean_ctor_set(redis_err, 0, connect_err);
  return redis_err;
}

static lean_object* mk_redis_connect_error_other(const char* msg) {
  lean_object* msg_obj = lean_mk_string(msg);
  lean_object* connect_err = lean_alloc_ctor(3, 1, 0); // otherError constructor
  lean_ctor_set(connect_err, 0, msg_obj);
  lean_object* redis_err = lean_alloc_ctor(0, 1, 0); // connectError constructor
  lean_ctor_set(redis_err, 0, connect_err);
  return redis_err;
}

static lean_object* mk_redis_null_reply_error(const char* msg) {
  lean_object* msg_obj = lean_mk_string(msg);
  lean_object* redis_err = lean_alloc_ctor(1, 1, 0); // nullReplyError constructor
  lean_ctor_set(redis_err, 0, msg_obj);
  return redis_err;
}

static lean_object* mk_redis_reply_error(const char* msg) {
  lean_object* msg_obj = lean_mk_string(msg);
  lean_object* redis_err = lean_alloc_ctor(2, 1, 0); // replyError constructor
  lean_ctor_set(redis_err, 0, msg_obj);
  return redis_err;
}

static lean_object* mk_redis_unexpected_reply_type_error(const char* msg) {
  lean_object* msg_obj = lean_mk_string(msg);
  lean_object* redis_err = lean_alloc_ctor(3, 1, 0); // unexpectedReplyTypeError constructor
  lean_ctor_set(redis_err, 0, msg_obj);
  return redis_err;
}

static lean_object* mk_redis_key_not_found_error(const char* key) {
  lean_object* key_obj = lean_mk_string(key);
  lean_object* redis_err = lean_alloc_ctor(4, 1, 0); // keyNotFoundError constructor
  lean_ctor_set(redis_err, 0, key_obj);
  return redis_err;
}

static lean_object* mk_redis_no_expiry_defined_error(const char* key) {
  lean_object* key_obj = lean_mk_string(key);
  lean_object* redis_err = lean_alloc_ctor(5, 1, 0); // noExpiryDefinedError constructor
  lean_ctor_set(redis_err, 0, key_obj);
  return redis_err;
}

static lean_object* mk_redis_error_from_context(redisContext* c) {
  if (!c) {
    return mk_redis_connect_error_other("context is NULL");
  }
  
  switch (c->err) {
    case REDIS_ERR_IO:
      return mk_redis_connect_error_io(c->errstr);
    case REDIS_ERR_EOF:
      return mk_redis_connect_error_eof(c->errstr);
    case REDIS_ERR_PROTOCOL:
      return mk_redis_connect_error_protocol(c->errstr);
    case REDIS_ERR_OTHER:
    default:
      return mk_redis_connect_error_other(c->errstr);
  }
}

