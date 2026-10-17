import RedisLean.Ops
import RedisLean.Streams
import RedisLean.Monad
import RedisLean.Config
import RedisLean.Cache

open Redis

namespace RedisTests.Integration

/-!
# Integration Tests

These run real commands against a live Redis server. They are **not** LSpec
`test "..." true` placeholders -- each one performs the operation and checks the
value that comes back.

Safety: everything runs in database `15` under the `redis-lean-test:<pid-ish>:`
prefix and deletes its own keys afterwards. Nothing here calls `FLUSHALL`.

They are executed by `RedisTests.TestRunner` (`lake exe redis_tests
integration`), not at elaboration time, so building the project does not
require a running server.
-/

def testConfig : Config := { host := "127.0.0.1", port := 6379, database := 15 }

def testRead : Read := { config := testConfig, enableMetrics := false }

/-- Prefix unique to this run, so concurrent runs cannot collide. -/
def freshPrefix : IO String := do
  let t ← IO.monoNanosNow
  let r ← IO.rand 0 999999
  return s!"redis-lean-test:{t}-{r}:"

/-- Is a server reachable at `testConfig`? -/
def serverAvailable : IO Bool := do
  match ← (FFI.connectConfig testConfig).toBaseIO with
  | .ok ctx => do let _ ← (FFI.close ctx).toBaseIO; return true
  | .error _ => return false

/-! ## Monomorphic helpers

`Ops` is parameterised over the key type, and its class members need the
`Codec` instance supplied explicitly at most call sites. These wrappers pin the
key type to `String` so the tests below read as Redis operations rather than as
instance plumbing. -/

private abbrev S := String

private def rset (k v : S) : RedisM Unit := Redis.set (α := S) (β := S) k v
private def rsetnx (k v : S) : RedisM Bool := Redis.setnx (α := S) (β := S) k v
private def rsetex (k v : S) (sec : Nat) : RedisM Unit := Redis.setex (α := S) (β := S) k v sec
private def rget (k : S) : RedisM S := Redis.getAs (α := S) S k
private def rdel (ks : List S) : RedisM Nat := Redis.del (α := S) ks
private def rexists (k : S) : RedisM Bool := Redis.existsKey (α := S) k
private def rtype (k : S) : RedisM RedisValue := Redis.typeKey (α := S) k
private def rincr (k : S) : RedisM Int := Redis.incr (α := S) k
private def rincrBy (k : S) (n : Int) : RedisM Int := Redis.incrBy (α := S) k n
private def rdecr (k : S) : RedisM Int := Redis.decr (α := S) k
private def rdecrBy (k : S) (n : Int) : RedisM Int := Redis.decrBy (α := S) k n
private def rsadd (k m : S) : RedisM Nat := Redis.sadd (α := S) k m
private def rsismember (k m : S) : RedisM Bool := Redis.sismember (α := S) k m
private def rscard (k : S) : RedisM Nat := Redis.scard (α := S) k
private def rhset (k f v : S) : RedisM Nat := Redis.hset (α := S) (γ := S) k f v
private def rhget (k f : S) : RedisM S := Redis.hgetAs (α := S) S k f
private def rhexists (k f : S) : RedisM Bool := Redis.hexists (α := S) k f
private def rhdel (k f : S) : RedisM Nat := Redis.hdel (α := S) k f
private def rhincrby (k f : S) (n : Int) : RedisM Int := Redis.hincrby (α := S) k f n
private def rzadd (k : S) (score : Float) (m : S) : RedisM Nat := Redis.zadd (α := S) k score m
private def rzcard (k : S) : RedisM Nat := Redis.zcard (α := S) k
private def rzrange (k : S) (a b : Int) : RedisM (List ByteArray) := Redis.zrange (α := S) k a b
private def rttl (k : S) : RedisM Nat := Redis.ttl (α := S) k
private def rpttl (k : S) : RedisM Nat := Redis.pttl (α := S) k
private def rping (msg : S) : RedisM Bool := Redis.ping (α := S) msg

