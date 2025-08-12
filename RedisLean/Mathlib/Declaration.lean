import RedisLean.Mathlib.Core

namespace Redis.Mathlib

/-!
# Declaration and Environment Storage for Lean/Mathlib

Store and retrieve Lean declarations with dependency tracking,
and manage environment snapshots for incremental compilation.
-/

open Redis

/-- Kind of a Lean declaration -/
inductive DeclKind where
  | axiomDecl
  | definition
  | theoremDecl
  | opaqueDecl
  | inductiveDecl
  | constructorDecl
  | recursorDecl
  | quotientDecl
  deriving Repr, BEq, Inhabited

instance : Lean.ToJson DeclKind where
  toJson
    | .axiomDecl => "axiom"
    | .definition => "definition"
    | .theoremDecl => "theorem"
    | .opaqueDecl => "opaque"
    | .inductiveDecl => "inductive"
    | .constructorDecl => "constructor"
    | .recursorDecl => "recursor"
    | .quotientDecl => "quotient"

instance : Lean.FromJson DeclKind where
  fromJson? j := do
    let s ← j.getStr?
    match s with
    | "axiom" => return .axiomDecl
    | "definition" => return .definition
    | "theorem" => return .theoremDecl
    | "opaque" => return .opaqueDecl
    | "inductive" => return .inductiveDecl
    | "constructor" => return .constructorDecl
    | "recursor" => return .recursorDecl
    | "quotient" => return .quotientDecl
    | _ => throw s!"Unknown DeclKind: {s}"

/-- Simplified declaration information -/
structure SimpleDeclInfo where
  /-- Declaration name -/
  name : String
  /-- Kind of declaration -/
  kind : DeclKind
  /-- Universe level parameters -/
  levelParams : List String
  /-- Type of the declaration -/
  declType : SimpleExpr
  /-- Value (for definitions/theorems) -/
  value : Option SimpleExpr
  /-- Whether marked unsafe -/
  isUnsafe : Bool
  /-- Module containing this declaration -/
  moduleName : String
  /-- Dependencies (other declarations this uses) -/
  dependencies : List String
  deriving Repr, BEq

instance : Lean.ToJson SimpleDeclInfo where
  toJson d := Lean.Json.mkObj [
    ("name", Lean.toJson d.name),
    ("kind", Lean.toJson d.kind),
    ("levelParams", Lean.toJson d.levelParams),
    ("declType", Lean.toJson d.declType.toEncodedString),
    ("value", match d.value with
      | some v => Lean.toJson v.toEncodedString
      | none => Lean.Json.null),
    ("isUnsafe", Lean.toJson d.isUnsafe),
    ("moduleName", Lean.toJson d.moduleName),
    ("dependencies", Lean.toJson d.dependencies)
  ]

instance : Lean.FromJson SimpleDeclInfo where
  fromJson? j := do
    let name ← j.getObjValAs? String "name"
    let kind ← j.getObjValAs? DeclKind "kind"
    let levelParams ← j.getObjValAs? (List String) "levelParams"
    let typeStr ← j.getObjValAs? String "declType"
    let valueJson := j.getObjVal? "value"
    let value := match valueJson with
      | .ok (.str s) => some (.other s)
      | _ => none
    let isUnsafe ← j.getObjValAs? Bool "isUnsafe"
    let moduleName ← j.getObjValAs? String "moduleName"
    let dependencies ← j.getObjValAs? (List String) "dependencies"
    return {
      name, kind, levelParams
      declType := .other typeStr
      value
      isUnsafe, moduleName, dependencies
    }

instance : Codec SimpleDeclInfo := jsonCodec

/-- Environment snapshot for incremental compilation -/
structure EnvSnapshot where
  /-- Unique snapshot ID -/
  id : String
  /-- Creation timestamp -/
  timestamp : Nat
  /-- List of declaration names in this snapshot -/
  declarations : List String
  /-- Imported modules -/
  imports : List String
  /-- Content hash for cache invalidation -/
  contentHash : UInt64
  deriving Repr, BEq

instance : Lean.ToJson EnvSnapshot where
  toJson s := Lean.Json.mkObj [
    ("id", Lean.toJson s.id),
    ("timestamp", Lean.toJson s.timestamp),
    ("declarations", Lean.toJson s.declarations),
    ("imports", Lean.toJson s.imports),
    ("contentHash", Lean.toJson s.contentHash.toNat)
  ]

