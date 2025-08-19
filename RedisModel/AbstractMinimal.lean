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

-- definition of empty database using RedisM evaluation
def empty (db : DB) := ∀ (k : α), (⇐ ops.existsKey k on db) = false

-- definition of non-empty database using RedisM evaluation
def non_empty (db : DB) := ∃ (k : α), (⇐ ops.existsKey k on db) = true

-- get don't modify the database state
axiom get_preserves_state :
  ∀ (k : α), (≡ ops.get k on db) = db

-- existsKey don't modify the database state
axiom existsKey_preserves_state :
  ∀ (k : α), (≡ ops.existsKey k on db) = db

-- del alters state only if the key exists
axiom del_alters_state_iff_exists :
  (≡ ops.del k on db) ≠ db ↔ (⇐ ops.existsKey k on db) = true

-- set alters state only if key doesn't exist or exists with different value
axiom set_alters_state_iff_new_or_different :
  (≡ ops.set k v on db) ≠ db ↔
  ((⇐ ops.existsKey k on db) = false ∨ (⇐ ops.get k on db) ≠ some v)

-- after setting a key-value pair, getting that key returns the set value
axiom set_get_consistency :
  (⇐ (ops.set k v *> ops.get k) on db) = some v

-- getting a non-existent key returns none implies key doesn't exist
axiom get_nonexistent :
  (⇐ ops.get k on db) = none → (⇐ ops.existsKey k on db) = false

-- if a key doesn't exist, getting it returns none
axiom get_nonexistent_key :
  (⇐ ops.existsKey k on db) = false → (⇐ ops.get k on db) = none

-- monadic composition axiom: (m1 *> m2) is equivalent to m2 on the state after m1
axiom monadic_composition {α β : Type} (m1 : RedisM DB α) (m2 : RedisM DB β) :
  (⇐ (m1 *> m2) on db) = (⇐ m2 on (≡ m1 on db))

-- operations on different keys don't interfere
axiom set_isolation :
  k1 ≠ k2 →
  (⇐ ops.get k2 on db) = (⇐ (ops.set k1 v *> ops.get k2) on db)

-- deleting a key makes it not exist
axiom del_removes_key :
  (⇐ (ops.del k *> ops.existsKey k) on db) = false

-- delete returns true if key existed, false otherwise
axiom del_returns_status :
  (⇐ ops.del k on db) = (⇐ ops.existsKey k on db)

-- there exists an initial empty database state
axiom exists_empty_db : ∃ (db : DB), (∀ (k : α), (⇐ ops.existsKey k on db) = false)

-- if two databases have same observable behavior, they represent same state
axiom observability :
  ∀ (db1 db2 : DB),
    (∀ (k : α), (⇐ ops.get k on db1) = (⇐ ops.get k on db2)) →
    (∀ (k : α), (⇐ ops.existsKey k on db1) = (⇐ ops.existsKey k on db2)) →
    db1 = db2

-- two databases are equivalent if they have the same observable behavior
def db_equivalent (db1 db2 : DB) : Prop :=
  ∀ (k : α), (⇐ ops.get k on db1) = (⇐ ops.get k on db2) ∧
             (⇐ ops.existsKey k on db1) = (⇐ ops.existsKey k on db2)

-- Event Sourcing Model: Database state as result of operation sequences

def AlterOp (DB : Type) := RedisM DB Unit

def EventHistory (DB : Type) := List (AlterOp DB)

def applyAlterOp {DB : Type} (op : AlterOp DB) (db : DB) : DB :=
  (≡ op on db)

def applyHistory {DB : Type} : EventHistory DB → DB → DB
  | [], db => db
  | op :: rest, db => applyHistory rest (applyAlterOp op db)

-- sourcing axiom: any database state can be represented
-- as the result of applying a sequence of write operations to an empty database
axiom event_sourcing_principle :
  ∀ (db : DB), ∃ (empty_db : DB) (history : EventHistory DB),
    (∀ (k : α), (⇐ ops.existsKey k on empty_db) = false) ∧
    (applyHistory history empty_db = db)

example (k : α) (v : γ) : AlterOp DB := ops.set k v
example (k : α) : AlterOp DB := (ops.del k).map (fun _ => ())
example (k1 k2 : α) (v1 v2 : γ) : EventHistory DB :=
  [ops.set k1 v1, ops.set k2 v2, (ops.del k1).map (fun _ => ())]

-- after deletion, get returns none  
theorem del_affects_get :
  (⇐ (ops.del k *> ops.get k) on db) = none := by
  rw [monadic_composition]
  have h1 : (⇐ (ops.del k *> ops.existsKey k) on db) = false := del_removes_key k db
  have h2 : (⇐ ops.existsKey k on (≡ ops.del k on db)) = false := by
    rw [← monadic_composition]
    exact h1
  exact get_nonexistent_key k (≡ ops.del k on db) h2

-- set is idempotent: setting a key to its current value doesn't change state
theorem set_idempotent :
  (⇐ ops.get k on db) = some v → (≡ ops.set k v on db) = db := by
  intro h
  suffices h_not_neq : ¬((≡ ops.set k v on db) ≠ db) by
    exact Classical.not_not.mp h_not_neq
  rw [set_alters_state_iff_new_or_different]
  simp only [not_or]
  constructor
  · 
    intro h_key_not_exists
    have get_none := get_nonexistent_key k db h_key_not_exists
    rw [h] at get_none
    simp at get_none
  · 
    intro h_value_different
    exact h_value_different h

-- setting a key-value pair makes the key exist
theorem set_creates_key :
  (⇐ (ops.set k v *> ops.existsKey k) on db) = true := by
  rw [monadic_composition]
  have h_get_some : (⇐ ops.get k on (≡ ops.set k v on db)) = some v := by
    rw [← monadic_composition]
    exact set_get_consistency k v db
  have h_not_false : ¬((⇐ ops.existsKey k on (≡ ops.set k v on db)) = false) := by
    intro h_false
    have h_get_none := get_nonexistent_key k (≡ ops.set k v on db) h_false
    rw [h_get_some] at h_get_none
    simp at h_get_none
  cases h_eq : (⇐ ops.existsKey k on (≡ ops.set k v on db))
  · exact False.elim (h_not_false h_eq)
  · rfl

-- setting a key twice overwrites the previous value
theorem set_overwrite :
  (⇐ (ops.set k v1 *> ops.set k v2 *> ops.get k) on db) = some v2 := by
  rw [monadic_composition]
  exact set_get_consistency k v2 (≡ ops.set k v1 on db)

end AbstractRedis

end RedisModel.AbstractMinimal