/-- Run `act`, reporting `true` if it raised the expected kind of error. -/
private def raises (kind : String) (act : RedisM α) : RedisM Bool :=
  try
    let _ ← act
    pure false
  catch e =>
    pure (e.kind == kind)

private def utf8 (bs : ByteArray) : String := (String.fromUTF8? bs).getD "<invalid>"

/-! ## Cases -/

/-- One named check. `run` returns `true` when the behaviour is correct. -/
structure Case where
  group : String
  name : String
  run : String → RedisM Bool

private def c (group name : String) (run : String → RedisM Bool) : Case := ⟨group, name, run⟩

def stringCases : List Case := [
  c "String" "SET and GET round-trip" fun p => do
    rset (p ++ "s1") "hello world"
    return (← rget (p ++ "s1")) == "hello world",

  c "String" "SET and GET with special characters" fun p => do
    let v := "line\nbreak\ttab \"quoted\" 100% \\backslash"
    rset (p ++ "s2") v
    return (← rget (p ++ "s2")) == v,

  c "String" "SET and GET unicode" fun p => do
    let v := "héllo ∀x∈ℕ 日本語 🎉"
    rset (p ++ "s3") v
    return (← rget (p ++ "s3")) == v,

  c "String" "SETNX succeeds on a new key" fun p => do
    let _ ← rdel [p ++ "s4"]
    return (← rsetnx (p ++ "s4") "first"),

  c "String" "SETNX reports false on an existing key and leaves it alone" fun p => do
    rset (p ++ "s5") "original"
    let wrote ← rsetnx (p ++ "s5") "replacement"
    return (!wrote) && (← rget (p ++ "s5")) == "original",

  c "String" "GET on a missing key raises keyNotFound" fun p =>
    raises "keyNotFound" (rget (p ++ "s6-absent"))
]

def keyCases : List Case := [
  c "Key" "DEL removes an existing key" fun p => do
    rset (p ++ "k1") "v"
    return (← rdel [p ++ "k1"]) == 1 && !(← rexists (p ++ "k1")),

  c "Key" "DEL on a missing key returns 0" fun p =>
    return (← rdel [p ++ "k2-absent"]) == 0,

  c "Key" "DEL removes multiple keys" fun p => do
    rset (p ++ "k3") "a"; rset (p ++ "k4") "b"; rset (p ++ "k5") "c"
    return (← rdel [p ++ "k3", p ++ "k4", p ++ "k5"]) == 3,

  c "Key" "EXISTS is true for a present key" fun p => do
    rset (p ++ "k6") "v"
    return (← rexists (p ++ "k6")),

  c "Key" "EXISTS is false for a missing key" fun p =>
    return !(← rexists (p ++ "k7-absent")),

  c "Key" "TYPE reports string" fun p => do
    rset (p ++ "k8") "v"
    return (← rtype (p ++ "k8")) == RedisValue.string
]

def numericCases : List Case := [
  c "Numeric" "INCR on a missing key yields 1" fun p => do
    let _ ← rdel [p ++ "n1"]
    return (← rincr (p ++ "n1")) == 1,

  c "Numeric" "INCR on an existing counter" fun p => do
    rset (p ++ "n2") "41"
    return (← rincr (p ++ "n2")) == 42,

  c "Numeric" "INCRBY with a positive amount" fun p => do
    let _ ← rdel [p ++ "n3"]
    return (← rincrBy (p ++ "n3") 10) == 10,

  -- Regression: this returned 18446744073709551615 before the signedness fix.
  c "Numeric" "DECR below zero gives a negative result" fun p => do
    let _ ← rdel [p ++ "n4"]
    return (← rdecr (p ++ "n4")) == -1,

  c "Numeric" "DECRBY below zero gives a negative result" fun p => do
    let _ ← rdel [p ++ "n5"]
    return (← rdecrBy (p ++ "n5") 9) == -9,

  c "Numeric" "INCRBY with a negative amount crosses zero correctly" fun p => do
    rset (p ++ "n6") "3"
    return (← rincrBy (p ++ "n6") (-10)) == -7
]

