import RedisLean.Mathlib.Core
import RedisLean.Mathlib.TacticCache
import RedisLean.Mathlib.TheoremSearch
import RedisLean.Mathlib.Declaration
import RedisLean.Mathlib.InstanceCache
import RedisLean.Mathlib.ProofState
import RedisLean.Mathlib.DistProof

/-!
# Lean/Mathlib Integration Features

This module provides Redis-backed features designed for Lean and Mathlib development:

- **TacticCache**: Cache elaboration results to speed up repeated tactic applications
- **TheoremSearch**: Type-indexed search for theorems by conclusion, hypotheses, or name
- **Declaration**: Store and query Lean declarations with dependency tracking
- **InstanceCache**: Cache type class instance synthesis results
- **ProofState**: Snapshot and replay proof states for time-travel debugging
- **DistProof**: Coordinate distributed proof checking across multiple workers

## Usage Example

```lean
import RedisLean
import RedisLean.Mathlib

open Redis Redis.Mathlib

-- Create caches
def tacticCache := TacticCache.create "myproject"
def theoremSearch := TheoremSearch.create "myproject"

-- In your elaborator/tactic:
-- let hash := hashSyntax stx
-- let result ← tacticCache.getOrElaborate hash (elaborate stx)

-- Search for theorems:
-- let results ← theoremSearch.searchByConclusion (.const "Nat.add_comm") 10
```

## Key Naming Conventions

All keys use a hierarchical namespace pattern:
- `{prefix}:tactic:{hash}` - Cached elaboration results
- `{prefix}:thm:*` - Theorem search indices
- `{prefix}:decl:{name}` - Declaration storage
- `{prefix}:instance:{class}:{type}` - Instance cache
- `{prefix}:proof:*` - Proof state snapshots
- `{prefix}:dist:*` - Distributed checking coordination
-/
