import Lean.Data.Json

namespace Redis

-- Codec α means that the type α can be serialized and deserialized to and from a ByteArray
class Codec (α : Type u) where
  enc : α → ByteArray
  dec : ByteArray → Except String α

instance : Codec ByteArray where
  enc := id
  dec := .ok

instance : Codec Unit where
  enc _ := String.toUTF8 ""
  dec _ := .ok ()

instance : Codec String where
  enc := String.toUTF8
  dec bytes :=
    match String.fromUTF8? bytes with
    | some str => .ok str
    | none => .error "Invalid UTF-8 bytes"

instance : Codec Nat where
  enc n := String.toUTF8 (toString n)
  dec bytes := do
    let str ← match String.fromUTF8? bytes with
      | some s => .ok s
      | none => .error "Invalid UTF-8 bytes"
    match str.toNat? with
    | some n => .ok n
    | none => .error s!"Cannot dec '{str}' as Nat"

instance : Codec Int where
  enc n := String.toUTF8 (toString n)
  dec bytes := do
    let str ← match String.fromUTF8? bytes with
      | some s => .ok s
      | none => .error "Invalid UTF-8 bytes"
    match str.toInt? with
    | some n => .ok n
    | none => .error s!"Cannot dec '{str}' as Int"

instance : Codec Bool where
  enc b := String.toUTF8 (if b then "true" else "false")
  dec bytes := do
    let str ← match String.fromUTF8? bytes with
      | some s => .ok s
      | none => .error "Invalid UTF-8 bytes"
    match str with
    | "true" => .ok true
    | "false" => .ok false
    | _ => .error s!"Cannot dec '{str}' as Bool"

/-- JSON codec for any type that has ToJson and FromJson instances -/
instance [Lean.ToJson α] [Lean.FromJson α] : Codec α where
  enc a := String.toUTF8 (Lean.toJson a).compress
  dec bytes := do
    let str ← match String.fromUTF8? bytes with
      | some s => .ok s
      | none => .error "Invalid UTF-8 bytes"
    let json ← Lean.Json.parse str |>.mapError (s!"JSON parse error: {·}")
    Lean.fromJson? json |>.mapError (s!"JSON dec error: {·}")

end Redis