def setCases : List Case := [
  c "Set" "SADD to a new set returns 1" fun p => do
    let _ ← rdel [p ++ "t1"]
    return (← rsadd (p ++ "t1") "m1") == 1,

  c "Set" "SADD of a duplicate member returns 0" fun p => do
    let _ ← rdel [p ++ "t2"]
    let _ ← rsadd (p ++ "t2") "m1"
    return (← rsadd (p ++ "t2") "m1") == 0,

  c "Set" "SISMEMBER is true for a present member" fun p => do
    let _ ← rdel [p ++ "t3"]
    let _ ← rsadd (p ++ "t3") "m1"
    return (← rsismember (p ++ "t3") "m1"),

  c "Set" "SISMEMBER is false for an absent member" fun p => do
    let _ ← rdel [p ++ "t4"]
    let _ ← rsadd (p ++ "t4") "m1"
    return !(← rsismember (p ++ "t4") "nope"),

  c "Set" "SCARD counts members" fun p => do
    let _ ← rdel [p ++ "t5"]
    let _ ← rsadd (p ++ "t5") "a"
    let _ ← rsadd (p ++ "t5") "b"
    let _ ← rsadd (p ++ "t5") "c"
    return (← rscard (p ++ "t5")) == 3,

  c "Set" "SCARD of a missing set is 0" fun p => do
    let _ ← rdel [p ++ "t6-absent"]
    return (← rscard (p ++ "t6-absent")) == 0
]

def hashCases : List Case := [
  c "Hash" "HSET then HGET round-trips" fun p => do
    let _ ← rdel [p ++ "h1"]
    let _ ← rhset (p ++ "h1") "field" "value"
    return (← rhget (p ++ "h1") "field") == "value",

  c "Hash" "HSET stores multiple fields independently" fun p => do
    let _ ← rdel [p ++ "h2"]
    let _ ← rhset (p ++ "h2") "a" "1"
    let _ ← rhset (p ++ "h2") "b" "2"
    return (← rhget (p ++ "h2") "a") == "1" && (← rhget (p ++ "h2") "b") == "2",

  c "Hash" "HEXISTS is true for a present field" fun p => do
    let _ ← rdel [p ++ "h3"]
    let _ ← rhset (p ++ "h3") "f" "v"
    return (← rhexists (p ++ "h3") "f"),

  c "Hash" "HEXISTS is false for an absent field" fun p => do
    let _ ← rdel [p ++ "h4"]
    let _ ← rhset (p ++ "h4") "f" "v"
    return !(← rhexists (p ++ "h4") "other"),

  c "Hash" "HDEL removes a field" fun p => do
    let _ ← rdel [p ++ "h5"]
    let _ ← rhset (p ++ "h5") "f" "v"
    return (← rhdel (p ++ "h5") "f") == 1 && !(← rhexists (p ++ "h5") "f"),

  -- Regression: HINCRBY was typed `m Nat`, so this wrapped to a huge number.
  c "Hash" "HINCRBY handles negative results" fun p => do
    let _ ← rdel [p ++ "h6"]
    let a ← rhincrby (p ++ "h6") "n" (-5)
    let b ← rhincrby (p ++ "h6") "n" 2
    return a == -5 && b == -3
]

def sortedSetCases : List Case := [
  c "SortedSet" "ZADD to a new sorted set returns 1" fun p => do
    let _ ← rdel [p ++ "z1"]
    return (← rzadd (p ++ "z1") 1.0 "m") == 1,

  c "SortedSet" "ZCARD counts members" fun p => do
    let _ ← rdel [p ++ "z2"]
    let _ ← rzadd (p ++ "z2") 1.0 "a"
    let _ ← rzadd (p ++ "z2") 2.0 "b"
    return (← rzcard (p ++ "z2")) == 2,

  c "SortedSet" "ZRANGE returns members in score order" fun p => do
    let _ ← rdel [p ++ "z3"]
    let _ ← rzadd (p ++ "z3") 3.0 "third"
    let _ ← rzadd (p ++ "z3") 1.0 "first"
    let _ ← rzadd (p ++ "z3") 2.0 "second"
    let members := (← rzrange (p ++ "z3") 0 (-1)).map utf8
    return members == ["first", "second", "third"]
]

