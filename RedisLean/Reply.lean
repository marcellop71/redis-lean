/-
  Structured Redis replies (RESP2 shape), as returned by `FFI.commandArgv`.
-/

namespace Redis

/-- A Redis reply. RESP3-only types are mapped onto these shapes by the FFI:
    double/bignum/verbatim → `str`, bool → `int`, map/set/push → `arr`
    (maps flattened to key, value, key, value, ...). -/
inductive Reply where
  | nil
  | int (n : Int)
  | str (b : ByteArray)
  | status (s : String)
  | err (s : String)
  | arr (xs : Array Reply)
  deriving Inhabited

namespace Reply

/-- The UTF-8 text of a `str` or `status` reply -/
def asString? : Reply → Option String
  | .str b => String.fromUTF8? b
  | .status s => some s
  | _ => none

/-- Short human-readable form (for errors and debugging) -/
partial def render : Reply → String
  | .nil => "nil"
  | .int n => toString n
  | .str b => match String.fromUTF8? b with
    | some s => s!"\"{s}\""
    | none => s!"<{b.size} bytes>"
  | .status s => s
  | .err s => s!"(error) {s}"
  | .arr xs => "[" ++ ", ".intercalate (xs.toList.map render) ++ "]"

instance : ToString Reply := ⟨render⟩

end Reply

end Redis
