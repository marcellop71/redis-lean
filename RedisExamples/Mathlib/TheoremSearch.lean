import RedisLean.Mathlib
import RedisLean.Log
import RedisLean.Monad

namespace MathlibTheoremSearchExample

open Redis Redis.Mathlib

/-!
# Theorem Search Example

Demonstrates type-indexed theorem search capabilities.
This is useful for:
- Finding theorems by their conclusion type
- Searching theorems by hypothesis requirements
- Building theorem databases for proof assistants
- Enabling "apply" suggestions in IDE tooling
-/

/-- Sample theorems to index -/
def sampleTheorems : List TheoremInfo := [
  {
    name := "Nat.add_comm"
    moduleName := "Mathlib.Data.Nat.Basic"
    conclusion := .app (.app (.const "Eq") (.const "Nat")) (.const "Nat.add")
    hypotheses := []
    docstring := some "Addition on natural numbers is commutative"
    tags := ["algebra", "nat", "commutative"]
  },
  {
    name := "Nat.add_assoc"
    moduleName := "Mathlib.Data.Nat.Basic"
    conclusion := .app (.app (.const "Eq") (.const "Nat")) (.const "Nat.add")
    hypotheses := []
    docstring := some "Addition on natural numbers is associative"
    tags := ["algebra", "nat", "associative"]
  },
  {
    name := "Nat.mul_comm"
    moduleName := "Mathlib.Data.Nat.Basic"
    conclusion := .app (.app (.const "Eq") (.const "Nat")) (.const "Nat.mul")
    hypotheses := []
    docstring := some "Multiplication on natural numbers is commutative"
    tags := ["algebra", "nat", "commutative"]
  },
  {
    name := "List.length_append"
    moduleName := "Mathlib.Data.List.Basic"
    conclusion := .app (.app (.const "Eq") (.const "Nat")) (.const "List.length")
    hypotheses := [.const "List"]
    docstring := some "Length of appended lists equals sum of lengths"
    tags := ["list", "length"]
  },
  {
    name := "List.reverse_reverse"
    moduleName := "Mathlib.Data.List.Basic"
    conclusion := .app (.app (.const "Eq") (.const "List")) (.const "List.reverse")
    hypotheses := [.const "List"]
    docstring := some "Reversing a list twice gives the original list"
    tags := ["list", "reverse", "involution"]
  },
  {
    name := "Int.add_neg_self"
    moduleName := "Mathlib.Data.Int.Basic"
    conclusion := .app (.app (.const "Eq") (.const "Int")) (.const "zero")
    hypotheses := [.const "Int"]
    docstring := some "Adding a number to its negation gives zero"
    tags := ["algebra", "int", "negation"]
  }
]

/-- Example: Index theorems -/
def exIndexTheorems : RedisM Unit := do
  Log.info "Example: Indexing theorems for search"

  let search := TheoremSearch.create "example"

  -- Clear any previous data
  let _ ← search.clear

  -- Index all sample theorems
  for thm in sampleTheorems do
    search.indexTheorem thm
    Log.info s!"  Indexed: {thm.name}"

  let count ← search.count
  Log.info s!"Total theorems indexed: {count}"

/-- Example: Search by name pattern -/
def exSearchByName : RedisM Unit := do
  Log.info "Example: Search theorems by name"

  let search := TheoremSearch.create "example"

  -- Search for theorems with "add" in the name
  Log.info "Searching for theorems containing 'add'..."
  let addResults ← search.searchByName "add" 10
  for r in addResults do
    Log.info s!"  Found: {r.theoremInfo.name} (score: {r.score})"

  -- Search for theorems with "comm" in the name
  Log.info "Searching for theorems containing 'comm'..."
  let commResults ← search.searchByName "comm" 10
  for r in commResults do
    Log.info s!"  Found: {r.theoremInfo.name}"

/-- Example: Search by tag -/
def exSearchByTag : RedisM Unit := do
  Log.info "Example: Search theorems by tag"

  let search := TheoremSearch.create "example"

  -- Search for commutative theorems
  Log.info "Searching for 'commutative' tagged theorems..."
  let commResults ← search.searchByTag "commutative" 10
  for r in commResults do
    Log.info s!"  Found: {r.theoremInfo.name}"
    if let some doc := r.theoremInfo.docstring then
      Log.info s!"    Doc: {doc}"

  -- Search for list-related theorems
  Log.info "Searching for 'list' tagged theorems..."
  let listResults ← search.searchByTag "list" 10
  for r in listResults do
    Log.info s!"  Found: {r.theoremInfo.name}"

/-- Example: Search by module -/
def exSearchByModule : RedisM Unit := do
  Log.info "Example: Search theorems by module"

  let search := TheoremSearch.create "example"

  -- Search in Nat module
  Log.info "Theorems in Mathlib.Data.Nat.Basic:"
  let natResults ← search.searchByModule "Mathlib.Data.Nat.Basic" 20
  for r in natResults do
    Log.info s!"  - {r.theoremInfo.name}"

  -- Search in List module
  Log.info "Theorems in Mathlib.Data.List.Basic:"
  let listResults ← search.searchByModule "Mathlib.Data.List.Basic" 20
  for r in listResults do
    Log.info s!"  - {r.theoremInfo.name}"

/-- Example: Search by conclusion type -/
def exSearchByConclusion : RedisM Unit := do
  Log.info "Example: Search theorems by conclusion type"

  let search := TheoremSearch.create "example"

  -- Search for theorems concluding with Nat equality
  let natEqPattern := TypePattern.app (.app (.const "Eq") (.const "Nat")) .any
  Log.info "Searching for theorems with Nat equality conclusions..."
  let results ← search.searchByConclusion natEqPattern 10
  Log.info s!"Found {results.length} theorems"
  for r in results do
    Log.info s!"  - {r.theoremInfo.name} (score: {r.score})"

/-- Example: Remove and update theorems -/
def exRemoveTheorem : RedisM Unit := do
  Log.info "Example: Remove theorem from index"

  let search := TheoremSearch.create "example"

  let countBefore ← search.count
  Log.info s!"Theorems before removal: {countBefore}"

  -- Remove a theorem
  search.removeTheorem "Nat.add_comm"
  Log.info "Removed: Nat.add_comm"

  let countAfter ← search.count
  Log.info s!"Theorems after removal: {countAfter}"

  -- Verify it's gone
  let results ← search.searchByName "Nat.add_comm" 5
  if results.isEmpty then
    Log.info "Verified: Nat.add_comm no longer in search results"
  else
    Log.info "Warning: Nat.add_comm still found"

/-- Run all theorem search examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Theorem Search Examples ==="
  exIndexTheorems
  exSearchByName
  exSearchByTag
  exSearchByModule
  exSearchByConclusion
  exRemoveTheorem
  Log.info "=== Theorem Search Examples Complete ==="

end MathlibTheoremSearchExample