instance : Lean.FromJson EnvSnapshot where
  fromJson? j := do
    let id ← j.getObjValAs? String "id"
    let timestamp ← j.getObjValAs? Nat "timestamp"
    let declarations ← j.getObjValAs? (List String) "declarations"
    let imports ← j.getObjValAs? (List String) "imports"
    let contentHash ← j.getObjValAs? Nat "contentHash"
    return { id, timestamp, declarations, imports, contentHash := UInt64.ofNat contentHash }

instance : Codec EnvSnapshot := jsonCodec

/-- Configuration for declaration storage -/
structure DeclStorage where
  /-- Key prefix -/
  keyPrefix : String := "mathlib"
  /-- TTL for declarations (0 = no expiry) -/
  ttlSeconds : Nat := 0
  deriving Repr

namespace DeclStorage

/-- Create a new declaration storage -/
def create (kPrefix : String := "mathlib") (ttl : Nat := 0) : DeclStorage :=
  { keyPrefix := kPrefix, ttlSeconds := ttl }

/-- Store a declaration -/
def storeDecl (storage : DeclStorage) (decl : SimpleDeclInfo) : RedisM Unit := do
  let k := declKey storage.keyPrefix decl.name
  let depsKey := declDepsKey storage.keyPrefix decl.name

  -- Store declaration data as hash fields
  let _ ← hset k "name" (String.toUTF8 decl.name)
  let _ ← hset k "kind" (String.toUTF8 (Lean.toJson decl.kind).compress)
  let _ ← hset k "levelParams" (String.toUTF8 (Lean.toJson decl.levelParams).compress)
  let _ ← hset k "declType" (String.toUTF8 decl.declType.toEncodedString)
  match decl.value with
  | some v => let _ ← hset k "value" (String.toUTF8 v.toEncodedString)
  | none => pure ()
  let _ ← hset k "isUnsafe" (String.toUTF8 (if decl.isUnsafe then "true" else "false"))
  let _ ← hset k "moduleName" (String.toUTF8 decl.moduleName)

  -- Store dependencies in a set
  for dep in decl.dependencies do
    let _ ← sadd depsKey dep

  -- Also track reverse dependencies (who depends on this decl)
  for dep in decl.dependencies do
    let reverseDepsKey := s!"{storage.keyPrefix}:decl:rdeps:{dep}"
    let _ ← sadd reverseDepsKey decl.name

  -- Set TTL if configured
  if storage.ttlSeconds > 0 then
    let _ ← expire k storage.ttlSeconds
    let _ ← expire depsKey storage.ttlSeconds

/-- Load a declaration by name -/
def loadDecl (storage : DeclStorage) (name : String) : RedisM (Option SimpleDeclInfo) := do
  let k := declKey storage.keyPrefix name
  let keyExists ← existsKey k
  if !keyExists then return none

  let all ← hgetall k
  -- Parse pairs from the flat list
  let fields := parsePairs all

  let getField (field : String) : Option String :=
    fields.find? (·.1 == field) |>.map (·.2)

  let name := getField "name" |>.getD ""
  let kind : DeclKind := match getField "kind" with
    | some s => match Lean.Json.parse s with
      | .ok json => match Lean.fromJson? (α := DeclKind) json with
        | .ok k => k
        | .error _ => DeclKind.definition
      | .error _ => DeclKind.definition
    | none => DeclKind.definition
  let levelParams : List String := match getField "levelParams" with
    | some s => match Lean.Json.parse s with
      | .ok json => match Lean.fromJson? (α := List String) json with
        | .ok lp => lp
        | .error _ => []
      | .error _ => []
    | none => []
  let declType := match getField "declType" with
    | some s => SimpleExpr.other s
    | none => SimpleExpr.other ""
  let value := getField "value" |>.map SimpleExpr.other
  let isUnsafe := getField "isUnsafe" == some "true"
  let moduleName := getField "moduleName" |>.getD ""

  -- Load dependencies
  let depsKey := declDepsKey storage.keyPrefix name
  let deps ← smembers depsKey
  let dependencies := deps.filterMap String.fromUTF8?

  return some { name, kind, levelParams, declType, value, isUnsafe, moduleName, dependencies }
