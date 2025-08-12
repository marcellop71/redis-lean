// Minimal hiredis shim for Lean 4 FFI (blocking)

#include <string.h>
#include <stdint.h>
#include <stdlib.h>
#include <hiredis/hiredis.h>
#include <lean/lean.h>

#include "errors.c"
#include "connect.c"
#include "ping.c"
#include "set.c"
#include "setex.c"
#include "get.c"
#include "del.c"
#include "exists.c"
#include "type.c"
#include "incr.c"
#include "decr.c"
#include "sismember.c"
#include "scard.c"
#include "sadd.c"
#include "publish.c"
#include "flushall.c"
#include "command.c"
#include "ttl.c"
#include "keys.c"
#include "hset.c"
#include "hget.c"
#include "hgetall.c"
#include "hdel.c"
#include "hexists.c"
#include "hincrby.c"
#include "hkeys.c"
#include "zadd.c"
#include "zcard.c"
#include "zrange.c"