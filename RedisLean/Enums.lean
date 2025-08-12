namespace Redis

inductive RedisValue where
  | none      : RedisValue  -- Key doesn't exist
  | string    : RedisValue  -- Byte array holding also Strings and Integers
  | list      : RedisValue  -- List
  | set       : RedisValue  -- Set
  | zset      : RedisValue  -- Sorted set
  | hash      : RedisValue  -- Hash
  | stream    : RedisValue  -- Stream
  | vectorset : RedisValue  -- Vector set (Redis Stack)
  | other     : RedisValue  -- Unknown/other type
deriving Repr, BEq

def RedisValue.fromString (s : String) : RedisValue :=
  match s with
  | "none"      => .none
  | "string"    => .string
  | "list"      => .list
  | "set"       => .set
  | "zset"      => .zset
  | "hash"      => .hash
  | "stream"    => .stream
  | "vectorset" => .vectorset
  | _           => .other

def RedisValue.toString : RedisValue → String
  | .none      => "none"
  | .string    => "string"
  | .list      => "list"
  | .set       => "set"
  | .zset      => "zset"
  | .hash      => "hash"
  | .stream    => "stream"
  | .vectorset => "vectorset"
  | .other     => "other"

/-- Redis command types for type-safe command tracking -/
inductive RedisCmd where
  -- String commands
  | SET     : RedisCmd
  | SETEX   : RedisCmd
  | GET     : RedisCmd
  | APPEND  : RedisCmd
  | GETDEL  : RedisCmd
  | GETEX   : RedisCmd
  | GETRANGE : RedisCmd
  | GETSET  : RedisCmd
  | INCR    : RedisCmd
  | INCRBY  : RedisCmd
  | INCRBYFLOAT : RedisCmd
  | DECR    : RedisCmd
  | DECRBY  : RedisCmd
  | MGET    : RedisCmd
  | MSET    : RedisCmd
  | MSETNX  : RedisCmd
  | SETNX   : RedisCmd
  | SETRANGE : RedisCmd
  | STRLEN  : RedisCmd
  | PSETEX  : RedisCmd
  | LCS     : RedisCmd
  -- Key commands
  | DEL     : RedisCmd
  | EXISTS  : RedisCmd
  | TYPE    : RedisCmd
  | TTL     : RedisCmd
  | PTTL    : RedisCmd
  | KEYS    : RedisCmd
  | SCAN    : RedisCmd
  | EXPIRE  : RedisCmd
  | EXPIREAT : RedisCmd
  | PEXPIRE : RedisCmd
  | PEXPIREAT : RedisCmd
  | PERSIST : RedisCmd
  | RENAME  : RedisCmd
  | RENAMENX : RedisCmd
  | COPY    : RedisCmd
  | UNLINK  : RedisCmd
  | TOUCH   : RedisCmd
  | EXPIRETIME : RedisCmd
  | RANDOMKEY : RedisCmd
  -- Set commands
  | SISMEMBER : RedisCmd
  | SCARD   : RedisCmd
  | SADD    : RedisCmd
  | SMEMBERS : RedisCmd
  | SREM    : RedisCmd
  | SPOP    : RedisCmd
  | SRANDMEMBER : RedisCmd
  | SMOVE   : RedisCmd
  | SMISMEMBER : RedisCmd
  | SDIFF   : RedisCmd
  | SDIFFSTORE : RedisCmd
  | SINTER  : RedisCmd
  | SINTERSTORE : RedisCmd
  | SINTERCARD : RedisCmd
  | SUNION  : RedisCmd
  | SUNIONSTORE : RedisCmd
  | SSCAN   : RedisCmd
  -- List commands
  | LPUSH   : RedisCmd
  | RPUSH   : RedisCmd
  | LPUSHX  : RedisCmd
  | RPUSHX  : RedisCmd
  | LPOP    : RedisCmd
  | RPOP    : RedisCmd
  | LRANGE  : RedisCmd
  | LINDEX  : RedisCmd
  | LLEN    : RedisCmd
  | LSET    : RedisCmd
  | LINSERT : RedisCmd
  | LTRIM   : RedisCmd
  | LREM    : RedisCmd
  | LPOS    : RedisCmd
  | LMOVE   : RedisCmd
  | LMPOP   : RedisCmd
  | BLPOP   : RedisCmd
  | BRPOP   : RedisCmd
  | BLMOVE  : RedisCmd
  | BLMPOP  : RedisCmd
  | RPOPLPUSH : RedisCmd
  | BRPOPLPUSH : RedisCmd
  -- Hash commands
  | HSET    : RedisCmd
  | HGET    : RedisCmd
  | HGETALL : RedisCmd
  | HDEL    : RedisCmd
  | HEXISTS : RedisCmd
  | HINCRBY : RedisCmd
  | HKEYS   : RedisCmd
  | HLEN    : RedisCmd
  | HVALS   : RedisCmd
  | HSETNX  : RedisCmd
  | HMGET   : RedisCmd
  | HMSET   : RedisCmd
  | HINCRBYFLOAT : RedisCmd
  | HSTRLEN : RedisCmd
  | HRANDFIELD : RedisCmd
  | HSCAN   : RedisCmd
  -- Sorted set commands
  | ZADD    : RedisCmd
  | ZCARD   : RedisCmd
  | ZRANGE  : RedisCmd
  | ZSCORE  : RedisCmd
  | ZRANK   : RedisCmd
  | ZREVRANK : RedisCmd
  | ZCOUNT  : RedisCmd
  | ZINCRBY : RedisCmd
  | ZREM    : RedisCmd
  | ZLEXCOUNT : RedisCmd
  | ZMSCORE : RedisCmd
  | ZRANDMEMBER : RedisCmd
  | ZSCAN   : RedisCmd
  | ZRANGEBYSCORE : RedisCmd
  | ZREVRANGE : RedisCmd
  | ZREVRANGEBYSCORE : RedisCmd
  | ZRANGEBYLEX : RedisCmd
  | ZREVRANGEBYLEX : RedisCmd
  | ZREMRANGEBYRANK : RedisCmd
  | ZREMRANGEBYSCORE : RedisCmd
  | ZREMRANGEBYLEX : RedisCmd
  | ZPOPMIN : RedisCmd
  | ZPOPMAX : RedisCmd
  | BZPOPMIN : RedisCmd
  | BZPOPMAX : RedisCmd
  | ZUNIONSTORE : RedisCmd
  | ZINTERSTORE : RedisCmd
  | ZDIFFSTORE : RedisCmd
  | ZUNION  : RedisCmd
  | ZINTER  : RedisCmd
  | ZDIFF   : RedisCmd
  | ZINTERCARD : RedisCmd
  | ZRANGESTORE : RedisCmd
  -- Stream commands
  | XADD    : RedisCmd
  | XREAD   : RedisCmd
  | XREADGROUP : RedisCmd
  | XRANGE  : RedisCmd
  | XLEN    : RedisCmd
  | XDEL    : RedisCmd
  | XTRIM   : RedisCmd
  -- HyperLogLog commands
  | PFADD   : RedisCmd
  | PFCOUNT : RedisCmd
  | PFMERGE : RedisCmd
  -- Geospatial commands
  | GEOADD  : RedisCmd
  | GEODIST : RedisCmd
  | GEOHASH : RedisCmd
  | GEOPOS  : RedisCmd
  | GEOSEARCH : RedisCmd
  | GEOSEARCHSTORE : RedisCmd
  -- Bitmap commands
  | SETBIT  : RedisCmd
  | GETBIT  : RedisCmd
  | BITCOUNT : RedisCmd
  | BITOP   : RedisCmd
  | BITPOS  : RedisCmd
  -- Transaction commands
  | MULTI   : RedisCmd
  | EXEC    : RedisCmd
  | DISCARD : RedisCmd
  | WATCH   : RedisCmd
  | UNWATCH : RedisCmd
  -- Scripting commands
  | EVAL    : RedisCmd
  | EVALSHA : RedisCmd
  | SCRIPTLOAD : RedisCmd
  | SCRIPTEXISTS : RedisCmd
  | SCRIPTFLUSH : RedisCmd
  | SCRIPTKILL : RedisCmd
  -- Pub/Sub commands
  | PUBLISH : RedisCmd
  | SUBSCRIBE : RedisCmd
  -- Connection commands
  | AUTH    : RedisCmd
  | HELLO   : RedisCmd
  | PING    : RedisCmd
  | CLIENTID : RedisCmd
  | CLIENTGETNAME : RedisCmd
  | CLIENTSETNAME : RedisCmd
  | CLIENTLIST : RedisCmd
  | CLIENTINFO : RedisCmd
  | CLIENTKILL : RedisCmd
  | CLIENTPAUSE : RedisCmd
  | CLIENTUNPAUSE : RedisCmd
  | SELECT  : RedisCmd
  | ECHO    : RedisCmd
  | QUIT    : RedisCmd
  | RESET   : RedisCmd
  -- Server commands
  | INFO    : RedisCmd
  | DBSIZE  : RedisCmd
  | LASTSAVE : RedisCmd
  | BGSAVE  : RedisCmd
  | BGREWRITEAOF : RedisCmd
  | TIME    : RedisCmd
  | CONFIGGET : RedisCmd
  | CONFIGSET : RedisCmd
  | CONFIGREWRITE : RedisCmd
  | CONFIGRESETSTAT : RedisCmd
  | MEMORYUSAGE : RedisCmd
  | OBJECTENCODING : RedisCmd
  | OBJECTIDLETIME : RedisCmd
  | OBJECTFREQ : RedisCmd
  | SLOWLOGGET : RedisCmd
  | SLOWLOGLEN : RedisCmd
  | SLOWLOGRESET : RedisCmd
  | FLUSHALL : RedisCmd
  | COMMAND : RedisCmd
  deriving Repr, BEq