where
  parsePairs (bs : List ByteArray) : List (String × String) :=
    match bs with
    | k :: v :: rest =>
      match String.fromUTF8? k, String.fromUTF8? v with
      | some ks, some vs => (ks, vs) :: parsePairs rest
      | _, _ => parsePairs rest
    | _ => []

/-- Get declarations that this declaration depends on -/
def getDependencies (storage : DeclStorage) (name : String) : RedisM (List String) := do
  let depsKey := declDepsKey storage.keyPrefix name
  let deps ← smembers depsKey
  return deps.filterMap String.fromUTF8?

/-- Get declarations that depend on this declaration -/
def getDependents (storage : DeclStorage) (name : String) : RedisM (List String) := do
  let rdepsKey := s!"{storage.keyPrefix}:decl:rdeps:{name}"
  let deps ← smembers rdepsKey
  return deps.filterMap String.fromUTF8?

/-- Delete a declaration -/
def deleteDecl (storage : DeclStorage) (name : String) : RedisM Unit := do
  let k := declKey storage.keyPrefix name
  let depsKey := declDepsKey storage.keyPrefix name
  let rdepsKey := s!"{storage.keyPrefix}:decl:rdeps:{name}"

  -- Remove from dependents' reverse deps
  let deps ← getDependencies storage name
  for dep in deps do
    let depRdepsKey := s!"{storage.keyPrefix}:decl:rdeps:{dep}"
    let _ ← srem depRdepsKey [name]

  let _ ← del [k, depsKey, rdepsKey]

/-- Create an environment snapshot -/
def createSnapshot (storage : DeclStorage) (id : String) (declarations : List String)
    (imports : List String) : RedisM EnvSnapshot := do
  let timestamp ← nowSeconds
  -- Compute content hash from declaration names
  let contentHash := declarations.foldl (fun h n => h ^^^ n.hash) (UInt64.ofNat 0)

  let snapshot : EnvSnapshot := { id, timestamp, declarations, imports, contentHash }
  let k := envSnapshotKey storage.keyPrefix id
  set k (Codec.enc snapshot)

  return snapshot

/-- Load an environment snapshot -/
def loadSnapshot (storage : DeclStorage) (id : String) : RedisM (Option EnvSnapshot) := do
  let k := envSnapshotKey storage.keyPrefix id
  let keyExists ← existsKey k
  if !keyExists then return none
  let bs ← get k
  match Codec.dec bs with
  | .ok s => return some s
  | .error _ => return none

/-- List all snapshots -/
def listSnapshots (storage : DeclStorage) : RedisM (List String) := do
  let pattern := s!"{storage.keyPrefix}:env:snapshot:*"
  let allKeys ← keys (α := String) (String.toUTF8 pattern)
  return allKeys.filterMap fun bs =>
    String.fromUTF8? bs |>.bind fun s =>
    -- Extract ID from key
    let kPrefix := s!"{storage.keyPrefix}:env:snapshot:"
    if s.startsWith kPrefix then some (dropPrefix s kPrefix.length)
    else none

/-- Delete a snapshot -/
def deleteSnapshot (storage : DeclStorage) (id : String) : RedisM Unit := do
  let k := envSnapshotKey storage.keyPrefix id
  let _ ← del [k]

/-- Check if a declaration exists -/
def declExists (storage : DeclStorage) (name : String) : RedisM Bool := do
  let k := declKey storage.keyPrefix name
  existsKey k

/-- Get all declaration names for a module -/
def getDeclsForModule (storage : DeclStorage) (moduleName : String) : RedisM (List String) := do
  let pattern := s!"{storage.keyPrefix}:decl:*"
  let allKeys ← keys (α := String) (String.toUTF8 pattern)
  let keyStrs := allKeys.filterMap String.fromUTF8?
  let mut result : List String := []
  for k in keyStrs do
    if containsSubstr k ":deps:" || containsSubstr k ":rdeps:" then continue
    let keyExists ← existsKey k
    if keyExists then
      let moduleField ← hget k "moduleName"
      match String.fromUTF8? moduleField with
      | some m => if m == moduleName then
        let nameField ← hget k "name"
        match String.fromUTF8? nameField with
        | some n => result := n :: result
        | none => pure ()
      | none => pure ()
  return result

end DeclStorage

end Redis.Mathlib
