-- AbstractOps in Ops.lean collects some real Redis operations
-- This module is meant to define an abstract Redis interface, a formal theoretical model for AbstractOps,
-- the theoretical foundations and axioms that the real Redis is expected to satisfy.

import RedisLean.Ops
import RedisLean.Codec

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

-- if a key doesn't exist, set followed by del doesn't alter the state
theorem set_del_nonexistent_preserves_state :
  (⇐ EXISTS k on db) = false → (≡ (SET k v *> DEL k) on db) = db := by
  intro h_not_exists
  sorry

end AbstractRedis

end RedisModel.AbstractMinimal
