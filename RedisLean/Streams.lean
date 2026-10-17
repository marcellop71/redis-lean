/-
  Redis streams with parsed replies.

  `xread`/`xreadgroup`/`xrange` in `Ops`/`FFI` return replies flattened into
  newline-separated text, which loses the structure (and breaks on values containing
  newlines). The functions here run the commands through `FFI.commandArgv` and parse the
  reply tree into stream entries. The parsers are pure, so they can be tested without a
  server.
-/
import RedisLean.FFI
import RedisLean.Monad
import RedisLean.Reply

namespace Redis

namespace FFI

/-- Run any command given as an argument vector (binary-safe) and return the reply tree.
    A top-level error reply raises. -/
@[extern "l_hiredis_command_argv"]
opaque commandArgv (ctx : @& Ctx) (args : @& List ByteArray) : EIO Error Reply

end FFI

/-- One stream entry: its id and field/value pairs (in stream order) -/
structure StreamEntry where
  id : String
  fields : Array (ByteArray × ByteArray)
  deriving Inhabited

namespace StreamEntry

/-- Value of the first field named `name` -/
def field? (e : StreamEntry) (name : String) : Option ByteArray :=
  let key := name.toUTF8
  (e.fields.find? (·.1 == key)).map (·.2)

/-- UTF-8 value of the first field named `name` -/
def fieldString? (e : StreamEntry) (name : String) : Option String :=
  (e.field? name).bind String.fromUTF8?

/-- Parse `[id, [field, value, ...]]`. A nil field list (an entry deleted while pending,
    in XREADGROUP history) gives an entry without fields. -/
def parse : Reply → Except String StreamEntry
  | .arr #[idReply, .arr kvs] => do
    let some id := idReply.asString? | throw s!"stream entry id is not a string: {idReply}"
    if kvs.size % 2 != 0 then throw s!"stream entry {id} has an odd number of field items"
    let mut fields := #[]
    for i in [:kvs.size / 2] do
      match kvs[2 * i]!, kvs[2 * i + 1]! with
      | .str k, .str v => fields := fields.push (k, v)
      | k, v => throw s!"stream entry {id}: unexpected field/value {k} {v}"
    pure { id, fields }
  | .arr #[idReply, .nil] => do
    let some id := idReply.asString? | throw s!"stream entry id is not a string: {idReply}"
    pure { id, fields := #[] }
  | r => throw s!"unexpected stream entry: {r}"

end StreamEntry

/-- Parse an XRANGE / XREVRANGE reply (array of entries; nil → none) -/
def parseStreamEntries : Reply → Except String (Array StreamEntry)
  | .nil => pure #[]
  | .arr entries => entries.mapM StreamEntry.parse
  | r => throw s!"unexpected XRANGE reply: {r}"

/-- Parse an XREAD / XREADGROUP reply into (stream, entries) pairs, in reply order.
    Accepts the RESP2 shape `[[stream, entries], ...]` and the flattened RESP3 map
    `[stream, entries, stream, entries, ...]`; nil (timeout / nothing new) → none. -/
def parseStreamsReply : Reply → Except String (Array (String × Array StreamEntry))
  | .nil => pure #[]
  | .arr items => do
    let pairs : Array (Reply × Reply) ←
      if items.all (fun | .arr #[_, _] => true | _ => false) then
        items.mapM fun
          | .arr #[s, es] => pure (s, es)
          | r => throw s!"unexpected stream reply item: {r}"
      else if items.size % 2 == 0 then
        pure ((List.range (items.size / 2)).toArray.map fun i => (items[2 * i]!, items[2 * i + 1]!))
      else throw s!"unexpected XREAD reply: {Reply.arr items}"
    pairs.mapM fun (s, es) => do
      let some stream := s.asString? | throw s!"stream name is not a string: {s}"
      pure (stream, ← parseStreamEntries es)
  | r => throw s!"unexpected XREAD reply: {r}"

/-- Run a command (argument vector of strings) and return its reply tree -/
def commandReply (cmd : RedisCmd) (args : List String) : RedisM Reply :=
  liftRedisEIO cmd (fun ctx => FFI.commandArgv ctx (args.map String.toUTF8))

private def liftParse (r : Except String α) : RedisM α :=
  match r with
  | .ok a => pure a
  | .error msg => throw (Error.otherError s!"unexpected reply: {msg}")

private def countBlock (count : Option Nat) (blockMs : Option Nat) : List String :=
  (match count with | some n => ["COUNT", toString n] | none => []) ++
  (match blockMs with | some ms => ["BLOCK", toString ms] | none => [])

/-- XREAD: entries after the given id of each stream (`$` = only new ones).
    `blockMs` waits up to that long for data (0 = forever); returns no entries on timeout. -/
def xreadEntries (streams : List (String × String)) (count : Option Nat := none) (blockMs : Option Nat := none)
    : RedisM (Array (String × Array StreamEntry)) := do
  let args := ["XREAD"] ++ countBlock count blockMs ++ ["STREAMS"] ++ streams.map (·.1) ++ streams.map (·.2)
  liftParse (parseStreamsReply (← commandReply .XREAD args))

/-- XREADGROUP: entries for `consumer` in `group` (id `>` = never delivered to the group,
    `0` = this consumer's pending entries). -/
def xreadgroupEntries (group consumer : String) (streams : List (String × String))
    (count : Option Nat := none) (blockMs : Option Nat := none) (noAck : Bool := false)
    : RedisM (Array (String × Array StreamEntry)) := do
  let args := ["XREADGROUP", "GROUP", group, consumer] ++ countBlock count blockMs ++
    (if noAck then ["NOACK"] else []) ++ ["STREAMS"] ++ streams.map (·.1) ++ streams.map (·.2)
  liftParse (parseStreamsReply (← commandReply .XREADGROUP args))

/-- XRANGE: entries of `key` with ids in [start, end] (`-` / `+` for the extremes) -/
def xrangeEntries (key start stop : String) (count : Option Nat := none) : RedisM (Array StreamEntry) := do
  let args := ["XRANGE", key, start, stop] ++ (match count with | some n => ["COUNT", toString n] | none => [])
  liftParse (parseStreamEntries (← commandReply .XRANGE args))

end Redis
