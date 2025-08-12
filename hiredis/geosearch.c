// geosearch :: UInt64 -> ByteArray -> ByteArray -> ByteArray -> Float -> ByteArray -> Option UInt64 -> EIO Error (List ByteArray)
// Search for members within a circular or rectangular area
// fromType: "FROMMEMBER" or "FROMLONLAT", fromValue: member name or "lon,lat"
// byType: "BYRADIUS" or "BYBOX", radius/width, unit: m/km/ft/mi
lean_obj_res l_hiredis_geosearch(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg from_type, b_lean_obj_arg from_value, b_lean_obj_arg by_type, double radius, b_lean_obj_arg unit, b_lean_obj_arg count_opt, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);
  const char* ft = (const char*)lean_sarray_cptr(from_type);
  size_t ft_len = lean_sarray_size(from_type);
  const char* fv = (const char*)lean_sarray_cptr(from_value);
  size_t fv_len = lean_sarray_size(from_value);
  const char* bt = (const char*)lean_sarray_cptr(by_type);
  size_t bt_len = lean_sarray_size(by_type);
  const char* u = (const char*)lean_sarray_cptr(unit);
  size_t u_len = lean_sarray_size(unit);

  const char* argv[10];
  size_t argvlen[10];
  int argc = 7;

  argv[0] = "GEOSEARCH";
  argvlen[0] = 9;
  argv[1] = k;
  argvlen[1] = k_len;
  argv[2] = ft;
  argvlen[2] = ft_len;
  argv[3] = fv;
  argvlen[3] = fv_len;
  argv[4] = bt;
  argvlen[4] = bt_len;

  char radius_str[64];
  snprintf(radius_str, sizeof(radius_str), "%.17g", radius);
  argv[5] = radius_str;
  argvlen[5] = strlen(radius_str);
  argv[6] = u;
  argvlen[6] = u_len;

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

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("GEOSEARCH returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_ARRAY) {
    lean_object* result_list = lean_box(0);
    for (int i = (int)r->elements - 1; i >= 0; i--) {
      redisReply* element = r->element[i];
      if (element->type == REDIS_REPLY_STRING && element->str) {
        lean_object* byte_array = lean_alloc_sarray(1, element->len, element->len);
        memcpy(lean_sarray_cptr(byte_array), element->str, element->len);
        lean_object* list_node = lean_alloc_ctor(1, 2, 0);
        lean_ctor_set(list_node, 0, byte_array);
        lean_ctor_set(list_node, 1, result_list);
        result_list = list_node;
      }
    }
    freeReplyObject(r);
    return lean_io_result_mk_ok(result_list);
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "GEOSEARCH returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