def ttlCases : List Case := [
  -- Regression: `setex` fed seconds into a PX (millisecond) parameter, so a
  -- one-hour TTL expired in 3.6 seconds.
  c "TTL" "SETEX expiry is in seconds" fun p => do
    rsetex (p ++ "e1") "v" 3600
    let sec ← rttl (p ++ "e1")
    let ms ← rpttl (p ++ "e1")
    return sec > 3500 && sec <= 3600 && ms > 3500000,

  c "TTL" "SETEX sets an expiry where SET does not" fun p => do
    rsetex (p ++ "e2") "v" 100
    return (← rttl (p ++ "e2")) > 0,

  c "TTL" "TTL on a key with no expiry raises noExpiryDefined" fun p => do
    rset (p ++ "e3") "v"
    raises "noExpiryDefined" (rttl (p ++ "e3")),

  c "TTL" "TTL on a missing key raises keyNotFound" fun p =>
    raises "keyNotFound" (rttl (p ++ "e4-absent"))
]

def lockCases : List Case := [
  c "Lock" "a lock can be acquired once" fun p => do
    let _ ← rdel [p ++ "l1"]
    let tok ← freshLockToken
    return (← acquireLock (p ++ "l1") tok 30),

  c "Lock" "a contending acquire returns false instead of raising" fun p => do
    let _ ← rdel [p ++ "l2"]
    let t1 ← freshLockToken
    let t2 ← freshLockToken
    let first ← acquireLock (p ++ "l2") t1 30
    let second ← acquireLock (p ++ "l2") t2 30
    return first && !second,

  c "Lock" "the lock carries its TTL atomically" fun p => do
    let _ ← rdel [p ++ "l3"]
    let tok ← freshLockToken
    let _ ← acquireLock (p ++ "l3") tok 30
    return (← rttl (p ++ "l3")) > 0,

  c "Lock" "a non-holder cannot release the lock" fun p => do
    let _ ← rdel [p ++ "l4"]
    let t1 ← freshLockToken
    let t2 ← freshLockToken
    let _ ← acquireLock (p ++ "l4") t1 30
    let stolen ← releaseLock (p ++ "l4") t2
    return !stolen && (← rexists (p ++ "l4")),

  c "Lock" "the holder can release the lock" fun p => do
    let _ ← rdel [p ++ "l5"]
    let tok ← freshLockToken
    let _ ← acquireLock (p ++ "l5") tok 30
    let released ← releaseLock (p ++ "l5") tok
    return released && !(← rexists (p ++ "l5"))
]

def connectionCases : List Case := [
  c "Connection" "PING succeeds" fun _ =>
    rping "hello",

  c "Connection" "many commands in sequence stay consistent" fun p => do
    for i in [:25] do
      rset s!"{p}m{i}" s!"value-{i}"
    let mut ok := true
    for i in [:25] do
      if (← rget s!"{p}m{i}") != s!"value-{i}" then ok := false
    let removed ← rdel ((List.range 25).map fun i => s!"{p}m{i}")
    return ok && removed == 25,

  c "Connection" "sequential INCR accumulates" fun p => do
    let _ ← rdel [p ++ "seq"]
    for _ in [:10] do
      let _ ← rincr (p ++ "seq")
    return (← rget (p ++ "seq")) == "10"
]

