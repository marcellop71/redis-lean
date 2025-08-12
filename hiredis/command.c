// Helper function to split command string into arguments
// Returns the number of arguments found, or -1 on error
static int parse_command_args(const char* command, char*** argv_out, size_t** argvlen_out) {
  if (!command || strlen(command) == 0) {
    return -1;
  }
  
  // First pass: count arguments
  int argc = 0;
  const char* p = command;
  int in_quotes = 0;
  int in_arg = 0;
  
  while (*p) {
    if (*p == '"' && (p == command || *(p-1) != '\\')) {
      in_quotes = !in_quotes;
      if (!in_arg) {
        argc++;
        in_arg = 1;
      }
    } else if (!in_quotes && (*p == ' ' || *p == '\t')) {
      in_arg = 0;
    } else if (!in_arg) {
      argc++;
      in_arg = 1;
    }
    p++;
  }

  if (argc == 0) {
    return -1;
  }
  
  // Allocate arrays
  char** argv = (char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));
  
  if (!argv || !argvlen) {
    if (argv) free(argv);
    if (argvlen) free(argvlen);
    return -1;
  }
  
  // Second pass: extract arguments
  int arg_idx = 0;
  p = command;
  in_quotes = 0;
  in_arg = 0;
  const char* arg_start = NULL;
  
  while (*p && arg_idx < argc) {
    if (*p == '"' && (p == command || *(p-1) != '\\')) {
      if (!in_quotes) {
        // Start of quoted argument
        in_quotes = 1;
        if (!in_arg) {
          arg_start = p + 1;  // Skip the opening quote
          in_arg = 1;
        }
      } else {
        // End of quoted argument
        in_quotes = 0;
        if (in_arg) {
          size_t len = p - arg_start;
          argv[arg_idx] = (char*)malloc(len + 1);
          if (!argv[arg_idx]) {
            // Cleanup on error
            for (int i = 0; i < arg_idx; i++) free(argv[i]);
            free(argv);
            free(argvlen);
            return -1;
          }
          strncpy(argv[arg_idx], arg_start, len);
          argv[arg_idx][len] = '\0';
          argvlen[arg_idx] = len;
          arg_idx++;
          in_arg = 0;
        }
      }
    } else if (!in_quotes && (*p == ' ' || *p == '\t')) {
      if (in_arg) {
        // End of unquoted argument
        size_t len = p - arg_start;
        argv[arg_idx] = (char*)malloc(len + 1);
        if (!argv[arg_idx]) {
          // Cleanup on error
          for (int i = 0; i < arg_idx; i++) free(argv[i]);
          free(argv);
          free(argvlen);
          return -1;
        }
        strncpy(argv[arg_idx], arg_start, len);
        argv[arg_idx][len] = '\0';
        argvlen[arg_idx] = len;
        arg_idx++;
        in_arg = 0;
      }
    } else if (!in_arg) {
      // Start of new argument
      arg_start = p;
      in_arg = 1;
    }
    p++;
  }
  
  // Handle last argument if we're still in one
  if (in_arg && arg_idx < argc) {
    size_t len = p - arg_start;
    if (in_quotes && len > 0) len--; // Remove trailing quote if in quotes
    argv[arg_idx] = (char*)malloc(len + 1);
    if (!argv[arg_idx]) {
      // Cleanup on error
      for (int i = 0; i < arg_idx; i++) free(argv[i]);
      free(argv);
      free(argvlen);
      return -1;
    }
    strncpy(argv[arg_idx], arg_start, len);
    argv[arg_idx][len] = '\0';
    argvlen[arg_idx] = len;
    arg_idx++;
  
  *argv_out = argv;
  *argvlen_out = argvlen;
  return arg_idx;
  }
}

// Helper function to free parsed arguments
static void free_parsed_args(char** argv, int argc) {
  if (argv) {
    for (int i = 0; i < argc; i++) {
      if (argv[i]) free(argv[i]);
    }
    free(argv);
  }
}

