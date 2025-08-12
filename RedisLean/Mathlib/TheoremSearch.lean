import RedisLean.Mathlib.Core

namespace Redis.Mathlib

/-!
# Type-Indexed Theorem Search for Lean/Mathlib

Enables searching for theorems by their conclusion type, hypotheses,
or name patterns. Uses Redis sorted sets for efficient retrieval.
-/

open Redis

/-- Information about an indexed theorem -/
structure TheoremInfo where
  /-- Theorem name -/
  name : String
  /-- Module containing the theorem -/
  moduleName : String
  /-- Type pattern of the conclusion -/
  conclusion : TypePattern
  /-- Type patterns of hypotheses -/
  hypotheses : List TypePattern
  /-- Optional documentation string -/
  docstring : Option String
  /-- Tags for categorization -/
  tags : List String
  deriving Repr, BEq

instance : Lean.ToJson TheoremInfo where
  toJson t := Lean.Json.mkObj [
    ("name", Lean.toJson t.name),
    ("moduleName", Lean.toJson t.moduleName),
    ("conclusion", Lean.toJson t.conclusion.toEncodedString),
    ("hypotheses", Lean.toJson (t.hypotheses.map (·.toEncodedString))),
    ("docstring", match t.docstring with
      | some d => Lean.toJson d
      | none => Lean.Json.null),
    ("tags", Lean.toJson t.tags)
  ]

instance : Lean.FromJson TheoremInfo where
  fromJson? j := do
    let name ← j.getObjValAs? String "name"
    let moduleName ← j.getObjValAs? String "moduleName"
    let conclStr ← j.getObjValAs? String "conclusion"
    let hypStrs ← j.getObjValAs? (List String) "hypotheses"
    let docstring := match j.getObjVal? "docstring" with
      | .ok (.str s) => some s
      | _ => none
    let tags ← j.getObjValAs? (List String) "tags"
    return {
      name, moduleName
      conclusion := .const conclStr  -- Simplified
      hypotheses := hypStrs.map TypePattern.const
      docstring, tags
    }

instance : Codec TheoremInfo := jsonCodec

/-- Search result with relevance score -/
structure SearchResult where
  /-- Theorem information -/
  theoremInfo : TheoremInfo
  /-- Relevance score (higher is better) -/
  score : Float
  deriving Repr

/-- Configuration for theorem search -/
structure TheoremSearch where
  /-- Key prefix -/
  keyPrefix : String := "mathlib"
  /-- Maximum results per query -/
  maxResults : Nat := 100
  deriving Repr

namespace TheoremSearch

/-- Create a new theorem search instance -/
def create (kPrefix : String := "mathlib") : TheoremSearch :=
  { keyPrefix := kPrefix }

/-- Index a theorem for searching -/
def indexTheorem (search : TheoremSearch) (thm : TheoremInfo) : RedisM Unit := do
  -- Store theorem metadata
  let nameKey := theoremNameKey search.keyPrefix thm.name
  set nameKey (Codec.enc thm)

  -- Index by conclusion type hash
  let conclHash := thm.conclusion.hash
  let conclKey := theoremConclusionKey search.keyPrefix conclHash
  -- Score is based on name length (shorter names often more fundamental)
  let score := 1000.0 - Float.ofNat thm.name.length
  let _ ← zadd conclKey score thm.name

  -- Index by each hypothesis type hash
  for hyp in thm.hypotheses do
    let hypHash := hyp.hash
    let hypKey := theoremHypothesisKey search.keyPrefix hypHash
    let _ ← zadd hypKey score thm.name

  -- Index by tags
  for tag in thm.tags do
    let tagKey := s!"{search.keyPrefix}:thm:tag:{tag}"
    let _ ← sadd tagKey thm.name

  -- Index in module's theorem list
  let moduleKey := s!"{search.keyPrefix}:thm:module:{thm.moduleName}"
  let _ ← sadd moduleKey thm.name

  -- Add to global theorem set
  let _ ← sadd s!"{search.keyPrefix}:thm:all" thm.name

/-- Search theorems by conclusion type -/
def searchByConclusion (search : TheoremSearch) (pattern : TypePattern) (limit : Nat := 20) : RedisM (List SearchResult) := do
  let patternHash := pattern.hash
  let conclKey := theoremConclusionKey search.keyPrefix patternHash

  -- Get theorem names sorted by score (descending)
  let results ← zrevrange conclKey 0 (Int.ofNat limit - 1)

  let mut searchResults : List SearchResult := []
  for nameBs in results do
    match String.fromUTF8? nameBs with
    | some name =>
      let nameKey := theoremNameKey search.keyPrefix name
      let keyExists ← existsKey nameKey
      if keyExists then
        let bs ← get nameKey
        match Codec.dec (α := TheoremInfo) bs with
        | .ok thm =>
          -- Get score from sorted set
          let scoreOpt ← zscore conclKey name
          let score := scoreOpt.getD 0.0
          -- Refine score based on pattern match quality
          let matchScore := if pattern.matchesPattern thm.conclusion then score else score * 0.5
          searchResults := { theoremInfo := thm, score := matchScore } :: searchResults
        | .error _ => pure ()
    | none => pure ()

  return searchResults.reverse

