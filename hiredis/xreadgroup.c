// xreadgroup :: UInt64 -> String -> String -> String -> UInt64 -> EIO RedisError ByteArray
// Read from stream using consumer group
// Args: ctx, group, consumer, stream, count

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// Helper to calculate size needed for serializing a reply to newline-separated format
static size_t xrg_calc_reply_size(redisReply* reply) {
  if (!reply) return 0;

  switch (reply->type) {
    case REDIS_REPLY_STRING:
    case REDIS_REPLY_STATUS:
    case REDIS_REPLY_ERROR:
      return reply->len + 1; // +1 for newline
    case REDIS_REPLY_INTEGER: {
      char buf[32];
      return snprintf(buf, sizeof(buf), "%lld", reply->integer) + 1;
    }
    case REDIS_REPLY_ARRAY: {
      size_t total = 0;
      for (size_t i = 0; i < reply->elements; i++) {
        total += xrg_calc_reply_size(reply->element[i]);
      }
      return total;
    }
    case REDIS_REPLY_NIL:
      return 0;
    default:
      return 0;
  }
}

// Helper to serialize a reply to newline-separated format
static size_t xrg_serialize_reply(redisReply* reply, char* buf, size_t offset) {
  if (!reply) return offset;

  switch (reply->type) {
    case REDIS_REPLY_STRING:
    case REDIS_REPLY_STATUS:
    case REDIS_REPLY_ERROR:
      memcpy(buf + offset, reply->str, reply->len);
      offset += reply->len;
      buf[offset++] = '\n';
      return offset;
    case REDIS_REPLY_INTEGER: {
      int written = sprintf(buf + offset, "%lld\n", reply->integer);
      return offset + written;
    }
    case REDIS_REPLY_ARRAY: {
      for (size_t i = 0; i < reply->elements; i++) {
        offset = xrg_serialize_reply(reply->element[i], buf, offset);
      }
      return offset;
    }
    case REDIS_REPLY_NIL:
      return offset;
    default:
      return offset;
  }
}

// xreadgroup :: UInt64 -> String -> String -> String -> UInt64 -> EIO RedisError ByteArray
lean_obj_res l_hiredis_xreadgroup(uint64_t ctx, b_lean_obj_arg group_arg, b_lean_obj_arg consumer_arg,
                                   b_lean_obj_arg stream_arg, uint64_t count, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  const char* group = lean_string_cstr(group_arg);
  const char* consumer = lean_string_cstr(consumer_arg);
  const char* stream = lean_string_cstr(stream_arg);

  // Build command: XREADGROUP GROUP groupname consumername COUNT count STREAMS stream >
  // Using 9 arguments
  const char* argv[9];
  size_t argvlen[9];

  argv[0] = "XREADGROUP";
  argvlen[0] = 10;

  argv[1] = "GROUP";
  argvlen[1] = 5;

  argv[2] = group;
  argvlen[2] = strlen(group);

  argv[3] = consumer;
  argvlen[3] = strlen(consumer);

  argv[4] = "COUNT";
  argvlen[4] = 5;

  char count_str[32];
  snprintf(count_str, sizeof(count_str), "%lu", (unsigned long)count);
  argv[5] = count_str;
  argvlen[5] = strlen(count_str);

  argv[6] = "STREAMS";
  argvlen[6] = 7;

  argv[7] = stream;
  argvlen[7] = strlen(stream);

  argv[8] = ">";  // Read only new messages not yet delivered
  argvlen[8] = 1;

  redisReply* r = (redisReply*)redisCommandArgv(c, 9, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("XREADGROUP returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    // No data available
    lean_object* result = lean_alloc_sarray(1, 0, 0);
    out = result;
  } else if (r->type == REDIS_REPLY_ARRAY) {
    // Parse the nested structure and serialize to newline-separated format
    size_t total_size = xrg_calc_reply_size(r);
    if (total_size == 0) {
      lean_object* result = lean_alloc_sarray(1, 0, 0);
      out = result;
    } else {
      char* buf = (char*)malloc(total_size + 1);
      size_t written = xrg_serialize_reply(r, buf, 0);

      // Remove trailing newline if present
      if (written > 0 && buf[written - 1] == '\n') {
        written--;
      }

      lean_object* result = lean_alloc_sarray(1, written, written);
      memcpy(lean_sarray_cptr(result), buf, written);
      free(buf);
      out = result;
    }
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "XREADGROUP returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }

  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}

// xack :: UInt64 -> String -> String -> String -> EIO RedisError UInt64
// Acknowledge a message in a consumer group
lean_obj_res l_hiredis_xack(uint64_t ctx, b_lean_obj_arg stream_arg, b_lean_obj_arg group_arg,
                             b_lean_obj_arg msgid_arg, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  const char* stream = lean_string_cstr(stream_arg);
  const char* group = lean_string_cstr(group_arg);
  const char* msgid = lean_string_cstr(msgid_arg);

  // XACK stream group id
  const char* argv[4];
  size_t argvlen[4];

  argv[0] = "XACK";
  argvlen[0] = 4;

  argv[1] = stream;
  argvlen[1] = strlen(stream);

  argv[2] = group;
  argvlen[2] = strlen(group);

  argv[3] = msgid;
  argvlen[3] = strlen(msgid);

  redisReply* r = (redisReply*)redisCommandArgv(c, 4, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("XACK returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t result = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(result));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(0));
  }
}

// xgroup_create :: UInt64 -> String -> String -> String -> EIO RedisError Unit
// Create a consumer group
lean_obj_res l_hiredis_xgroup_create(uint64_t ctx, b_lean_obj_arg stream_arg, b_lean_obj_arg group_arg,
                                      b_lean_obj_arg start_id_arg, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  const char* stream = lean_string_cstr(stream_arg);
  const char* group = lean_string_cstr(group_arg);
  const char* start_id = lean_string_cstr(start_id_arg);

  // XGROUP CREATE stream group start_id MKSTREAM
  const char* argv[6];
  size_t argvlen[6];

  argv[0] = "XGROUP";
  argvlen[0] = 6;

  argv[1] = "CREATE";
  argvlen[1] = 6;

  argv[2] = stream;
  argvlen[2] = strlen(stream);

  argv[3] = group;
  argvlen[3] = strlen(group);

  argv[4] = start_id;
  argvlen[4] = strlen(start_id);

  argv[5] = "MKSTREAM";
  argvlen[5] = 8;

  redisReply* r = (redisReply*)redisCommandArgv(c, 6, argv, argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("XGROUP CREATE returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_STATUS || r->type == REDIS_REPLY_STRING) {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0)); // Unit
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box(0)); // Unit
  }
}