// command :: UInt64 -> String -> EIO RedisError ByteArray
// Generic command function that accepts a command string and returns the raw reply as ByteArray
// This allows execution of arbitrary Redis commands
lean_obj_res l_hiredis_command(uint64_t ctx, b_lean_obj_arg command_str, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* cmd = lean_string_cstr(command_str);
  
  // Parse command string into arguments
  char** argv = NULL;
  size_t* argvlen = NULL;
  int argc = parse_command_args(cmd, &argv, &argvlen);
  
  if (argc <= 0) {
    lean_object* error = mk_redis_null_reply_error("failed to parse command arguments");
    return lean_io_result_mk_error(error);
  }

  // Execute command using redisCommandArgv
  redisReply* r = (redisReply*)redisCommandArgv(c, argc, (const char**)argv, argvlen);
  
  // Free parsed arguments
  free_parsed_args(argv, argc);
  if (argvlen) free(argvlen);
  
  if (!r) {
    lean_object* error = mk_redis_null_reply_error("redisCommandArgv returned NULL");
    return lean_io_result_mk_error(error);
  }

  lean_object* result;
  
  // Handle different reply types and convert to ByteArray
  switch (r->type) {
    case REDIS_REPLY_STRING:
    case REDIS_REPLY_STATUS:
      if (r->str) {
        result = lean_alloc_sarray(1, r->len, r->len);
        memcpy(lean_sarray_cptr(result), r->str, r->len);
      } else {
        result = lean_alloc_sarray(1, 0, 0);
      }
      break;
      
    case REDIS_REPLY_INTEGER: {
      // Convert integer to string representation
      char int_str[32];
      int len = snprintf(int_str, sizeof(int_str), "%lld", r->integer);
      result = lean_alloc_sarray(1, len, len);
      memcpy(lean_sarray_cptr(result), int_str, len);
      break;
    }
    
    case REDIS_REPLY_NIL:
      // Return empty ByteArray for NIL
      result = lean_alloc_sarray(1, 0, 0);
      break;
      
    case REDIS_REPLY_ERROR:
      if (r->str) {
        lean_object* error = mk_redis_null_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
      } else {
        freeReplyObject(r);
        lean_object* error = mk_redis_null_reply_error("Redis error with no message");
    return lean_io_result_mk_error(error);
      }
      
    case REDIS_REPLY_ARRAY: {
      // For arrays, create a simple text representation
      // Format: "[elem1,elem2,...]" 
      char* array_str = (char*)malloc(4096); // Start with reasonable size
      if (!array_str) {
        freeReplyObject(r);
        lean_object* error = mk_redis_null_reply_error("memory allocation failed");
    return lean_io_result_mk_error(error);
      }
      
      int pos = 0;
      pos += snprintf(array_str + pos, 4096 - pos, "[");
      
      for (size_t i = 0; i < r->elements && pos < 4090; i++) {
        if (i > 0) {
          pos += snprintf(array_str + pos, 4096 - pos, ",");
        }
        
        redisReply* elem = r->element[i];
        if (elem->type == REDIS_REPLY_STRING && elem->str) {
          pos += snprintf(array_str + pos, 4096 - pos, "\"%.*s\"", (int)elem->len, elem->str);
        } else if (elem->type == REDIS_REPLY_INTEGER) {
          pos += snprintf(array_str + pos, 4096 - pos, "%lld", elem->integer);
        } else if (elem->type == REDIS_REPLY_NIL) {
          pos += snprintf(array_str + pos, 4096 - pos, "null");
        } else {
          pos += snprintf(array_str + pos, 4096 - pos, "?");
        }
      }

      pos += snprintf(array_str + pos, 4096 - pos, "]");
      
      result = lean_alloc_sarray(1, pos, pos);
      memcpy(lean_sarray_cptr(result), array_str, pos);
      free(array_str);
      break;
    }
    
    default: {
      // For unknown types, return type info
      char type_str[64];
      int len = snprintf(type_str, sizeof(type_str), "UNKNOWN_TYPE_%d", r->type);
      result = lean_alloc_sarray(1, len, len);
      memcpy(lean_sarray_cptr(result), type_str, len);
      break;
    }
  }
  
  freeReplyObject(r);
  return lean_io_result_mk_ok(result);
}
