// xread :: UInt64 -> List (ByteArray × ByteArray) -> Option UInt64 -> Option UInt64 -> EIO RedisError (List (ByteArray × List (ByteArray × List (ByteArray × ByteArray))))
// Read from streams: key-id pairs, optional count, optional block timeout

#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// Helper to calculate size needed for serializing a reply to newline-separated format
static size_t calc_reply_size(redisReply* reply) {
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
        total += calc_reply_size(reply->element[i]);
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
static size_t serialize_reply(redisReply* reply, char* buf, size_t offset) {
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
        offset = serialize_reply(reply->element[i], buf, offset);
      }
      return offset;
    }
    case REDIS_REPLY_NIL:
      return offset;
    default:
      return offset;
  }
}

lean_obj_res l_hiredis_xread(uint64_t ctx, b_lean_obj_arg streams, b_lean_obj_arg count_opt, b_lean_obj_arg block_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);

  // Count stream-id pairs
  lean_object* stream_list = streams;
  size_t stream_count = 0;
  while (lean_obj_tag(stream_list) != 0) { // while not Nil
    stream_count++;
    stream_list = lean_ctor_get(stream_list, 1); // get tail
  }

  if (stream_count == 0) {
    lean_object* error = mk_redis_reply_error("XREAD: no streams provided");
    return lean_io_result_mk_error(error);
  }

  // Build command: XREAD [COUNT count] [BLOCK milliseconds] STREAMS stream1 stream2 ... id1 id2 ...
  size_t max_argc = 6 + (stream_count * 2); // XREAD [COUNT n] [BLOCK n] STREAMS + streams + ids
  const char** argv = (const char**)malloc(max_argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(max_argc * sizeof(size_t));
  size_t argc = 0;

  argv[argc] = "XREAD";
  argvlen[argc] = 5;
  argc++;

  // Add COUNT option if provided
  if (lean_obj_tag(count_opt) == 1) { // Some
    lean_object* count_val = lean_ctor_get(count_opt, 0);
    argv[argc] = "COUNT";
    argvlen[argc] = 5;
    argc++;

    // Convert UInt64 to string
    uint64_t count = lean_unbox_uint64(count_val);
    char* count_str = (char*)malloc(32);
    snprintf(count_str, 32, "%lu", count);
    argv[argc] = count_str;
    argvlen[argc] = strlen(count_str);
    argc++;
  }

  // Add BLOCK option if provided
  if (lean_obj_tag(block_opt) == 1) { // Some
    lean_object* block_val = lean_ctor_get(block_opt, 0);
    argv[argc] = "BLOCK";
    argvlen[argc] = 5;
    argc++;

    // Convert UInt64 to string
    uint64_t block = lean_unbox_uint64(block_val);
    char* block_str = (char*)malloc(32);
    snprintf(block_str, 32, "%lu", block);
    argv[argc] = block_str;
    argvlen[argc] = strlen(block_str);
    argc++;
  }

  argv[argc] = "STREAMS";
  argvlen[argc] = 7;
  argc++;

  // Add stream names
  stream_list = streams;
  while (lean_obj_tag(stream_list) != 0) {
    lean_object* pair = lean_ctor_get(stream_list, 0); // get head (stream, id)
    lean_object* stream = lean_ctor_get(pair, 0);

    argv[argc] = (const char*)lean_sarray_cptr(stream);
    argvlen[argc] = lean_sarray_size(stream);
    argc++;

    stream_list = lean_ctor_get(stream_list, 1); // get tail
  }

  // Add stream IDs
  stream_list = streams;
  while (lean_obj_tag(stream_list) != 0) {
    lean_object* pair = lean_ctor_get(stream_list, 0); // get head (stream, id)
    lean_object* stream_id = lean_ctor_get(pair, 1);

    argv[argc] = (const char*)lean_sarray_cptr(stream_id);
    argvlen[argc] = lean_sarray_size(stream_id);
    argc++;

    stream_list = lean_ctor_get(stream_list, 1); // get tail
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  // Free allocated strings
  for (size_t i = 0; i < argc; i++) {
    if (strcmp(argv[i], "COUNT") == 0 || strcmp(argv[i], "BLOCK") == 0) {
      if (i + 1 < argc) {
        free((void*)argv[i + 1]); // Free the number string
        i++; // Skip the next iteration since we handled it
      }
    }
  }
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("XREAD returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* out;
  if (r->type == REDIS_REPLY_NIL) {
    // No data available (timeout or no new entries)
    // Return empty ByteArray
    lean_object* result = lean_alloc_sarray(1, 0, 0);
    out = result;
  } else if (r->type == REDIS_REPLY_ARRAY) {
    // Parse the nested structure and serialize to newline-separated format
    // Structure: Array[ Array[ stream_name, Array[ Array[ entry_id, Array[ field, value, ... ] ] ] ] ]
    size_t total_size = calc_reply_size(r);
    if (total_size == 0) {
      // Empty result
      lean_object* result = lean_alloc_sarray(1, 0, 0);
      out = result;
    } else {
      char* buf = (char*)malloc(total_size + 1);
      size_t written = serialize_reply(r, buf, 0);

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
    snprintf(error_msg, sizeof(error_msg), "XREAD returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
  freeReplyObject(r);
  return lean_io_result_mk_ok(out);
}
