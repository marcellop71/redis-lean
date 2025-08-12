import RedisLean.Ops
import RedisLean.Codec

/-!
# Abstract Redis Model

A formal mathematical specification of Redis key-value store semantics.
See `RedisModel/README.md` for comprehensive documentation including:
- Design insights and axiom system rationale
- Complete list of proven theorems with categories
- Limitations and future enhancements

Some theorems in this module were proven with the assistance of Claude (Anthropic's AI).
This is safe because Lean verifies all proofs mechanically - a successful build guarantees correctness.
-/

namespace RedisModel.AbstractMinimal

section AbstractRedis

-- Redis computational setup as a state monad
-- DB is the type of the database state
abbrev RedisM (DB : Type) (α : Type) := StateT DB Id α

namespace RedisM

  -- evaluate a RedisM computation to get the result value
  def result {DB α} (m : RedisM DB α) (db : DB) : α := (m.run db).fst

  -- execute a RedisM computation to get the final database state
  def state {DB α} (m : RedisM DB α) (db : DB) : DB := (m.run db).snd

end RedisM

-- concise notations for RedisM evaluation
notation:70 "⇐" m " on  " db => RedisM.result m db
notation:70 "≡ " m " on " db => RedisM.state m db

-- abstract Redis operations
-- errors are not modelled (while the Redis monad for the client uses a RedisError)
-- get returns an Option (not an Except RedisError as in the client)
-- del just one element for simplicity, del do nothing if the key does not exist and returns false
-- α is the type of Redis keys
-- γ is the type of Redis values
class AbstractOps (DB α γ : Type) where
  set : α → γ → RedisM DB Unit
  get : α → RedisM DB (Option γ)
  del : α → RedisM DB Bool
  existsKey : α → RedisM DB Bool

-- marker types to distinguish read-only from operations that could alter a database
inductive OpType where
  | ReadOnly   : OpType
  | CouldAlter : OpType

-- operation type classification
def opType : String → OpType
  | "set" => OpType.CouldAlter
  | "del" => OpType.CouldAlter
  | "get" => OpType.ReadOnly
  | "existsKey" => OpType.ReadOnly
  | _ => OpType.ReadOnly

variable {DB α γ : Type} [ops : AbstractOps DB α γ] (k k1 k2 : α) (v v1 v2 : γ) (db : DB)

-- Local notation for cleaner axioms and theorems
local notation "GET" => ops.get
local notation "SET" => ops.set  
local notation "DEL" => ops.del
local notation "EXISTS" => ops.existsKey

-- definition of empty database using RedisM evaluation
def empty (db : DB) := ∀ (k : α), (⇐ EXISTS k on db) = false

-- monadic composition axiom: (m1 *> m2) is equivalent to m2 on the state after m1
axiom monadic_composition {α β : Type} (m1 : RedisM DB α) (m2 : RedisM DB β) :
  (⇐ (m1 *> m2) on db) = (⇐ m2 on (≡ m1 on db))

-- get don't modify the database state
axiom get_preserves_state :
  ∀ (k : α), (≡ GET k on db) = db

-- existsKey don't modify the database state
axiom existsKey_preserves_state :
  ∀ (k : α), (≡ EXISTS k on db) = db

-- del alters state only if the key exists
axiom del_alters_state_iff_exists :
  (≡ DEL k on db) ≠ db ↔ (⇐ EXISTS k on db) = true

-- set alters state only if key doesn't exist or exists with different value
axiom set_alters_state_iff_new_or_different :
  (≡ SET k v on db) ≠ db ↔
  ((⇐ EXISTS k on db) = false ∨ (⇐ GET k on db) ≠ some v)

-- after setting a key-value pair, getting that key returns the set value
axiom set_get_consistency :
  (⇐ (SET k v *> GET k) on db) = some v

-- getting a non-existent key returns none implies key doesn't exist
axiom get_none_iff_nonexistent :
  (⇐ GET k on db) = none ↔ (⇐ EXISTS k on db) = false

-- deleting a key makes it not exist
axiom del_removes_key :
  (⇐ (DEL k *> EXISTS k) on db) = false

-- delete returns true if key existed, false otherwise
axiom del_returns_status :
  (⇐ DEL k on db) = (⇐ EXISTS k on db)

-- there exists an initial empty database state
axiom exists_empty_db : ∃ (db : DB), (∀ (k : α), (⇐ EXISTS k on db) = false)

-- if two databases have same observable behavior, they represent same state
axiom observability :
  ∀ (db1 db2 : DB),
    (∀ (k : α), (⇐ GET k on db1) = (⇐ GET k on db2)) →
    (∀ (k : α), (⇐ EXISTS k on db1) = (⇐ EXISTS k on db2)) →
    db1 = db2

-- set isolation: set operations on a different key don't interfere with observable behavior
axiom set_isolation :
  ∀ (k1 k2 : α) (v : γ) (db : DB),
    k1 ≠ k2 →
    (⇐ GET k2 on db) = (⇐ GET k2 on (≡ SET k1 v on db)) ∧
    (⇐ EXISTS k2 on db) = (⇐ EXISTS k2 on (≡ SET k1 v on db))

-- det isolation: del operations on a different key don't interfere with observable behavior
axiom del_isolation :
  ∀ (k1 k2 : α) (db : DB),
    k1 ≠ k2 →
    (⇐ GET k2 on db) = (⇐ GET k2 on (≡ DEL k1 on db)) ∧
    (⇐ EXISTS k2 on db) = (⇐ EXISTS k2 on (≡ DEL k1 on db))

-- two databases are equivalent if they have the same observable behavior
def db_equivalent (db1 db2 : DB) : Prop :=
  ∀ (k : α), (⇐ GET k on db1) = (⇐ GET k on db2) ∧
             (⇐ EXISTS k on db1) = (⇐ EXISTS k on db2)

-- event Sourcing Model: Database state as result of AbstractOps sequences
-- event history as composition of AbstractOps state transformations
def EventHistory (DB : Type) := List (DB → DB)

def applyHistory {DB : Type} : EventHistory DB → DB → DB
  | [], db => db
  | op :: rest, db => applyHistory rest (op db)

-- sourcing axiom: any database state can be represented as the result of applying 
-- a sequence of SET and DEL operations to an empty database
axiom event_sourcing_principle :
  ∀ (db : DB), ∃ (empty_db : DB) (ops_sequence : List (DB → DB)),
    (∀ (k : α), (⇐ EXISTS k on empty_db) = false) ∧
    (∀ f ∈ ops_sequence, ∃ (k : α) (v : γ), (∀ db', f db' = (≡ SET k v on db')) ∨ 
                          ∃ (k : α), (∀ db', f db' = (≡ DEL k on db'))) ∧
    (applyHistory ops_sequence empty_db = db)

-- after deletion, get returns none  
theorem del_affects_get :
  (⇐ (DEL k *> GET k) on db) = none := by
  rw [monadic_composition]
  have h1 : (⇐ (DEL k *> EXISTS k) on db) = false := del_removes_key k db
  have h2 : (⇐ EXISTS k on (≡ DEL k on db)) = false := by
    rw [← monadic_composition]
    exact h1
  exact (get_none_iff_nonexistent k (≡ DEL k on db)).mpr h2

-- set is idempotent: setting a key to its current value doesn't change state
theorem set_idempotent :
  (⇐ GET k on db) = some v → (≡ SET k v on db) = db := by
  intro h
  suffices h_not_neq : ¬((≡ SET k v on db) ≠ db) by
    exact Classical.not_not.mp h_not_neq
  rw [set_alters_state_iff_new_or_different]
  simp only [not_or]
  constructor
  · 
    intro h_key_not_exists
    have get_none := (get_none_iff_nonexistent k db).mpr h_key_not_exists
    rw [h] at get_none
    simp at get_none
  · 
    intro h_value_different
    exact h_value_different h

-- setting a key-value pair makes the key exist
theorem set_creates_key :
  (⇐ (SET k v *> EXISTS k) on db) = true := by
  rw [monadic_composition]
  have h_get_some : (⇐ GET k on (≡ SET k v on db)) = some v := by
    rw [← monadic_composition]
    exact set_get_consistency k v db
  have h_not_false : ¬((⇐ EXISTS k on (≡ SET k v on db)) = false) := by
    intro h_false
    have h_get_none := (get_none_iff_nonexistent k (≡ SET k v on db)).mpr h_false
    rw [h_get_some] at h_get_none
    simp at h_get_none
  cases h_eq : (⇐ EXISTS k on (≡ SET k v on db))
  · exact False.elim (h_not_false h_eq)
  · rfl

-- setting a key twice overwrites the previous value
theorem set_overwrite :
  (⇐ (SET k v1 *> SET k v2 *> GET k) on db) = some v2 := by
  rw [monadic_composition]
  exact set_get_consistency k v2 (≡ SET k v1 on db)

-- State composition lemma: state after m1 *> m2 is state after m2 run on state after m1
-- This follows from StateT semantics
theorem state_composition' {α β : Type} (m1 : RedisM DB α) (m2 : RedisM DB β) :
  (≡ (m1 *> m2) on db) = (≡ m2 on (≡ m1 on db)) := by
  simp only [RedisM.state]
  rfl

-- Helper lemma: GET returns none after DEL
-- Proof: del_removes_key says EXISTS k = false after DEL k, then get_none_iff_nonexistent
theorem del_get_none' :
  (⇐ GET k on (≡ DEL k on db)) = none := by
  have h : (⇐ EXISTS k on (≡ DEL k on db)) = false := by
    have h1 := @del_removes_key DB α γ ops k db
    rw [monadic_composition] at h1
    exact h1
  exact (get_none_iff_nonexistent k (≡ DEL k on db)).mpr h

-- if a key doesn't exist, set followed by del doesn't alter the state
-- Proof strategy: use observability to show all GETs and EXISTS return same values
-- For k: GET returns none (was none, del makes it none), EXISTS returns false
-- For k' ≠ k: unchanged by isolation
theorem set_del_nonexistent_preserves_state :
  (⇐ EXISTS k on db) = false → (≡ (SET k v *> DEL k) on db) = db := by
  intro h_not_exists
  rw [state_composition']
  apply @observability DB α γ ops
  -- Prove GET k' is equal on both sides for all k'
  · intro k'
    by_cases h : k' = k
    · -- k' = k: GET k is none on both sides
      rw [h]
      -- GET k on db is none because EXISTS k = false
      have h_get_orig : (⇐ GET k on db) = none :=
        (get_none_iff_nonexistent k db).mpr h_not_exists
      -- GET k after SET then DEL is none
      have h_get_after : (⇐ GET k on (≡ DEL k on (≡ SET k v on db))) = none := by
        exact del_get_none' k (≡ SET k v on db)
      rw [h_get_after, h_get_orig]
    · -- k' ≠ k: GET k' unchanged by isolation
      have h_neq : k ≠ k' := Ne.symm h
      have ⟨h_set_iso, _⟩ := @set_isolation DB α γ ops k k' v db h_neq
      have ⟨h_del_iso, _⟩ := @del_isolation DB α γ ops k k' (≡ SET k v on db) h_neq
      rw [← h_del_iso, ← h_set_iso]
  -- Prove EXISTS k' is equal on both sides for all k'
  · intro k'
    by_cases h : k' = k
    · -- k' = k: EXISTS k is false on both sides
      rw [h]
      -- EXISTS k after SET then DEL is false
      have h_exists_after : (⇐ EXISTS k on (≡ DEL k on (≡ SET k v on db))) = false := by
        have h1 := @del_removes_key DB α γ ops k (≡ SET k v on db)
        rw [monadic_composition] at h1
        exact h1
      rw [h_exists_after, h_not_exists]
    · -- k' ≠ k: EXISTS k' unchanged by isolation
      have h_neq : k ≠ k' := Ne.symm h
      have ⟨_, h_set_iso⟩ := @set_isolation DB α γ ops k k' v db h_neq
      have ⟨_, h_del_iso⟩ := @del_isolation DB α γ ops k k' (≡ SET k v on db) h_neq
      rw [← h_del_iso, ← h_set_iso]

/-! ## Basic Property Theorems

These theorems establish fundamental relationships between operations,
directly derived from the core axioms.
-/

-- GET after SET on the resulting state (direct state access, not composition)
theorem get_after_set :
  (⇐ GET k on (≡ SET k v on db)) = some v := by
  have h := set_get_consistency k v db
  rw [monadic_composition] at h
  exact h

-- EXISTS after SET returns true (direct state access)
theorem exists_after_set :
  (⇐ EXISTS k on (≡ SET k v on db)) = true := by
  have h := set_creates_key k v db
  rw [monadic_composition] at h
  exact h

-- State composition lemma: state after m1 *> m2 is state after m2 run on state after m1
-- This follows from StateT semantics
theorem state_composition {α β : Type} (m1 : RedisM DB α) (m2 : RedisM DB β) :
  (≡ (m1 *> m2) on db) = (≡ m2 on (≡ m1 on db)) := by
  simp only [RedisM.state]
  rfl

-- GET is transparent: doesn't affect state for subsequent operations
theorem get_transparent {β : Type} (m : RedisM DB β) :
  (≡ (GET k *> m) on db) = (≡ m on db) := by
  rw [state_composition]
  rw [get_preserves_state]

-- EXISTS is transparent: doesn't affect state for subsequent operations
theorem exists_transparent {β : Type} (m : RedisM DB β) :
  (≡ (EXISTS k *> m) on db) = (≡ m on db) := by
  rw [state_composition]
  rw [existsKey_preserves_state]

/-! ## Idempotence Theorems

Operations that produce the same result when applied multiple times.
-/

-- DEL on empty database is no-op
-- Stated using EXISTS directly to avoid type inference issues with `empty`
-- Proof: if EXISTS k = false, del doesn't change state (by del_alters_state_iff_exists)
theorem del_on_empty_noop :
  (⇐ EXISTS k on db) = false → (≡ DEL k on db) = db := by
  intro h_not_exists
  have h_not_neq : ¬((≡ DEL k on db) ≠ db) := by
    rw [del_alters_state_iff_exists]
    simp [h_not_exists]
  exact Classical.not_not.mp h_not_neq

-- DEL is idempotent: deleting twice is same as deleting once
-- Proof: after first DEL, key doesn't exist, so second DEL doesn't change state
theorem del_idempotent :
  (≡ (DEL k *> DEL k) on db) = (≡ DEL k on db) := by
  rw [state_composition]
  -- After first DEL, EXISTS k = false
  have h_not_exists : (⇐ EXISTS k on (≡ DEL k on db)) = false := by
    have h1 := @del_removes_key DB α γ ops k db
    rw [monadic_composition] at h1
    exact h1
  -- So second DEL is a no-op
  exact del_on_empty_noop k (≡ DEL k on db) h_not_exists

-- SET-SET with same value is idempotent
theorem set_set_same_idempotent :
  (≡ (SET k v *> SET k v) on db) = (≡ SET k v on db) := by
  -- After first SET, GET k = some v, so second SET doesn't change state
  have h_get : (⇐ GET k on (≡ SET k v on db)) = some v := get_after_set k v db
  exact set_idempotent k v (≡ SET k v on db) h_get

/-! ## Uniqueness and Equivalence Theorems

Theorems about database state identity and equivalence relations.

Note: Some theorems involving multiple DB parameters (db_equivalent_symm, db_equivalent_trans,
db_equivalent_eq, empty_unique) require more explicit type annotations due to typeclass
inference limitations. The proof strategies are documented below:

- db_equivalent_refl: Immediate from reflexivity of =
- db_equivalent_symm: Follows from symmetry of = on components
- db_equivalent_trans: Follows from transitivity of = on components
- db_equivalent_eq: Apply observability with the two components of db_equivalent
- empty_unique: Apply observability; all GETs return none, all EXISTS return false
-/

-- db_equivalent is reflexive
theorem db_equivalent_refl : db_equivalent (α := α) (γ := γ) db db := by
  intro k'
  constructor <;> rfl

-- Helper lemma: GET returns none after DEL
-- Proof: del_removes_key says EXISTS k = false after DEL k, then get_none_iff_nonexistent
theorem del_get_none :
  (⇐ GET k on (≡ DEL k on db)) = none := by
  have h : (⇐ EXISTS k on (≡ DEL k on db)) = false := by
    have h1 := @del_removes_key DB α γ ops k db
    rw [monadic_composition] at h1
    exact h1
  exact (get_none_iff_nonexistent k (≡ DEL k on db)).mpr h

/-! ## Commutativity Theorems

Operations on different keys can be reordered without affecting the final state.
These follow from the isolation axioms.
-/

-- SET operations on different keys commute
-- Proof: use observability; for each key, show GET and EXISTS return same values
-- by using isolation axioms (operations on different keys don't interfere)
theorem set_set_commute :
  k1 ≠ k2 →
  (≡ (SET k1 v1 *> SET k2 v2) on db) = (≡ (SET k2 v2 *> SET k1 v1) on db) := by
  intro h_neq
  -- Rewrite using state_composition to get sequential states
  rw [state_composition, state_composition]
  -- Use observability to prove the two final states are equal
  apply @observability DB α γ ops
  -- Prove GET k' is equal on both sides for all k'
  · intro k'
    by_cases h1 : k' = k1
    · -- k' = k1: GET k1 returns v1 on both sides
      rw [h1]
      -- On LHS: SET k2 v2 (SET k1 v1 db), GET k1 = some v1 by isolation (k1 ≠ k2)
      have h_lhs : (⇐ GET k1 on (≡ SET k2 v2 on (≡ SET k1 v1 on db))) = some v1 := by
        have ⟨h_iso, _⟩ := @set_isolation DB α γ ops k2 k1 v2 (≡ SET k1 v1 on db) (Ne.symm h_neq)
        rw [← h_iso]
        exact get_after_set k1 v1 db
      -- On RHS: SET k1 v1 (SET k2 v2 db), GET k1 = some v1 directly
      have h_rhs : (⇐ GET k1 on (≡ SET k1 v1 on (≡ SET k2 v2 on db))) = some v1 := by
        exact get_after_set k1 v1 (≡ SET k2 v2 on db)
      rw [h_lhs, h_rhs]
    · by_cases h2 : k' = k2
      · -- k' = k2: GET k2 returns v2 on both sides
        rw [h2]
        -- On LHS: GET k2 after SET k2 v2 = some v2
        have h_lhs : (⇐ GET k2 on (≡ SET k2 v2 on (≡ SET k1 v1 on db))) = some v2 := by
          exact get_after_set k2 v2 (≡ SET k1 v1 on db)
        -- On RHS: SET k1 v1 doesn't affect k2 (by isolation)
        have h_rhs : (⇐ GET k2 on (≡ SET k1 v1 on (≡ SET k2 v2 on db))) = some v2 := by
          have ⟨h_iso, _⟩ := @set_isolation DB α γ ops k1 k2 v1 (≡ SET k2 v2 on db) h_neq
          rw [← h_iso]
          exact get_after_set k2 v2 db
        rw [h_lhs, h_rhs]
      · -- k' ≠ k1 and k' ≠ k2: GET k' unchanged on both sides
        have h_neq1 : k1 ≠ k' := Ne.symm h1
        have h_neq2 : k2 ≠ k' := Ne.symm h2
        -- LHS: GET k' unchanged through both SETs
        have ⟨h_iso_k1, _⟩ := @set_isolation DB α γ ops k1 k' v1 db h_neq1
        have ⟨h_iso_k2, _⟩ := @set_isolation DB α γ ops k2 k' v2 (≡ SET k1 v1 on db) h_neq2
        -- RHS: GET k' unchanged through both SETs (in opposite order)
        have ⟨h_iso_k2', _⟩ := @set_isolation DB α γ ops k2 k' v2 db h_neq2
        have ⟨h_iso_k1', _⟩ := @set_isolation DB α γ ops k1 k' v1 (≡ SET k2 v2 on db) h_neq1
        rw [← h_iso_k2, ← h_iso_k1, ← h_iso_k1', ← h_iso_k2']
  -- Prove EXISTS k' is equal on both sides for all k'
  · intro k'
    by_cases h1 : k' = k1
    · -- k' = k1: EXISTS k1 is true on both sides
      rw [h1]
      have h_lhs : (⇐ EXISTS k1 on (≡ SET k2 v2 on (≡ SET k1 v1 on db))) = true := by
        have ⟨_, h_iso⟩ := @set_isolation DB α γ ops k2 k1 v2 (≡ SET k1 v1 on db) (Ne.symm h_neq)
        rw [← h_iso]
        exact exists_after_set k1 v1 db
      have h_rhs : (⇐ EXISTS k1 on (≡ SET k1 v1 on (≡ SET k2 v2 on db))) = true := by
        exact exists_after_set k1 v1 (≡ SET k2 v2 on db)
      rw [h_lhs, h_rhs]
    · by_cases h2 : k' = k2
      · -- k' = k2: EXISTS k2 is true on both sides
        rw [h2]
        have h_lhs : (⇐ EXISTS k2 on (≡ SET k2 v2 on (≡ SET k1 v1 on db))) = true := by
          exact exists_after_set k2 v2 (≡ SET k1 v1 on db)
        have h_rhs : (⇐ EXISTS k2 on (≡ SET k1 v1 on (≡ SET k2 v2 on db))) = true := by
          have ⟨_, h_iso⟩ := @set_isolation DB α γ ops k1 k2 v1 (≡ SET k2 v2 on db) h_neq
          rw [← h_iso]
          exact exists_after_set k2 v2 db
        rw [h_lhs, h_rhs]
      · -- k' ≠ k1 and k' ≠ k2: EXISTS k' unchanged on both sides
        have h_neq1 : k1 ≠ k' := Ne.symm h1
        have h_neq2 : k2 ≠ k' := Ne.symm h2
        have ⟨_, h_iso_k1⟩ := @set_isolation DB α γ ops k1 k' v1 db h_neq1
        have ⟨_, h_iso_k2⟩ := @set_isolation DB α γ ops k2 k' v2 (≡ SET k1 v1 on db) h_neq2
        have ⟨_, h_iso_k2'⟩ := @set_isolation DB α γ ops k2 k' v2 db h_neq2
        have ⟨_, h_iso_k1'⟩ := @set_isolation DB α γ ops k1 k' v1 (≡ SET k2 v2 on db) h_neq1
        rw [← h_iso_k2, ← h_iso_k1, ← h_iso_k1', ← h_iso_k2']

-- DEL operations on different keys commute
theorem del_del_commute :
  k1 ≠ k2 →
  (≡ (DEL k1 *> DEL k2) on db) = (≡ (DEL k2 *> DEL k1) on db) := by
  intro h_neq
  rw [state_composition, state_composition]
  apply @observability DB α γ ops
  -- Prove GET k' is equal on both sides for all k'
  · intro k'
    by_cases h1 : k' = k1
    · -- k' = k1: GET k1 is none on both sides
      rw [h1]
      -- On LHS: DEL k2 (DEL k1 db), GET k1 is none by isolation (k1 ≠ k2)
      have h_lhs : (⇐ GET k1 on (≡ DEL k2 on (≡ DEL k1 on db))) = none := by
        have ⟨h_iso, _⟩ := @del_isolation DB α γ ops k2 k1 (≡ DEL k1 on db) (Ne.symm h_neq)
        rw [← h_iso]
        exact del_get_none k1 db
      -- On RHS: DEL k1 (DEL k2 db), GET k1 is none directly
      have h_rhs : (⇐ GET k1 on (≡ DEL k1 on (≡ DEL k2 on db))) = none := by
        exact del_get_none k1 (≡ DEL k2 on db)
      rw [h_lhs, h_rhs]
    · by_cases h2 : k' = k2
      · -- k' = k2: GET k2 is none on both sides
        rw [h2]
        have h_lhs : (⇐ GET k2 on (≡ DEL k2 on (≡ DEL k1 on db))) = none := by
          exact del_get_none k2 (≡ DEL k1 on db)
        have h_rhs : (⇐ GET k2 on (≡ DEL k1 on (≡ DEL k2 on db))) = none := by
          have ⟨h_iso, _⟩ := @del_isolation DB α γ ops k1 k2 (≡ DEL k2 on db) h_neq
          rw [← h_iso]
          exact del_get_none k2 db
        rw [h_lhs, h_rhs]
      · -- k' ≠ k1 and k' ≠ k2: GET k' unchanged on both sides
        have h_neq1 : k1 ≠ k' := Ne.symm h1
        have h_neq2 : k2 ≠ k' := Ne.symm h2
        have ⟨h_iso_k1, _⟩ := @del_isolation DB α γ ops k1 k' db h_neq1
        have ⟨h_iso_k2, _⟩ := @del_isolation DB α γ ops k2 k' (≡ DEL k1 on db) h_neq2
        have ⟨h_iso_k2', _⟩ := @del_isolation DB α γ ops k2 k' db h_neq2
        have ⟨h_iso_k1', _⟩ := @del_isolation DB α γ ops k1 k' (≡ DEL k2 on db) h_neq1
        rw [← h_iso_k2, ← h_iso_k1, ← h_iso_k1', ← h_iso_k2']
  -- Prove EXISTS k' is equal on both sides for all k'
  · intro k'
    by_cases h1 : k' = k1
    · -- k' = k1: EXISTS k1 is false on both sides
      rw [h1]
      have h_del_k1 : (⇐ EXISTS k1 on (≡ DEL k1 on db)) = false := by
        have h := @del_removes_key DB α γ ops k1 db
        rw [monadic_composition] at h
        exact h
      have h_lhs : (⇐ EXISTS k1 on (≡ DEL k2 on (≡ DEL k1 on db))) = false := by
        have ⟨_, h_iso⟩ := @del_isolation DB α γ ops k2 k1 (≡ DEL k1 on db) (Ne.symm h_neq)
        rw [← h_iso]
        exact h_del_k1
      have h_rhs : (⇐ EXISTS k1 on (≡ DEL k1 on (≡ DEL k2 on db))) = false := by
        have h := @del_removes_key DB α γ ops k1 (≡ DEL k2 on db)
        rw [monadic_composition] at h
        exact h
      rw [h_lhs, h_rhs]
    · by_cases h2 : k' = k2
      · -- k' = k2: EXISTS k2 is false on both sides
        rw [h2]
        have h_del_k2 : (⇐ EXISTS k2 on (≡ DEL k2 on db)) = false := by
          have h := @del_removes_key DB α γ ops k2 db
          rw [monadic_composition] at h
          exact h
        have h_lhs : (⇐ EXISTS k2 on (≡ DEL k2 on (≡ DEL k1 on db))) = false := by
          have h := @del_removes_key DB α γ ops k2 (≡ DEL k1 on db)
          rw [monadic_composition] at h
          exact h
        have h_rhs : (⇐ EXISTS k2 on (≡ DEL k1 on (≡ DEL k2 on db))) = false := by
          have ⟨_, h_iso⟩ := @del_isolation DB α γ ops k1 k2 (≡ DEL k2 on db) h_neq
          rw [← h_iso]
          exact h_del_k2
        rw [h_lhs, h_rhs]
      · -- k' ≠ k1 and k' ≠ k2: EXISTS k' unchanged on both sides
        have h_neq1 : k1 ≠ k' := Ne.symm h1
        have h_neq2 : k2 ≠ k' := Ne.symm h2
        have ⟨_, h_iso_k1⟩ := @del_isolation DB α γ ops k1 k' db h_neq1
        have ⟨_, h_iso_k2⟩ := @del_isolation DB α γ ops k2 k' (≡ DEL k1 on db) h_neq2
        have ⟨_, h_iso_k2'⟩ := @del_isolation DB α γ ops k2 k' db h_neq2
        have ⟨_, h_iso_k1'⟩ := @del_isolation DB α γ ops k1 k' (≡ DEL k2 on db) h_neq1
        rw [← h_iso_k2, ← h_iso_k1, ← h_iso_k1', ← h_iso_k2']

-- SET and DEL on different keys commute
theorem set_del_commute :
  k1 ≠ k2 →
  (≡ (SET k1 v *> DEL k2) on db) = (≡ (DEL k2 *> SET k1 v) on db) := by
  intro h_neq
  rw [state_composition, state_composition]
  apply @observability DB α γ ops
  -- Prove GET k' is equal on both sides for all k'
  · intro k'
    by_cases h1 : k' = k1
    · -- k' = k1: GET k1 returns some v on both sides
      rw [h1]
      -- LHS: DEL k2 (SET k1 v db), GET k1 = some v by isolation
      have h_lhs : (⇐ GET k1 on (≡ DEL k2 on (≡ SET k1 v on db))) = some v := by
        have ⟨h_iso, _⟩ := @del_isolation DB α γ ops k2 k1 (≡ SET k1 v on db) (Ne.symm h_neq)
        rw [← h_iso]
        exact get_after_set k1 v db
      -- RHS: SET k1 v (DEL k2 db), GET k1 = some v directly
      have h_rhs : (⇐ GET k1 on (≡ SET k1 v on (≡ DEL k2 on db))) = some v := by
        exact get_after_set k1 v (≡ DEL k2 on db)
      rw [h_lhs, h_rhs]
    · by_cases h2 : k' = k2
      · -- k' = k2: GET k2 is none on both sides
        rw [h2]
        -- LHS: GET k2 after DEL k2 = none
        have h_lhs : (⇐ GET k2 on (≡ DEL k2 on (≡ SET k1 v on db))) = none := by
          exact del_get_none k2 (≡ SET k1 v on db)
        -- RHS: SET k1 v doesn't affect k2, and DEL k2 made it none
        have h_rhs : (⇐ GET k2 on (≡ SET k1 v on (≡ DEL k2 on db))) = none := by
          have ⟨h_iso, _⟩ := @set_isolation DB α γ ops k1 k2 v (≡ DEL k2 on db) h_neq
          rw [← h_iso]
          exact del_get_none k2 db
        rw [h_lhs, h_rhs]
      · -- k' ≠ k1 and k' ≠ k2: GET k' unchanged on both sides
        have h_neq1 : k1 ≠ k' := Ne.symm h1
        have h_neq2 : k2 ≠ k' := Ne.symm h2
        have ⟨h_set_iso, _⟩ := @set_isolation DB α γ ops k1 k' v db h_neq1
        have ⟨h_del_iso, _⟩ := @del_isolation DB α γ ops k2 k' (≡ SET k1 v on db) h_neq2
        have ⟨h_del_iso', _⟩ := @del_isolation DB α γ ops k2 k' db h_neq2
        have ⟨h_set_iso', _⟩ := @set_isolation DB α γ ops k1 k' v (≡ DEL k2 on db) h_neq1
        rw [← h_del_iso, ← h_set_iso, ← h_set_iso', ← h_del_iso']
  -- Prove EXISTS k' is equal on both sides for all k'
  · intro k'
    by_cases h1 : k' = k1
    · -- k' = k1: EXISTS k1 is true on both sides
      rw [h1]
      have h_lhs : (⇐ EXISTS k1 on (≡ DEL k2 on (≡ SET k1 v on db))) = true := by
        have ⟨_, h_iso⟩ := @del_isolation DB α γ ops k2 k1 (≡ SET k1 v on db) (Ne.symm h_neq)
        rw [← h_iso]
        exact exists_after_set k1 v db
      have h_rhs : (⇐ EXISTS k1 on (≡ SET k1 v on (≡ DEL k2 on db))) = true := by
        exact exists_after_set k1 v (≡ DEL k2 on db)
      rw [h_lhs, h_rhs]
    · by_cases h2 : k' = k2
      · -- k' = k2: EXISTS k2 is false on both sides
        rw [h2]
        have h_del_k2 : (⇐ EXISTS k2 on (≡ DEL k2 on db)) = false := by
          have h := @del_removes_key DB α γ ops k2 db
          rw [monadic_composition] at h
          exact h
        have h_lhs : (⇐ EXISTS k2 on (≡ DEL k2 on (≡ SET k1 v on db))) = false := by
          have h := @del_removes_key DB α γ ops k2 (≡ SET k1 v on db)
          rw [monadic_composition] at h
          exact h
        have h_rhs : (⇐ EXISTS k2 on (≡ SET k1 v on (≡ DEL k2 on db))) = false := by
          have ⟨_, h_iso⟩ := @set_isolation DB α γ ops k1 k2 v (≡ DEL k2 on db) h_neq
          rw [← h_iso]
          exact h_del_k2
        rw [h_lhs, h_rhs]
      · -- k' ≠ k1 and k' ≠ k2: EXISTS k' unchanged on both sides
        have h_neq1 : k1 ≠ k' := Ne.symm h1
        have h_neq2 : k2 ≠ k' := Ne.symm h2
        have ⟨_, h_set_iso⟩ := @set_isolation DB α γ ops k1 k' v db h_neq1
        have ⟨_, h_del_iso⟩ := @del_isolation DB α γ ops k2 k' (≡ SET k1 v on db) h_neq2
        have ⟨_, h_del_iso'⟩ := @del_isolation DB α γ ops k2 k' db h_neq2
        have ⟨_, h_set_iso'⟩ := @set_isolation DB α γ ops k1 k' v (≡ DEL k2 on db) h_neq1
        rw [← h_del_iso, ← h_set_iso, ← h_set_iso', ← h_del_iso']

/-! ## Cancellation and Restoration Theorems

Sequences of operations that return the database to a previous state.
-/

-- DEL then SET restores state if key existed with that value
-- Proof: use observability; GET k returns some v in both (after SET), EXISTS k is true
-- For k' ≠ k: unchanged by isolation
theorem del_set_restore :
  (⇐ GET k on db) = some v →
  (≡ (DEL k *> SET k v) on db) = db := by
  intro h_get
  rw [state_composition]
  apply @observability DB α γ ops
  -- Prove GET k' is equal on both sides for all k'
  · intro k'
    by_cases h : k' = k
    · -- k' = k: GET k returns some v on both sides
      rw [h]
      -- After SET k v, GET k = some v
      have h_lhs : (⇐ GET k on (≡ SET k v on (≡ DEL k on db))) = some v := by
        exact get_after_set k v (≡ DEL k on db)
      rw [h_lhs, h_get]
    · -- k' ≠ k: GET k' unchanged
      have h_neq : k ≠ k' := Ne.symm h
      have ⟨h_del_iso, _⟩ := @del_isolation DB α γ ops k k' db h_neq
      have ⟨h_set_iso, _⟩ := @set_isolation DB α γ ops k k' v (≡ DEL k on db) h_neq
      rw [← h_set_iso, ← h_del_iso]
  -- Prove EXISTS k' is equal on both sides for all k'
  · intro k'
    by_cases h : k' = k
    · -- k' = k: EXISTS k is true on both sides
      rw [h]
      -- GET k = some v implies EXISTS k = true (via contrapositive of get_none_iff_nonexistent)
      have h_exists : (⇐ EXISTS k on db) = true := by
        cases h_exists_val : (⇐ EXISTS k on db) with
        | true => rfl
        | false =>
          -- If EXISTS k = false, then GET k = none, contradicting h_get = some v
          have h_get_none := (get_none_iff_nonexistent k db).mpr h_exists_val
          rw [h_get_none] at h_get
          cases h_get
      -- After SET k v, EXISTS k = true
      have h_lhs : (⇐ EXISTS k on (≡ SET k v on (≡ DEL k on db))) = true := by
        exact exists_after_set k v (≡ DEL k on db)
      rw [h_lhs, h_exists]
    · -- k' ≠ k: EXISTS k' unchanged
      have h_neq : k ≠ k' := Ne.symm h
      have ⟨_, h_del_iso⟩ := @del_isolation DB α γ ops k k' db h_neq
      have ⟨_, h_set_iso⟩ := @set_isolation DB α γ ops k k' v (≡ DEL k on db) h_neq
      rw [← h_set_iso, ← h_del_iso]

/-! ## Algebraic Laws

How operations compose and simplify.
-/

-- SET absorbs prior SET on same key (last write wins)
-- Proof: use observability; GET k returns v2 in both, EXISTS k is true in both
-- For k' ≠ k: unchanged by isolation
theorem set_absorbs_set :
  (≡ (SET k v1 *> SET k v2) on db) = (≡ SET k v2 on db) := by
  rw [state_composition]
  apply @observability DB α γ ops
  -- Prove GET k' is equal on both sides for all k'
  · intro k'
    by_cases h : k' = k
    · -- k' = k: GET k returns v2 on both sides
      rw [h]
      -- LHS: SET k v2 (SET k v1 db), GET k = some v2
      have h_lhs : (⇐ GET k on (≡ SET k v2 on (≡ SET k v1 on db))) = some v2 := by
        exact get_after_set k v2 (≡ SET k v1 on db)
      -- RHS: SET k v2 db, GET k = some v2
      have h_rhs : (⇐ GET k on (≡ SET k v2 on db)) = some v2 := by
        exact get_after_set k v2 db
      rw [h_lhs, h_rhs]
    · -- k' ≠ k: GET k' unchanged on both sides
      have h_neq : k ≠ k' := Ne.symm h
      have ⟨h_set_iso1, _⟩ := @set_isolation DB α γ ops k k' v1 db h_neq
      have ⟨h_set_iso2, _⟩ := @set_isolation DB α γ ops k k' v2 (≡ SET k v1 on db) h_neq
      have ⟨h_set_iso3, _⟩ := @set_isolation DB α γ ops k k' v2 db h_neq
      rw [← h_set_iso2, ← h_set_iso1, ← h_set_iso3]
  -- Prove EXISTS k' is equal on both sides for all k'
  · intro k'
    by_cases h : k' = k
    · -- k' = k: EXISTS k is true on both sides
      rw [h]
      have h_lhs : (⇐ EXISTS k on (≡ SET k v2 on (≡ SET k v1 on db))) = true := by
        exact exists_after_set k v2 (≡ SET k v1 on db)
      have h_rhs : (⇐ EXISTS k on (≡ SET k v2 on db)) = true := by
        exact exists_after_set k v2 db
      rw [h_lhs, h_rhs]
    · -- k' ≠ k: EXISTS k' unchanged on both sides
      have h_neq : k ≠ k' := Ne.symm h
      have ⟨_, h_set_iso1⟩ := @set_isolation DB α γ ops k k' v1 db h_neq
      have ⟨_, h_set_iso2⟩ := @set_isolation DB α γ ops k k' v2 (≡ SET k v1 on db) h_neq
      have ⟨_, h_set_iso3⟩ := @set_isolation DB α γ ops k k' v2 db h_neq
      rw [← h_set_iso2, ← h_set_iso1, ← h_set_iso3]

-- DEL absorbs prior SET on same key when key didn't exist originally
theorem del_absorbs_set_nonexistent :
  (⇐ EXISTS k on db) = false →
  (≡ (SET k v *> DEL k) on db) = db :=
  set_del_nonexistent_preserves_state k v db

-- DEL after SET is equivalent to just DEL when key exists
-- Proof: use observability; both result in GET k = none, EXISTS k = false
-- For k' ≠ k: unchanged by isolation
theorem set_then_del_eq_del :
  (⇐ EXISTS k on db) = true →
  (≡ (SET k v *> DEL k) on db) = (≡ DEL k on db) := by
  intro h_exists
  rw [state_composition]
  apply @observability DB α γ ops
  -- Prove GET k' is equal on both sides for all k'
  · intro k'
    by_cases h : k' = k
    · -- k' = k: GET k is none on both sides (after DEL)
      rw [h]
      -- LHS: DEL k (SET k v db), GET k = none
      have h_lhs : (⇐ GET k on (≡ DEL k on (≡ SET k v on db))) = none := by
        exact del_get_none k (≡ SET k v on db)
      -- RHS: DEL k db, GET k = none
      have h_rhs : (⇐ GET k on (≡ DEL k on db)) = none := by
        exact del_get_none k db
      rw [h_lhs, h_rhs]
    · -- k' ≠ k: GET k' unchanged on both sides
      have h_neq : k ≠ k' := Ne.symm h
      have ⟨h_set_iso, _⟩ := @set_isolation DB α γ ops k k' v db h_neq
      have ⟨h_del_iso1, _⟩ := @del_isolation DB α γ ops k k' (≡ SET k v on db) h_neq
      have ⟨h_del_iso2, _⟩ := @del_isolation DB α γ ops k k' db h_neq
      rw [← h_del_iso1, ← h_set_iso, ← h_del_iso2]
  -- Prove EXISTS k' is equal on both sides for all k'
  · intro k'
    by_cases h : k' = k
    · -- k' = k: EXISTS k is false on both sides (after DEL)
      rw [h]
      -- LHS
      have h_lhs : (⇐ EXISTS k on (≡ DEL k on (≡ SET k v on db))) = false := by
        have h1 := @del_removes_key DB α γ ops k (≡ SET k v on db)
        rw [monadic_composition] at h1
        exact h1
      -- RHS
      have h_rhs : (⇐ EXISTS k on (≡ DEL k on db)) = false := by
        have h1 := @del_removes_key DB α γ ops k db
        rw [monadic_composition] at h1
        exact h1
      rw [h_lhs, h_rhs]
    · -- k' ≠ k: EXISTS k' unchanged on both sides
      have h_neq : k ≠ k' := Ne.symm h
      have ⟨_, h_set_iso⟩ := @set_isolation DB α γ ops k k' v db h_neq
      have ⟨_, h_del_iso1⟩ := @del_isolation DB α γ ops k k' (≡ SET k v on db) h_neq
      have ⟨_, h_del_iso2⟩ := @del_isolation DB α γ ops k k' db h_neq
      rw [← h_del_iso1, ← h_set_iso, ← h_del_iso2]

/-! ## Structural Theorems

Properties about the structure of databases and operations.

Note: Some structural theorems involving multiple DB parameters require explicit type
annotations due to typeclass inference. The proof strategies are:

- db_determined_by_get: Use observability; GET equality implies EXISTS equality
  via get_none_iff_nonexistent (GET k = none ↔ EXISTS k = false)
- existence_requires_set: Follows from event_sourcing_principle - any state change
  must come from a sequence of SET/DEL operations, and only SET can create keys
-/

/-! ## Additional Helper Lemmas -/

-- DEL returns false iff key didn't exist
-- Proof: direct consequence of del_returns_status
theorem del_returns_false_iff_nonexistent :
  (⇐ DEL k on db) = false ↔ (⇐ EXISTS k on db) = false := by
  have h := @del_returns_status DB α γ ops k db
  constructor
  · intro h_del; rw [h] at h_del; exact h_del
  · intro h_exists; rw [h]; exact h_exists

-- After SET, the database is not empty (at least one key exists)
-- This is equivalent to: EXISTS k on (≡ SET k v on db) = true
-- Which follows directly from exists_after_set
theorem set_makes_key_exist :
  (⇐ EXISTS k on (≡ SET k v on db)) = true := exists_after_set k v db

end AbstractRedis

end RedisModel.AbstractMinimal
