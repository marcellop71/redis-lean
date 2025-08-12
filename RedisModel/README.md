# Redis Model

This project provides a **formal mathematical model** of Redis operations using Lean's theorem proving capabilities. The model serves as both a specification and a verification framework for Redis behavior.

## AI-Assisted Theorem Proving Disclaimer

Some theorems in this module were proven with the assistance of **Claude** (Anthropic's AI assistant). This is perfectly safe because we are working within Lean's formal verification system:

- **Lean verifies all proofs**: Every theorem is machine-checked by the Lean compiler. If a proof is incorrect, Lean will reject it with an error.
- **No trust required in the AI**: The AI merely suggests proof strategies; Lean independently validates correctness.
- **Mathematical certainty**: A successful `lake build` with no warnings means all proofs are logically valid.

This demonstrates the power of formal methods: you can accept proof assistance from any source (human or AI) while maintaining absolute confidence in correctness through mechanical verification.

## Abstract Redis Interface

The model defines an abstract Redis interface without concrete implementations:

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

-- Concise notations for RedisM evaluation
notation:70 "⇐" m " on " db => RedisM.result m db
notation:70 "≡ " m " on " db => RedisM.state m db

-- Local notation for cleaner axioms and theorems
local notation "GET" => ops.get
local notation "SET" => ops.set
local notation "DEL" => ops.del
local notation "EXISTS" => ops.existsKey
```

- **`⇐ operation on database`** - Evaluates the operation and returns the **result value**
- **`≡ operation on database`** - Executes the operation and returns the **final database state**
- **Local notation** - `GET`, `SET`, `DEL`, `EXISTS` for cleaner, more readable axioms

## Design Insights

### 1. Observability as Extensionality

The `observability` axiom is particularly powerful: it states that database state is uniquely determined by observable behavior (GET and EXISTS results for all keys). This enables proving state equality by checking all observables, effectively treating DB as a partial function `α → Option γ`.

### 2. Minimal but Complete Axiom System

The 13 axioms capture essential Redis semantics:
- Read operations preserve state (`get_preserves_state`, `existsKey_preserves_state`)
- Write operations have precise state-change conditions (`set_alters_state_iff_new_or_different`, `del_alters_state_iff_exists`)
- Isolation guarantees for operations on different keys
- Consistency between GET and EXISTS

### 3. Event Sourcing Model

The `event_sourcing_principle` axiom captures that any database state can be reconstructed from an empty database by applying a sequence of SET and DEL operations. This is existential rather than constructive - a constructive version would be more useful for verification.

### 4. Limitations of Current Model

- Errors are not modeled (real Redis operations can fail)
- Single value type γ (real Redis has strings, lists, sets, hashes, sorted sets, streams)
- No TTL/expiry modeling
- No atomic compound operations (SETNX, GETSET, INCR)
- No concurrency/linearizability properties

## Core Axioms

### Foundational Principles

```lean
-- Monadic composition: sequential operations
axiom monadic_composition {α β : Type} (m1 : RedisM DB α) (m2 : RedisM DB β) :
  (⇐ (m1 *> m2) on db) = (⇐ m2 on (≡ m1 on db))

-- Read-only operations preserve database state
axiom get_preserves_state : ∀ (k : α), (≡ GET k on db) = db
axiom existsKey_preserves_state : ∀ (k : α), (≡ EXISTS k on db) = db

-- Empty database existence
axiom exists_empty_db : ∃ (db : DB), (∀ (k : α), (⇐ EXISTS k on db) = false)

-- Database observability: equivalent behavior implies equal state
axiom observability :
  ∀ (db1 db2 : DB),
    (∀ (k : α), (⇐ GET k on db1) = (⇐ GET k on db2)) →
    (∀ (k : α), (⇐ EXISTS k on db1) = (⇐ EXISTS k on db2)) →
    db1 = db2
```

### Operation Behavior

```lean
-- State alteration conditions
axiom del_alters_state_iff_exists :
  (≡ DEL k on db) ≠ db ↔ (⇐ EXISTS k on db) = true

axiom set_alters_state_iff_new_or_different :
  (≡ SET k v on db) ≠ db ↔
  ((⇐ EXISTS k on db) = false ∨ (⇐ GET k on db) ≠ some v)

-- Core operation consistency
axiom set_get_consistency : (⇐ (SET k v *> GET k) on db) = some v
axiom get_none_iff_nonexistent : (⇐ GET k on db) = none ↔ (⇐ EXISTS k on db) = false

-- Deletion behavior
axiom del_removes_key : (⇐ (DEL k *> EXISTS k) on db) = false
axiom del_returns_status : (⇐ DEL k on db) = (⇐ EXISTS k on db)

-- Key isolation: operations on different keys don't interfere
axiom key_isolation :
  ∀ (k1 k2 : α) (v : γ) (db : DB), k1 ≠ k2 →
    (⇐ GET k2 on db) = (⇐ GET k2 on (≡ SET k1 v on db)) ∧
    (⇐ EXISTS k2 on db) = (⇐ EXISTS k2 on (≡ SET k1 v on db))

axiom del_isolation :
  ∀ (k1 k2 : α) (db : DB), k1 ≠ k2 →
    (⇐ GET k2 on db) = (⇐ GET k2 on (≡ DEL k1 on db)) ∧
    (⇐ EXISTS k2 on db) = (⇐ EXISTS k2 on (≡ DEL k1 on db))
```

## Event Sourcing Model

The model captures Redis as an event-sourced system where database state results from applying SET and DEL operations sequentially:

```lean
-- Event history as composition of AbstractOps state transformations
def EventHistory (DB : Type) := List (DB → DB)

def applyHistory {DB : Type} : EventHistory DB → DB → DB
  | [], db => db
  | op :: rest, db => applyHistory rest (op db)

-- Any database state can be represented as the result of applying
-- a sequence of SET and DEL operations to an empty database
axiom event_sourcing_principle :
  ∀ (db : DB), ∃ (empty_db : DB) (ops_sequence : List (DB → DB)),
    (∀ (k : α), (⇐ EXISTS k on empty_db) = false) ∧
    (∀ f ∈ ops_sequence, ∃ (k : α) (v : γ), (∀ db', f db' = (≡ SET k v on db')) ∨
                          ∃ (k : α), (∀ db', f db' = (≡ DEL k on db'))) ∧
    (applyHistory ops_sequence empty_db = db)
```

## Proven Theorems

The theorems fall into several categories:

### Basic Properties
Direct consequences of axioms:

```lean
-- After deletion, get returns none
theorem del_affects_get :
  (⇐ (DEL k *> GET k) on db) = none

-- Setting a key-value pair makes the key exist
theorem set_creates_key :
  (⇐ (SET k v *> EXISTS k) on db) = true

-- Setting a key twice overwrites the previous value
theorem set_overwrite :
  (⇐ (SET k v1 *> SET k v2 *> GET k) on db) = some v2

-- GET returns none after DEL
theorem del_get_none :
  (⇐ GET k on (≡ DEL k on db)) = none
```

### Idempotence Theorems
Operations that don't change state when repeated:

```lean
-- Set is idempotent: setting a key to its current value doesn't change state
theorem set_idempotent :
  (⇐ GET k on db) = some v → (≡ SET k v on db) = db

-- DEL is idempotent: deleting twice is same as deleting once
theorem del_idempotent :
  (≡ (DEL k *> DEL k) on db) = (≡ DEL k on db)

-- SET-SET with same value is idempotent
theorem set_set_same_idempotent :
  (≡ (SET k v *> SET k v) on db) = (≡ SET k v on db)
```

### Commutativity Theorems
Operations on different keys can be reordered:

```lean
-- SET operations on different keys commute
theorem set_set_commute :
  k1 ≠ k2 →
  (≡ (SET k1 v1 *> SET k2 v2) on db) = (≡ (SET k2 v2 *> SET k1 v1) on db)

-- DEL operations on different keys commute
theorem del_del_commute :
  k1 ≠ k2 →
  (≡ (DEL k1 *> DEL k2) on db) = (≡ (DEL k2 *> DEL k1) on db)

-- SET and DEL on different keys commute
theorem set_del_commute :
  k1 ≠ k2 →
  (≡ (SET k1 v *> DEL k2) on db) = (≡ (DEL k2 *> SET k1 v) on db)
```

### Cancellation and Restoration Theorems
Sequences that return to original state:

```lean
-- If a key doesn't exist, set followed by del doesn't alter the state
theorem set_del_nonexistent_preserves_state :
  (⇐ EXISTS k on db) = false → (≡ (SET k v *> DEL k) on db) = db

-- DEL then SET restores state if key existed with that value
theorem del_set_restore :
  (⇐ GET k on db) = some v →
  (≡ (DEL k *> SET k v) on db) = db
```

### Algebraic Laws
How operations compose and simplify:

```lean
-- SET absorbs prior SET on same key (last write wins)
theorem set_absorbs_set :
  (≡ (SET k v1 *> SET k v2) on db) = (≡ SET k v2 on db)

-- DEL after SET is equivalent to just DEL when key exists
theorem set_then_del_eq_del :
  (⇐ EXISTS k on db) = true →
  (≡ (SET k v *> DEL k) on db) = (≡ DEL k on db)

-- DEL absorbs prior SET on same key when key didn't exist originally
theorem del_absorbs_set_nonexistent :
  (⇐ EXISTS k on db) = false →
  (≡ (SET k v *> DEL k) on db) = db
```

### Transparency Theorems
Read operations don't affect subsequent operations:

```lean
-- GET is transparent: doesn't affect state for subsequent operations
theorem get_transparent {β : Type} (m : RedisM DB β) :
  (≡ (GET k *> m) on db) = (≡ m on db)

-- EXISTS is transparent: doesn't affect state for subsequent operations
theorem exists_transparent {β : Type} (m : RedisM DB β) :
  (≡ (EXISTS k *> m) on db) = (≡ m on db)
```

## Why Formal Modeling?

What is *Redis*? Building a model of this database means giving a precise answer to this question, precise specifications for your objects. A model is an abstract, conceptual playground, where you can prove theorems and establish properties, you can make assumptions and derive claims.

### Benefits

- **Precision**: Mathematical definitions eliminate ambiguity found in informal specifications
- **Verification**: Prove correctness properties that testing alone cannot guarantee
- **Documentation**: Executable specifications that serve as authoritative references
- **Confidence**: Mathematical certainty about system behavior under all conditions
- **Brainstorming**: The formal model enables reasoning about fundamental Redis properties

This approach separates the **what** (abstract specification) from the **how** (concrete implementation), enabling rigorous mathematical reasoning about Redis behavior independently of implementation details.

### Applications

A well-done model provides the mathematical framework for:

- **Event Sourcing Verification**: Prove that any Redis implementation correctly implements event sourcing semantics where state is derived from operation history
- **Consistency Guarantees**: Formally verify that operations maintain consistency invariants like key isolation and set-get coherence
- **State Reconstruction**: Mathematically demonstrate that database state can be reconstructed by replaying write operations from empty initial state
- **Implementation Correctness**: Provide specification against which concrete Redis implementations can be verified
- **Property Discovery**: Find interesting theorems like `set_del_nonexistent_preserves_state` that reveal non-obvious system behaviors

### Current Status

The model currently includes:
- **13 core axioms** defining Redis behavior
- **20+ proven theorems** demonstrating key properties (basic, idempotence, commutativity, cancellation, algebraic laws)
- **Event sourcing principle** using the same `AbstractOps` interface
- **Local notation** (`GET`, `SET`, `DEL`, `EXISTS`) for readable specifications
- **Key isolation axioms** for both set and delete operations

## Future Enhancements

- **Key Expiration**: Extend the model to include TTL (time-to-live) for keys, allowing proofs about temporal behavior
- **Complex Data Types**: Add support for Redis lists, sets, hashes, and sorted sets
- **Transactions**: Model Redis MULTI/EXEC transaction semantics
- **Persistence**: Model Redis persistence guarantees and recovery behavior
- **Replication**: Extend to multi-node Redis clusters with consistency models
