namespace RedisLean

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
  | SET     : RedisCmd
  | SETEX   : RedisCmd
  | GET     : RedisCmd
  | DEL     : RedisCmd
  | EXISTS  : RedisCmd
  | TYPE    : RedisCmd
  | INCR    : RedisCmd
  | INCRBY  : RedisCmd
  | DECR    : RedisCmd
  | DECRBY  : RedisCmd
  | SISMEMBER : RedisCmd
  | SCARD   : RedisCmd
  | SADD    : RedisCmd
  | PUBLISH : RedisCmd
  | PING    : RedisCmd
  | XADD    : RedisCmd
  | XREAD   : RedisCmd
  | XRANGE  : RedisCmd
  | XLEN    : RedisCmd
  | XDEL    : RedisCmd
  | XTRIM   : RedisCmd
  deriving Repr, BEq

/-- Convert RedisCmd to string for metrics and logging -/
def RedisCmd.toString : RedisCmd → String
  | .SET      => "SET"
  | .SETEX    => "SETEX"
  | .GET      => "GET"
  | .DEL      => "DEL"
  | .EXISTS   => "EXISTS"
  | .TYPE     => "TYPE"
  | .INCR     => "INCR"
  | .INCRBY   => "INCRBY"
  | .DECR     => "DECR"
  | .DECRBY   => "DECRBY"
  | .SISMEMBER => "SISMEMBER"
  | .SCARD    => "SCARD"
  | .SADD     => "SADD"
  | .PUBLISH  => "PUBLISH"
  | .PING     => "PING"
  | .XADD     => "XADD"
  | .XREAD    => "XREAD"
  | .XRANGE   => "XRANGE"
  | .XLEN     => "XLEN"
  | .XDEL     => "XDEL"
  | .XTRIM    => "XTRIM"

instance : ToString RedisCmd := ⟨RedisCmd.toString⟩

end RedisLean