/-- Search theorems by hypothesis type -/
def searchByHypothesis (search : TheoremSearch) (pattern : TypePattern) (limit : Nat := 20) : RedisM (List SearchResult) := do
  let patternHash := pattern.hash
  let hypKey := theoremHypothesisKey search.keyPrefix patternHash

  let results ← zrevrange hypKey 0 (Int.ofNat limit - 1)

  let mut searchResults : List SearchResult := []
  for nameBs in results do
    match String.fromUTF8? nameBs with
    | some name =>
      let nameKey := theoremNameKey search.keyPrefix name
      let keyExists ← existsKey nameKey
      if keyExists then
        let bs ← get nameKey
        match Codec.dec (α := TheoremInfo) bs with
        | .ok thm =>
          let scoreOpt ← zscore hypKey name
          let score := scoreOpt.getD 100.0
          searchResults := { theoremInfo := thm, score } :: searchResults
        | .error _ => pure ()
    | none => pure ()

  return searchResults.reverse

/-- Search theorems by name pattern (prefix match) -/
def searchByName (search : TheoremSearch) (pattern : String) (limit : Nat := 20) : RedisM (List SearchResult) := do
  -- Get all theorem names
  let allNames ← smembers s!"{search.keyPrefix}:thm:all"
  let nameStrs := allNames.filterMap String.fromUTF8?

  -- Filter by pattern
  let matching := nameStrs.filter fun name =>
    containsSubstr name pattern || containsSubstr name.toLower pattern.toLower

  -- Load theorem info for matching names
  let mut searchResults : List SearchResult := []
  for name in matching.take limit do
    let nameKey := theoremNameKey search.keyPrefix name
    let keyExists ← existsKey nameKey
    if keyExists then
      let bs ← get nameKey
      match Codec.dec (α := TheoremInfo) bs with
      | .ok thm =>
        -- Score based on name length and match
        let score := 1000.0 - Float.ofNat name.length
        searchResults := { theoremInfo := thm, score } :: searchResults
      | .error _ => pure ()

  return searchResults

/-- Search theorems by tag -/
def searchByTag (search : TheoremSearch) (tag : String) (limit : Nat := 20) : RedisM (List SearchResult) := do
  let tagKey := s!"{search.keyPrefix}:thm:tag:{tag}"
  let names ← smembers tagKey
  let nameStrs := names.filterMap String.fromUTF8?

  let mut searchResults : List SearchResult := []
  for name in nameStrs.take limit do
    let nameKey := theoremNameKey search.keyPrefix name
    let keyExists ← existsKey nameKey
    if keyExists then
      let bs ← get nameKey
      match Codec.dec (α := TheoremInfo) bs with
      | .ok thm =>
        searchResults := { theoremInfo := thm, score := 100.0 } :: searchResults
      | .error _ => pure ()

  return searchResults

/-- Search theorems in a specific module -/
def searchByModule (search : TheoremSearch) (moduleName : String) (limit : Nat := 100) : RedisM (List SearchResult) := do
  let moduleKey := s!"{search.keyPrefix}:thm:module:{moduleName}"
  let names ← smembers moduleKey
  let nameStrs := names.filterMap String.fromUTF8?

  let mut searchResults : List SearchResult := []
  for name in nameStrs.take limit do
    let nameKey := theoremNameKey search.keyPrefix name
    let keyExists ← existsKey nameKey
    if keyExists then
      let bs ← get nameKey
      match Codec.dec (α := TheoremInfo) bs with
      | .ok thm =>
        searchResults := { theoremInfo := thm, score := 100.0 } :: searchResults
      | .error _ => pure ()

  return searchResults

/-- Remove a theorem from the index -/
def removeTheorem (search : TheoremSearch) (name : String) : RedisM Unit := do
  -- Load theorem info first
  let nameKey := theoremNameKey search.keyPrefix name
  let keyExists ← existsKey nameKey
  if !keyExists then return

  let bs ← get nameKey
  match Codec.dec (α := TheoremInfo) bs with
  | .ok thm =>
    -- Remove from conclusion index
    let conclHash := thm.conclusion.hash
    let conclKey := theoremConclusionKey search.keyPrefix conclHash
    let _ ← zrem conclKey [name]

    -- Remove from hypothesis indices
    for hyp in thm.hypotheses do
      let hypHash := hyp.hash
      let hypKey := theoremHypothesisKey search.keyPrefix hypHash
      let _ ← zrem hypKey [name]

    -- Remove from tags
    for tag in thm.tags do
      let tagKey := s!"{search.keyPrefix}:thm:tag:{tag}"
      let _ ← srem tagKey [name]

    -- Remove from module index
    let moduleKey := s!"{search.keyPrefix}:thm:module:{thm.moduleName}"
    let _ ← srem moduleKey [name]

    -- Remove from global set
    let _ ← srem s!"{search.keyPrefix}:thm:all" [name]

    -- Delete the theorem data
    let _ ← del [nameKey]

  | .error _ => pure ()

/-- Get the total number of indexed theorems -/
def count (search : TheoremSearch) : RedisM Nat :=
  scard s!"{search.keyPrefix}:thm:all"

/-- Clear all indexed theorems -/
def clear (search : TheoremSearch) : RedisM Nat := do
  let pattern := s!"{search.keyPrefix}:thm:*"
  let allKeys ← keys (α := String) (String.toUTF8 pattern)
  if allKeys.isEmpty then return 0
  let keyStrs := allKeys.filterMap String.fromUTF8?
  del keyStrs

end TheoremSearch

end Redis.Mathlib