/-- Convert RedisCmd to string for metrics and logging -/
def RedisCmd.toString : RedisCmd → String
  -- String commands
  | .SET      => "SET"
  | .SETEX    => "SETEX"
  | .GET      => "GET"
  | .APPEND   => "APPEND"
  | .GETDEL   => "GETDEL"
  | .GETEX    => "GETEX"
  | .GETRANGE => "GETRANGE"
  | .GETSET   => "GETSET"
  | .INCR     => "INCR"
  | .INCRBY   => "INCRBY"
  | .INCRBYFLOAT => "INCRBYFLOAT"
  | .DECR     => "DECR"
  | .DECRBY   => "DECRBY"
  | .MGET     => "MGET"
  | .MSET     => "MSET"
  | .MSETNX   => "MSETNX"
  | .SETNX    => "SETNX"
  | .SETRANGE => "SETRANGE"
  | .STRLEN   => "STRLEN"
  | .PSETEX   => "PSETEX"
  | .LCS      => "LCS"
  -- Key commands
  | .DEL      => "DEL"
  | .EXISTS   => "EXISTS"
  | .TYPE     => "TYPE"
  | .TTL      => "TTL"
  | .PTTL     => "PTTL"
  | .KEYS     => "KEYS"
  | .SCAN     => "SCAN"
  | .EXPIRE   => "EXPIRE"
  | .EXPIREAT => "EXPIREAT"
  | .PEXPIRE  => "PEXPIRE"
  | .PEXPIREAT => "PEXPIREAT"
  | .PERSIST  => "PERSIST"
  | .RENAME   => "RENAME"
  | .RENAMENX => "RENAMENX"
  | .COPY     => "COPY"
  | .UNLINK   => "UNLINK"
  | .TOUCH    => "TOUCH"
  | .EXPIRETIME => "EXPIRETIME"
  | .RANDOMKEY => "RANDOMKEY"
  -- Set commands
  | .SISMEMBER => "SISMEMBER"
  | .SCARD    => "SCARD"
  | .SADD     => "SADD"
  | .SMEMBERS => "SMEMBERS"
  | .SREM     => "SREM"
  | .SPOP     => "SPOP"
  | .SRANDMEMBER => "SRANDMEMBER"
  | .SMOVE    => "SMOVE"
  | .SMISMEMBER => "SMISMEMBER"
  | .SDIFF    => "SDIFF"
  | .SDIFFSTORE => "SDIFFSTORE"
  | .SINTER   => "SINTER"
  | .SINTERSTORE => "SINTERSTORE"
  | .SINTERCARD => "SINTERCARD"
  | .SUNION   => "SUNION"
  | .SUNIONSTORE => "SUNIONSTORE"
  | .SSCAN    => "SSCAN"
  -- List commands
  | .LPUSH    => "LPUSH"
  | .RPUSH    => "RPUSH"
  | .LPUSHX   => "LPUSHX"
  | .RPUSHX   => "RPUSHX"
  | .LPOP     => "LPOP"
  | .RPOP     => "RPOP"
  | .LRANGE   => "LRANGE"
  | .LINDEX   => "LINDEX"
  | .LLEN     => "LLEN"
  | .LSET     => "LSET"
  | .LINSERT  => "LINSERT"
  | .LTRIM    => "LTRIM"
  | .LREM     => "LREM"
  | .LPOS     => "LPOS"
  | .LMOVE    => "LMOVE"
  | .LMPOP    => "LMPOP"
  | .BLPOP    => "BLPOP"
  | .BRPOP    => "BRPOP"
  | .BLMOVE   => "BLMOVE"
  | .BLMPOP   => "BLMPOP"
  | .RPOPLPUSH => "RPOPLPUSH"
  | .BRPOPLPUSH => "BRPOPLPUSH"
  -- Hash commands
  | .HSET     => "HSET"
  | .HGET     => "HGET"
  | .HGETALL  => "HGETALL"
  | .HDEL     => "HDEL"
  | .HEXISTS  => "HEXISTS"
  | .HINCRBY  => "HINCRBY"
  | .HKEYS    => "HKEYS"
  | .HLEN     => "HLEN"
  | .HVALS    => "HVALS"
  | .HSETNX   => "HSETNX"
  | .HMGET    => "HMGET"
  | .HMSET    => "HMSET"
  | .HINCRBYFLOAT => "HINCRBYFLOAT"
  | .HSTRLEN  => "HSTRLEN"
  | .HRANDFIELD => "HRANDFIELD"
  | .HSCAN    => "HSCAN"
  -- Sorted set commands
  | .ZADD     => "ZADD"
  | .ZCARD    => "ZCARD"
  | .ZRANGE   => "ZRANGE"
  | .ZSCORE   => "ZSCORE"
  | .ZRANK    => "ZRANK"
  | .ZREVRANK => "ZREVRANK"
  | .ZCOUNT   => "ZCOUNT"
  | .ZINCRBY  => "ZINCRBY"
  | .ZREM     => "ZREM"
  | .ZLEXCOUNT => "ZLEXCOUNT"
  | .ZMSCORE  => "ZMSCORE"
  | .ZRANDMEMBER => "ZRANDMEMBER"
  | .ZSCAN    => "ZSCAN"
  | .ZRANGEBYSCORE => "ZRANGEBYSCORE"
  | .ZREVRANGE => "ZREVRANGE"
  | .ZREVRANGEBYSCORE => "ZREVRANGEBYSCORE"
  | .ZRANGEBYLEX => "ZRANGEBYLEX"
  | .ZREVRANGEBYLEX => "ZREVRANGEBYLEX"
  | .ZREMRANGEBYRANK => "ZREMRANGEBYRANK"
  | .ZREMRANGEBYSCORE => "ZREMRANGEBYSCORE"
  | .ZREMRANGEBYLEX => "ZREMRANGEBYLEX"
  | .ZPOPMIN  => "ZPOPMIN"
  | .ZPOPMAX  => "ZPOPMAX"
  | .BZPOPMIN => "BZPOPMIN"
  | .BZPOPMAX => "BZPOPMAX"
  | .ZUNIONSTORE => "ZUNIONSTORE"
  | .ZINTERSTORE => "ZINTERSTORE"
  | .ZDIFFSTORE => "ZDIFFSTORE"
  | .ZUNION   => "ZUNION"
  | .ZINTER   => "ZINTER"
  | .ZDIFF    => "ZDIFF"
  | .ZINTERCARD => "ZINTERCARD"
  | .ZRANGESTORE => "ZRANGESTORE"
  -- Stream commands
  | .XADD     => "XADD"
  | .XREAD    => "XREAD"
  | .XREADGROUP => "XREADGROUP"
  | .XRANGE   => "XRANGE"
  | .XLEN     => "XLEN"
  | .XDEL     => "XDEL"
  | .XTRIM    => "XTRIM"
  -- HyperLogLog commands
  | .PFADD    => "PFADD"
  | .PFCOUNT  => "PFCOUNT"
  | .PFMERGE  => "PFMERGE"
  -- Geospatial commands
  | .GEOADD   => "GEOADD"
  | .GEODIST  => "GEODIST"
  | .GEOHASH  => "GEOHASH"
  | .GEOPOS   => "GEOPOS"
  | .GEOSEARCH => "GEOSEARCH"
  | .GEOSEARCHSTORE => "GEOSEARCHSTORE"
  -- Bitmap commands
  | .SETBIT   => "SETBIT"
  | .GETBIT   => "GETBIT"
  | .BITCOUNT => "BITCOUNT"
  | .BITOP    => "BITOP"
  | .BITPOS   => "BITPOS"
  -- Transaction commands
  | .MULTI    => "MULTI"
  | .EXEC     => "EXEC"
  | .DISCARD  => "DISCARD"
  | .WATCH    => "WATCH"
  | .UNWATCH  => "UNWATCH"
  -- Scripting commands
  | .EVAL     => "EVAL"
  | .EVALSHA  => "EVALSHA"
  | .SCRIPTLOAD => "SCRIPT LOAD"
  | .SCRIPTEXISTS => "SCRIPT EXISTS"
  | .SCRIPTFLUSH => "SCRIPT FLUSH"
  | .SCRIPTKILL => "SCRIPT KILL"
  -- Pub/Sub commands
  | .PUBLISH  => "PUBLISH"
  | .SUBSCRIBE => "SUBSCRIBE"
  -- Connection commands
  | .AUTH     => "AUTH"
  | .HELLO    => "HELLO"
  | .PING     => "PING"
  | .CLIENTID => "CLIENT ID"
  | .CLIENTGETNAME => "CLIENT GETNAME"
  | .CLIENTSETNAME => "CLIENT SETNAME"
  | .CLIENTLIST => "CLIENT LIST"
  | .CLIENTINFO => "CLIENT INFO"
  | .CLIENTKILL => "CLIENT KILL"
  | .CLIENTPAUSE => "CLIENT PAUSE"
  | .CLIENTUNPAUSE => "CLIENT UNPAUSE"
  | .SELECT   => "SELECT"
  | .ECHO     => "ECHO"
  | .QUIT     => "QUIT"
  | .RESET    => "RESET"
  -- Server commands
  | .INFO     => "INFO"
  | .DBSIZE   => "DBSIZE"
  | .LASTSAVE => "LASTSAVE"
  | .BGSAVE   => "BGSAVE"
  | .BGREWRITEAOF => "BGREWRITEAOF"
  | .TIME     => "TIME"
  | .CONFIGGET => "CONFIG GET"
  | .CONFIGSET => "CONFIG SET"
  | .CONFIGREWRITE => "CONFIG REWRITE"
  | .CONFIGRESETSTAT => "CONFIG RESETSTAT"
  | .MEMORYUSAGE => "MEMORY USAGE"
  | .OBJECTENCODING => "OBJECT ENCODING"
  | .OBJECTIDLETIME => "OBJECT IDLETIME"
  | .OBJECTFREQ => "OBJECT FREQ"
  | .SLOWLOGGET => "SLOWLOG GET"
  | .SLOWLOGLEN => "SLOWLOG LEN"
  | .SLOWLOGRESET => "SLOWLOG RESET"
  | .FLUSHALL => "FLUSHALL"
  | .COMMAND  => "COMMAND"

instance : ToString RedisCmd := ⟨RedisCmd.toString⟩

end Redis
