import RedisLean.Mathlib
import RedisLean.Log
import RedisLean.Monad

namespace MathlibDeclarationExample

open Redis Redis.Mathlib

/-!
# Declaration Storage Example

Demonstrates storing and querying Lean declarations with dependency tracking.
This is useful for:
- Caching compiled declarations for incremental builds
- Tracking declaration dependencies for refactoring
- Building "go to definition" features
- Understanding codebase structure
-/

/-- Sample declarations representing a small Nat module -/
def sampleDeclarations : List SimpleDeclInfo := [
  {
    name := "Nat"
    kind := .inductiveDecl
    levelParams := []
    declType := .const "Type" []
    value := none
    isUnsafe := false
    moduleName := "Init.Prelude"
    dependencies := []
  },
  {
    name := "Nat.zero"
    kind := .constructorDecl
    levelParams := []
    declType := .const "Nat" []
    value := none
    isUnsafe := false
    moduleName := "Init.Prelude"
    dependencies := ["Nat"]
  },
  {
    name := "Nat.succ"
    kind := .constructorDecl
    levelParams := []
    declType := .forallE "_" (.const "Nat" []) (.const "Nat" [])
    value := none
    isUnsafe := false
    moduleName := "Init.Prelude"
    dependencies := ["Nat"]
  },
  {
    name := "Nat.add"
    kind := .definition
    levelParams := []
    declType := .forallE "_" (.const "Nat" []) (.forallE "_" (.const "Nat" []) (.const "Nat" []))
    value := some (.other "fun n m => Nat.rec m (fun _ ih => Nat.succ ih) n")
    isUnsafe := false
    moduleName := "Init.Prelude"
    dependencies := ["Nat", "Nat.succ", "Nat.rec"]
  },
  {
    name := "Nat.add_zero"
    kind := .theoremDecl
    levelParams := []
    declType := .other "∀ n : Nat, n + 0 = n"
    value := some (.other "fun n => rfl")
    isUnsafe := false
    moduleName := "Init.Data.Nat.Basic"
    dependencies := ["Nat", "Nat.add", "Eq", "Eq.refl"]
  },
  {
    name := "Nat.add_succ"
    kind := .theoremDecl
    levelParams := []
    declType := .other "∀ n m : Nat, n + succ m = succ (n + m)"
    value := some (.other "fun n m => rfl")
    isUnsafe := false
    moduleName := "Init.Data.Nat.Basic"
    dependencies := ["Nat", "Nat.add", "Nat.succ", "Eq"]
  },
  {
    name := "Nat.add_comm"
    kind := .theoremDecl
    levelParams := []
    declType := .other "∀ n m : Nat, n + m = m + n"
    value := some (.other "proof by induction")
    isUnsafe := false
    moduleName := "Init.Data.Nat.Basic"
    dependencies := ["Nat", "Nat.add", "Nat.add_zero", "Nat.add_succ", "Eq"]
  }
]

/-- Example: Store declarations -/
def exStoreDeclarations : RedisM Unit := do
  Log.info "Example: Storing declarations"

  let storage := DeclStorage.create "example"

  for decl in sampleDeclarations do
    storage.storeDecl decl
    Log.info s!"  Stored: {decl.name} ({repr decl.kind})"

  Log.info s!"Total declarations stored: {sampleDeclarations.length}"

/-- Example: Load and inspect declarations -/
def exLoadDeclarations : RedisM Unit := do
  Log.info "Example: Loading declarations"

  let storage := DeclStorage.create "example"

  -- Load a specific declaration
  let declOpt ← storage.loadDecl "Nat.add"
  match declOpt with
  | some decl =>
    Log.info s!"Loaded: {decl.name}"
    Log.info s!"  Kind: {repr decl.kind}"
    Log.info s!"  Type: {decl.declType.toEncodedString}"
    Log.info s!"  Module: {decl.moduleName}"
    Log.info s!"  Dependencies: {decl.dependencies}"
  | none =>
    Log.info "Declaration not found"

