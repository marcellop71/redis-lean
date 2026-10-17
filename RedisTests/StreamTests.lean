import LSpec
import RedisLean.Streams

open Redis LSpec

namespace RedisTests.StreamTests

def s (x : String) : Reply := .str x.toUTF8
def entry (id : String) (kvs : List String) : Reply := .arr #[s id, .arr (kvs.map s).toArray]

def entryOk (r : Reply) (check : StreamEntry → Bool) : Bool :=
  match StreamEntry.parse r with
  | .ok e => check e
  | .error _ => false

def isError : Except String α → Bool
  | .error _ => true
  | .ok _ => false

def streamsOk (r : Reply) (check : Array (String × Array StreamEntry) → Bool) : Bool :=
  match parseStreamsReply r with
  | .ok v => check v
  | .error _ => false

-- XREAD reply: [[stream, [[id, [k, v, ...]], ...]], ...]
def xreadReply : Reply := .arr #[
  .arr #[s "s1", .arr #[entry "1-0" ["event", "PING"], entry "1-1" ["msg", "a\nb", "n", "2"]]],
  .arr #[s "s2", .arr #[entry "2-0" ["x", "y"]]]]

def xrangeOk : Bool :=
  match parseStreamEntries (.arr #[entry "1-0" ["a", "1"], entry "1-1" ["b", "2"]]) with
  | .ok es => es.map (·.id) == #["1-0", "1-1"]
  | .error _ => false

def entryTests : TestSeq :=
  test "entry id and fields" (entryOk (entry "5-1" ["a", "1", "b", "2"]) fun e =>
    e.id == "5-1" && e.fieldString? "a" == some "1" && e.fieldString? "b" == some "2" && e.fields.size == 2) $
  test "values with newlines are kept" (entryOk (entry "5-2" ["msg", "line1\nline2"]) fun e =>
    e.fieldString? "msg" == some "line1\nline2") $
  test "missing field is none" (entryOk (entry "5-3" ["a", "1"]) fun e => (e.field? "zz").isNone) $
  test "deleted pending entry (nil fields)" (entryOk (.arr #[s "5-4", .nil]) fun e => e.id == "5-4" && e.fields.isEmpty) $
  test "odd field list is rejected" (isError (StreamEntry.parse (entry "5-5" ["a"]))) $
  test "non-string id is rejected" (isError (StreamEntry.parse (.arr #[.int 1, .arr #[]])))

def streamsTests : TestSeq :=
  test "XREAD reply: streams in order" (streamsOk xreadReply fun v =>
    v.map (·.1) == #["s1", "s2"] && v[0]!.2.size == 2 && v[1]!.2.size == 1) $
  test "XREAD reply: entries parsed" (streamsOk xreadReply fun v =>
    v[0]!.2[1]!.fieldString? "msg" == some "a\nb" && v[1]!.2[0]!.id == "2-0") $
  test "nil reply (timeout) is no streams" (streamsOk .nil (·.isEmpty)) $
  test "RESP3 flattened map shape" (streamsOk (.arr #[s "s1", .arr #[entry "1-0" ["k", "v"]]]) fun v =>
    v.size == 1 && v[0]!.1 == "s1" && v[0]!.2[0]!.fieldString? "k" == some "v") $
  test "XRANGE reply" xrangeOk $
  test "malformed reply is rejected" (isError (parseStreamsReply (.int 3)))

def allStreamTests : TestSeq :=
  group "Stream reply parsing" (entryTests ++ streamsTests)

end RedisTests.StreamTests