def streamCases : List Case := [
  c "Stream" "commandReply returns the reply tree" fun p => do
    let _ ← commandReply .RPUSH ["RPUSH", p ++ "l", "a", "b"]
    match ← commandReply .LRANGE ["LRANGE", p ++ "l", "0", "-1"] with
    | .arr #[.str a, .str b] => return String.fromUTF8? a == some "a" && String.fromUTF8? b == some "b"
    | _ => return false,

  c "Stream" "xrangeEntries keeps fields, values with newlines and binary data" fun p => do
    let k := p ++ "st1"
    let _ ← commandReply .XADD ["XADD", k, "*", "msg", "line1\nline2", "n", "1"]
    let _ ← commandReply .XADD ["XADD", k, "*", "msg", "second"]
    let es ← xrangeEntries k "-" "+"
    return es.size == 2 && es[0]!.fieldString? "msg" == some "line1\nline2" &&
      es[0]!.fieldString? "n" == some "1" && es[1]!.fields.size == 1,

  c "Stream" "xreadEntries returns entries after an id, per stream" fun p => do
    let k := p ++ "st2"
    let first ← commandReply .XADD ["XADD", k, "*", "f", "1"]
    let _ ← commandReply .XADD ["XADD", k, "*", "f", "2"]
    let some firstId := first.asString? | return false
    let res ← xreadEntries [(k, firstId)] (count := some 10)
    return res.size == 1 && res[0]!.1 == k && res[0]!.2.size == 1 &&
      res[0]!.2[0]!.fieldString? "f" == some "2",

  c "Stream" "xreadEntries on nothing new returns no streams" fun p => do
    let k := p ++ "st3"
    let _ ← commandReply .XADD ["XADD", k, "*", "f", "1"]
    let res ← xreadEntries [(k, "$")] (blockMs := some 10)
    return res.isEmpty,

  c "Stream" "xreadgroupEntries delivers new entries once, then as pending" fun p => do
    let k := p ++ "st4"
    let _ ← commandReply .COMMAND ["XGROUP", "CREATE", k, "g", "0", "MKSTREAM"]
    let _ ← commandReply .XADD ["XADD", k, "*", "event", "PING"]
    let fresh ← xreadgroupEntries "g" "c1" [(k, ">")]
    let again ← xreadgroupEntries "g" "c1" [(k, ">")]
    let pending ← xreadgroupEntries "g" "c1" [(k, "0")]
    return fresh.size == 1 && fresh[0]!.2[0]!.fieldString? "event" == some "PING" &&
      (again.isEmpty || again.all (·.2.isEmpty)) &&
      pending.size == 1 && pending[0]!.2.size == 1,

  c "Stream" "xrange (text form) returns the entries, not a placeholder" fun p => do
    let k := p ++ "st5"
    let _ ← commandReply .XADD ["XADD", k, "*", "f", "v"]
    let raw ← xrange k "-" "+"
    let text := String.fromUTF8! raw
    return (text.splitOn "\n").contains "f" && (text.splitOn "\n").contains "v"
]

def allCases : List Case :=
  stringCases ++ keyCases ++ numericCases ++ setCases ++ hashCases
    ++ sortedSetCases ++ ttlCases ++ lockCases ++ connectionCases ++ streamCases

/-! ## Cases that need raw FFI rather than the `RedisM` layer -/