/-- Example: Query dependencies -/
def exQueryDependencies : RedisM Unit := do
  Log.info "Example: Querying dependencies"

  let storage := DeclStorage.create "example"

  -- Get what Nat.add_comm depends on
  let deps ← storage.getDependencies "Nat.add_comm"
  Log.info s!"Nat.add_comm depends on:"
  for dep in deps do
    Log.info s!"  - {dep}"

  -- Get what depends on Nat.add (reverse dependencies)
  let dependents ← storage.getDependents "Nat.add"
  Log.info s!"Declarations that use Nat.add:"
  for dep in dependents do
    Log.info s!"  - {dep}"

/-- Example: Check declaration existence -/
def exCheckExists : RedisM Unit := do
  Log.info "Example: Checking declaration existence"

  let storage := DeclStorage.create "example"

  let names := ["Nat.add", "Nat.mul", "Nat.add_comm", "NonExistent.Decl"]
  for name in names do
    let exists_ ← storage.declExists name
    if exists_ then
      Log.info s!"  {name}: exists"
    else
      Log.info s!"  {name}: not found"

/-- Example: Get declarations by module -/
def exGetByModule : RedisM Unit := do
  Log.info "Example: Getting declarations by module"

  let storage := DeclStorage.create "example"

  -- Get all declarations from Init.Prelude
  let preludeDecls ← storage.getDeclsForModule "Init.Prelude"
  Log.info s!"Declarations in Init.Prelude ({preludeDecls.length}):"
  for name in preludeDecls do
    Log.info s!"  - {name}"

  -- Get all declarations from Init.Data.Nat.Basic
  let natDecls ← storage.getDeclsForModule "Init.Data.Nat.Basic"
  Log.info s!"Declarations in Init.Data.Nat.Basic ({natDecls.length}):"
  for name in natDecls do
    Log.info s!"  - {name}"

/-- Example: Environment snapshots -/
def exEnvironmentSnapshots : RedisM Unit := do
  Log.info "Example: Environment snapshots"

  let storage := DeclStorage.create "example"

  -- Create a snapshot of current environment
  let declNames := sampleDeclarations.map (·.name)
  let imports := ["Init", "Lean"]

  let snapshot ← storage.createSnapshot "v1.0.0" declNames imports
  Log.info s!"Created snapshot: {snapshot.id}"
  Log.info s!"  Declarations: {snapshot.declarations.length}"
  Log.info s!"  Imports: {snapshot.imports}"
  Log.info s!"  Content hash: {snapshot.contentHash}"

  -- Load the snapshot back
  let loadedOpt ← storage.loadSnapshot "v1.0.0"
  match loadedOpt with
  | some loaded =>
    Log.info s!"Loaded snapshot: {loaded.id}"
    Log.info s!"  Matches original: {loaded.contentHash == snapshot.contentHash}"
  | none =>
    Log.info "Failed to load snapshot"

  -- List all snapshots
  let allSnapshots ← storage.listSnapshots
  Log.info s!"All snapshots: {allSnapshots}"

/-- Example: Delete declaration -/
def exDeleteDeclaration : RedisM Unit := do
  Log.info "Example: Deleting declarations"

  let storage := DeclStorage.create "example"

  -- Check before deletion
  let beforeExists ← storage.declExists "Nat.add_comm"
  Log.info s!"Before deletion - Nat.add_comm exists: {beforeExists}"

  -- Delete
  storage.deleteDecl "Nat.add_comm"
  Log.info "Deleted: Nat.add_comm"

  -- Check after deletion
  let afterExists ← storage.declExists "Nat.add_comm"
  Log.info s!"After deletion - Nat.add_comm exists: {afterExists}"

/-- Run all declaration examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Declaration Storage Examples ==="
  exStoreDeclarations
  exLoadDeclarations
  exQueryDependencies
  exCheckExists
  exGetByModule
  exEnvironmentSnapshots
  exDeleteDeclaration
  Log.info "=== Declaration Storage Examples Complete ==="

end MathlibDeclarationExample
