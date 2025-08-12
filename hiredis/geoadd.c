// geoadd :: UInt64 -> ByteArray -> List (Float × Float × ByteArray) -> EIO Error UInt64
// Add geospatial items (longitude, latitude, member) to a sorted set
lean_obj_res l_hiredis_geoadd(uint64_t ctx, b_lean_obj_arg key, b_lean_obj_arg items, lean_obj_arg w) {
  VALIDATE_REDIS_CTX(c, ctx);
  const char* k = (const char*)lean_sarray_cptr(key);
  size_t k_len = lean_sarray_size(key);

  // Count items
  size_t item_count = 0;
  lean_object* tmp = items;
  while (!lean_is_scalar(tmp)) {
    item_count++;
    tmp = lean_ctor_get(tmp, 1);
  }

  if (item_count == 0) {
    return lean_io_result_mk_ok(lean_box_uint64(0));
  }

  // Build argv: GEOADD key longitude latitude member [longitude latitude member ...]
  int argc = 2 + (int)item_count * 3;
  const char** argv = (const char**)malloc(argc * sizeof(char*));
  size_t* argvlen = (size_t*)malloc(argc * sizeof(size_t));
  char** coord_strs = (char**)malloc(item_count * 2 * sizeof(char*));

  argv[0] = "GEOADD";
  argvlen[0] = 6;
  argv[1] = k;
  argvlen[1] = k_len;

  tmp = items;
  int idx = 2;
  int coord_idx = 0;
  while (!lean_is_scalar(tmp)) {
    lean_object* item = lean_ctor_get(tmp, 0);
    // Item is (lon, (lat, member))
    double lon = lean_unbox_float(lean_ctor_get(item, 0));
    lean_object* inner = lean_ctor_get(item, 1);
    double lat = lean_unbox_float(lean_ctor_get(inner, 0));
    lean_object* member = lean_ctor_get(inner, 1);

    coord_strs[coord_idx] = (char*)malloc(64);
    snprintf(coord_strs[coord_idx], 64, "%.17g", lon);
    argv[idx] = coord_strs[coord_idx];
    argvlen[idx] = strlen(coord_strs[coord_idx]);
    idx++;
    coord_idx++;

    coord_strs[coord_idx] = (char*)malloc(64);
    snprintf(coord_strs[coord_idx], 64, "%.17g", lat);
    argv[idx] = coord_strs[coord_idx];
    argvlen[idx] = strlen(coord_strs[coord_idx]);
    idx++;
    coord_idx++;

    argv[idx] = (const char*)lean_sarray_cptr(member);
    argvlen[idx] = lean_sarray_size(member);
    idx++;

    tmp = lean_ctor_get(tmp, 1);
  }

  redisReply* r = (redisReply*)redisCommandArgv(c, argc, argv, argvlen);

  for (int i = 0; i < (int)(item_count * 2); i++) {
    free(coord_strs[i]);
  }
  free(coord_strs);
  free(argv);
  free(argvlen);

  if (!r) {
    lean_object* error = mk_redis_null_reply_error("GEOADD returned NULL");
    return lean_io_result_mk_error(error);
  }

  if (r->type == REDIS_REPLY_INTEGER) {
    uint64_t added = (uint64_t)r->integer;
    freeReplyObject(r);
    return lean_io_result_mk_ok(lean_box_uint64(added));
  } else if (r->type == REDIS_REPLY_ERROR && r->str) {
    lean_object* error = mk_redis_reply_error(r->str);
    freeReplyObject(r);
    return lean_io_result_mk_error(error);
  } else {
    char error_msg[256];
    snprintf(error_msg, sizeof(error_msg), "GEOADD returned unexpected reply type %d", r->type);
    freeReplyObject(r);
    lean_object* error = mk_redis_unexpected_reply_type_error(error_msg);
    return lean_io_result_mk_error(error);
  }
}
