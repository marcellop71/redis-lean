# Redis Model

This project provides a **formal mathematical model** of Redis operations using Lean's theorem proving capabilities. The model serves as both a specification and a verification framework for Redis behavior.

### Abstract operations

The model defines an abstract Redis interface without concrete implementations
(and some concise notation to make axioms more readable):

```lean
-- Redis operations as state monad computations
abbrev RedisM (DB : Type) (α : Type) := StateT DB Id α

-- Abstract Redis operations interface
class AbstractOps (DB α γ : Type) where
  set : α → γ → RedisM DB Unit
  get : α → RedisM DB (Option γ)
  del : α → RedisM DB Bool
  existsKey : α → RedisM DB Bool

namespace RedisM
  def result {DB α} (m : RedisM DB α) (db : DB) : α := (m.run db).fst
  def state {DB α} (m : RedisM DB α) (db : DB) : DB := (m.run db).snd
end RedisM

notation:70 "⇐" m " on " db => RedisM.result m db
notation:70 "≡ " m " on " db => RedisM.state m db
```

- **`⇐ operation on database`** - Evaluates the operation and returns the **result value**
- **`≡ operation on database`** - Executes the operation and returns the **final database state**

### Axioms

```lean
-- Read-only operations preserve database state
axiom get_preserves_state :
  ∀ (k : α), (≡ ops.get k on db) = db

axiom existsKey_preserves_state :
  ∀ (k : α), (≡ ops.existsKey k on db) = db

-- State alteration conditions
axiom del_alters_state_iff_exists :
  (≡ ops.del k on db) ≠ db ↔ (⇐ ops.existsKey k on db) = true

axiom set_alters_state_iff_new_or_different :
  (≡ ops.set k v on db) ≠ db ↔
  ((⇐ ops.existsKey k on db) = false ∨ (⇐ ops.get k on db) ≠ some v)

-- Setting creates keys and enables retrieval
axiom set_creates_key :
  (⇐ (ops.set k v *> ops.existsKey k) on db) = true

axiom set_get_consistency :
  (⇐ (ops.set k v *> ops.get k) on db) = some v

-- Set is idempotent when setting to current value
axiom set_idempotent :
  (⇐ ops.get k on db) = some v → (≡ ops.set k v on db) = db

-- Getting a non-existent key returns none
axiom get_nonexistent :
  (⇐ ops.get k on db) = none → (⇐ ops.existsKey k on db) = false

-- Setting overwrites previous values
axiom set_overwrite :
  (⇐ (ops.set k v1 *> ops.set k v2 *> ops.get k) on db) = some v2

-- Key isolation - operations on different keys don't interfere
axiom set_isolation :
  k1 ≠ k2 →
  (⇐ ops.get k2 on db) = (⇐ (ops.set k1 v *> ops.get k2) on db)

-- Deletion properties
axiom del_removes_key :
  (⇐ (ops.del k *> ops.existsKey k) on db) = false

axiom del_returns_status :
  (⇐ ops.del k on db) = (⇐ ops.existsKey k on db)

axiom del_affects_get :
  (⇐ (ops.del k *> ops.get k) on db) = none

axiom exists_empty_db : 
  ∃ (empty_db : DB), (∀ (k : α), (⇐ ops.existsKey k on empty_db) = false)

axiom observability :
  ∀ (db1 db2 : DB),
    (∀ (k : α), (⇐ ops.get k on db1) = (⇐ ops.get k on db2)) →
    (∀ (k : α), (⇐ ops.existsKey k on db1) = (⇐ ops.existsKey k on db2)) →
    db1 = db2
```

It is important also to capture Redis as an event-sourced system where database state results from applying operations sequentially:

```lean
axiom event_sourcing_principle :
  ∀ (db : DB), ∃ (empty_db : DB) (history : EventHistory DB),
    (∀ (k : α), (⇐ ops.existsKey k on empty_db) = false) ∧
    (applyHistory history empty_db = db)
```

Some (very) elementary theorems:

```lean
-- Setting a key makes it exist
theorem set_makes_key_exist :
  (⇐ (ops.set k v *> ops.existsKey k) on db) = true

-- Getting after setting returns the set value
theorem get_after_set :
  (⇐ (ops.set k v *> ops.get k) on db) = some v

-- Deleting a non-existent key returns false
theorem del_nonexistent_returns_false :
  (⇐ ops.existsKey k on db) = false → (⇐ ops.del k on db) = false
```

### Why formal modeling?

What is *Redis*? Building a model of this database means giving a precise answer to this question, precise specifications for your objects. A model is an abstract, conceptual playground, where you can prove theorems and establish properties, you can make assumptions and derive claims.

- **Brainstorming**: The formal model enables reasoning about fundamental Redis properties
- **Precision**: Mathematical definitions eliminate ambiguity found in informal specifications  
- **Verification**: Prove correctness properties that testing alone cannot guarantee  
- **Documentation**: Executable specifications that serve as authoritative references  
- **Confidence**: Mathematical certainty about system behavior under all conditions

This approach separates the **what** (abstract specification) from the **how** (concrete implementation), enabling rigorous mathematical reasoning about Redis behavior independently of implementation details.

Clearly enough, working on a model of Redis is quite different from building a client, which is meant to interact with the real *Redis*.

A well-done model could provide the mathematical framework for:

- **Event Sourcing Verification**: Prove that any Redis implementation correctly implements event sourcing semantics where state is derived from operation history
- **Consistency Guarantees**: Formally verify that operations maintain consistency invariants like key isolation and set-get coherence
- **State Reconstruction**: Mathematically demonstrate that database state can be reconstructed by replaying write operations from empty initial state
- **Implementation Correctness**: Provide specification against which concrete Redis implementations can be verified
- **Usage for Verification**: The abstract model serves as a formal specification that concrete implementations should satisfy.

Ultimately, we need models that reflect reality: models of databases, models of networks, models of all the relevant components. Only with such models can we demonstrate interesting properties within the model.

## Future enhancements

- extending the model to include expiration of keys (would allow us to show that a GET following a SET might not actually return the key if the GET happens after the key has expired)
- adding support for more complex Redis data types (lists, sets, hashes)