/-- Checks that do not fit the `RedisM` shape: connection lifetime, the generic
command parser, and pipelining. Returns `(name, passed)` pairs. -/
def ffiCases (keyPrefix : String) : IO (List (String × Bool)) := do
  let mut out : List (String × Bool) := []

  -- Generic command: a trailing space and a quoted final argument both used to
  -- hit an unreachable `return` in the C argument parser.
  let r ← (do
    let ctx ← FFI.connectConfig testConfig
    let pong ← FFI.command ctx "PING "
    let _ ← FFI.command ctx s!"SET {keyPrefix}q \"hello world\""
    let back ← FFI.Internal.get ctx (keyPrefix ++ "q").toUTF8
    let _ ← FFI.Internal.del ctx [(keyPrefix ++ "q").toUTF8]
    FFI.close ctx
    pure (utf8 pong == "PONG" && utf8 back == "hello world")).toBaseIO
  out := out ++ [("FFI: generic command handles trailing space and quoting", r.toOption.getD false)]

  -- Generic command: an element longer than the old fixed 4096-byte buffer.
  let r2 ← (do
    let ctx ← FFI.connectConfig testConfig
    let k := (keyPrefix ++ "big").toUTF8
    let _ ← FFI.Internal.del ctx [k]
    let _ ← FFI.Internal.rpush ctx k [(String.ofList (List.replicate 6000 'x')).toUTF8]
    let reply ← FFI.command ctx s!"LRANGE {keyPrefix}big 0 -1"
    let _ ← FFI.Internal.del ctx [k]
    FFI.close ctx
    pure (decide (reply.size > 6000))).toBaseIO
  out := out ++ [("FFI: long array element does not overflow the reply buffer", r2.toOption.getD false)]

  -- Pipeline: replies must carry their bytes, in order, binary-safe.
  let r3 ← (do
    let ctx ← FFI.connectConfig testConfig
    let tricky := "a b \"c\" 100% d"
    let replies ← FFI.withPipeline ctx fun pb =>
      pb.set (keyPrefix ++ "p") tricky |>.get (keyPrefix ++ "p")
    let _ ← FFI.Internal.del ctx [(keyPrefix ++ "p").toUTF8]
    FFI.close ctx
    pure (decide (replies.size == 2) && utf8 replies[0]! == "OK" && utf8 replies[1]! == tricky)).toBaseIO
  out := out ++ [("FFI: pipeline returns non-empty replies in order", r3.toOption.getD false)]

  -- Connection lifetime: closing is idempotent, and use after close is a clean
  -- error rather than a crash.
  let r4 ← (do
    let ctx ← FFI.connectConfig testConfig
    FFI.close ctx
    FFI.close ctx
    let used ← (FFI.Internal.ping ctx "x".toUTF8).toBaseIO
    pure (match used with | .error _ => true | .ok _ => false)).toBaseIO
  out := out ++ [("FFI: close is idempotent and use-after-close errors cleanly", r4.toOption.getD false)]

  -- Config.database is honoured.
  let r5 ← (do
    let ctx ← FFI.connectConfig { testConfig with database := 11 }
    let info ← FFI.Internal.command ctx "CLIENT INFO"
    FFI.close ctx
    pure (((utf8 info).splitOn " ").any (· == "db=11"))).toBaseIO
  out := out ++ [("FFI: Config.database selects the configured database", r5.toOption.getD false)]

  return out

/-! ## Runner -/

/-- Run every integration case. Returns `(passed, failed, failureNames)`. -/
def runAll : IO (Nat × Nat × List String) := do
  let keyPrefix ← freshPrefix
  let mut passed := 0
  let mut failed := 0
  let mut failures : List String := []
  let mut lastGroup := ""

  for case in allCases do
    if case.group != lastGroup then
      IO.println s!"  {case.group}:"
      lastGroup := case.group
    let outcome ← runRedisNoState testRead (case.run keyPrefix)
    match outcome with
    | .ok true =>
      IO.println s!"    ✓ {case.name}"
      passed := passed + 1
    | .ok false =>
      IO.println s!"    ✗ {case.name}"
      failed := failed + 1
      failures := failures ++ [s!"{case.group} / {case.name}"]
    | .error e =>
      IO.println s!"    ✗ {case.name}  ({e})"
      failed := failed + 1
      failures := failures ++ [s!"{case.group} / {case.name}: {e}"]

  IO.println "  FFI:"
  for (name, ok) in ← ffiCases keyPrefix do
    if ok then
      IO.println s!"    ✓ {name}"
      passed := passed + 1
    else
      IO.println s!"    ✗ {name}"
      failed := failed + 1
      failures := failures ++ [name]

  -- Sweep anything a failing case left behind.
  let _ ← runRedisNoState testRead (do
    let leftovers ← Redis.keys (α := S) (String.toUTF8 (keyPrefix ++ "*"))
    let names := leftovers.filterMap (fun bs => String.fromUTF8? bs)
    if names.isEmpty then pure 0 else rdel names)

  return (passed, failed, failures)

end RedisTests.Integration
