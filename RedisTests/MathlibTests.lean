import LSpec
import RedisLean.Mathlib.Core
import RedisLean.Mathlib.TacticCache
import RedisLean.Mathlib.TheoremSearch
import RedisLean.Mathlib.Declaration
import RedisLean.Mathlib.InstanceCache
import RedisLean.Mathlib.ProofState
import RedisLean.Mathlib.DistProof
import RedisLean.Expr

open Redis LSpec
open Redis.Mathlib

namespace RedisTests.MathlibTests

/-!
# Mathlib Integration Tests

Tests for the Mathlib-specific Redis integration features.
These test the data structures and utilities without requiring a Redis connection.
-/

-- SimpleExpr Tests (from RedisLean.Expr)

def simpleExprTests : TestSeq :=
  test "SimpleExpr.bvar creation" (
    let expr := SimpleExpr.bvar 0
    match expr with
    | SimpleExpr.bvar n => n == 0
    | _ => false) $
  test "SimpleExpr.const creation" (
    let expr := SimpleExpr.const "Nat.add" []
    match expr with
    | SimpleExpr.const name _ => name == "Nat.add"
    | _ => false) $
  test "SimpleExpr.app creation" (
    let fn := SimpleExpr.const "f" []
    let arg := SimpleExpr.bvar 0
    let app := SimpleExpr.app fn arg
    match app with
    | SimpleExpr.app _ _ => true
    | _ => false) $
  test "SimpleExpr.lam creation" (
    let body := SimpleExpr.bvar 0
    let lam := SimpleExpr.lam "x" (SimpleExpr.const "Nat" []) body
    match lam with
    | SimpleExpr.lam name _ _ => name == "x"
    | _ => false) $
  test "SimpleExpr.forallE creation" (
    let body := SimpleExpr.const "Prop" []
    let forallExpr := SimpleExpr.forallE "x" (SimpleExpr.const "Nat" []) body
    match forallExpr with
    | SimpleExpr.forallE name _ _ => name == "x"
    | _ => false) $
  test "SimpleExpr.sort creation" (
    let sort := SimpleExpr.sort 0
    match sort with
    | SimpleExpr.sort level => level == 0
    | _ => false)

-- TypePattern Tests

def typePatternTests : TestSeq :=
  test "TypePattern.const creation" (
    let pat := TypePattern.const "Nat"
    match pat with
    | TypePattern.const name => name == "Nat"
    | _ => false) $
  test "TypePattern.app creation" (
    let fn := TypePattern.const "List"
    let arg := TypePattern.const "Nat"
    let app := TypePattern.app fn arg
    match app with
    | TypePattern.app _ _ => true
    | _ => false) $
  test "TypePattern.arrow creation" (
    let dom := TypePattern.const "Nat"
    let cod := TypePattern.const "Nat"
    let arrow := TypePattern.arrow dom cod
    match arrow with
    | TypePattern.arrow _ _ => true
    | _ => false) $
  test "TypePattern.forallE creation" (
    let body := TypePattern.const "Prop"
    let forallPat := TypePattern.forallE "α" body
    match forallPat with
    | TypePattern.forallE name _ => name == "α"
    | _ => false) $
  test "TypePattern.var creation" (
    let v := TypePattern.var 0
    match v with
    | TypePattern.var idx => idx == 0
    | _ => false) $
  test "TypePattern.any creation" (
    match TypePattern.any with
    | TypePattern.any => true
    | _ => false) $
  test "TypePattern.hash produces value" (
    let pat := TypePattern.const "Nat"
    pat.hash > 0 || pat.hash == 0) $  -- Just check it doesn't crash
  test "TypePattern.toEncodedString" (
    let pat := TypePattern.const "Nat"
    pat.toEncodedString.length > 0)

-- TypePattern Matching Tests

def typePatternMatchingTests : TestSeq :=
  test "any matches anything" (
    TypePattern.matchesPattern .any (.const "Anything")) $
  test "const matches same const" (
    TypePattern.matchesPattern (.const "Nat") (.const "Nat")) $
  test "const doesn't match different const" (
    not (TypePattern.matchesPattern (.const "Nat") (.const "Int"))) $
  test "app matches app with matching parts" (
    TypePattern.matchesPattern
      (.app (.const "List") .any)
      (.app (.const "List") (.const "Nat"))) $
  test "arrow matches arrow" (
    TypePattern.matchesPattern
      (.arrow (.const "Nat") (.const "Nat"))
      (.arrow (.const "Nat") (.const "Nat")))

-- CheckStatus Tests

def checkStatusTests : TestSeq :=
  test "CheckStatus.pending" (
    match CheckStatus.pending with
    | CheckStatus.pending => true
    | _ => false) $
  test "CheckStatus.claimed" (
    let status := CheckStatus.claimed "worker1" 1000
    match status with
    | CheckStatus.claimed w t => w == "worker1" && t == 1000
    | _ => false) $
  test "CheckStatus.checking" (
    let status := CheckStatus.checking "worker1" 1000 50
    match status with
    | CheckStatus.checking w t p => w == "worker1" && t == 1000 && p == 50
    | _ => false) $
  test "CheckStatus.completed" (
    let status := CheckStatus.completed "worker1" 2000 true
    match status with
    | CheckStatus.completed w t s => w == "worker1" && t == 2000 && s == true
    | _ => false) $
  test "CheckStatus.failed" (
    let status := CheckStatus.failed "worker1" 2000 "error message"
    match status with
    | CheckStatus.failed w t e => w == "worker1" && t == 2000 && e == "error message"
    | _ => false)

-- Module Tests

def moduleTests : TestSeq :=
  test "Module creation" (
    let mod : Module := {
      name := "Mathlib.Algebra.Group"
      dependencies := ["Mathlib.Algebra.Monoid", "Mathlib.Logic.Basic"]
      complexity := 100
      sourcePath := "Mathlib/Algebra/Group.lean"
    }
    mod.name == "Mathlib.Algebra.Group") $
  test "Module with no dependencies" (
    let mod : Module := {
      name := "Init.Core"
      dependencies := []
      complexity := 10
      sourcePath := "Init/Core.lean"
    }
    mod.dependencies.length == 0) $
  test "Module complexity" (
    let mod : Module := {
      name := "Large"
      dependencies := []
      complexity := 1000
      sourcePath := "path"
    }
    mod.complexity == 1000)

-- SimpleGoal Tests

def simpleGoalTests : TestSeq :=
  test "SimpleGoal creation" (
    let goal : SimpleGoal := {
      mvarId := 12345
      userName := "h"
      goalType := SimpleExpr.const "Nat" []
      localContext := []
    }
    goal.userName == "h") $
  test "SimpleGoal with local context" (
    let localDecl : SimpleLocalDecl := {
      fvarId := 1
      userName := "x"
      localType := SimpleExpr.const "Nat" []
      value := none
      isLet := false
    }
    let goal : SimpleGoal := {
      mvarId := 1
      userName := "main"
      goalType := SimpleExpr.const "Prop" []
      localContext := [localDecl]
    }
    goal.localContext.length == 1) $
  test "SimpleLocalDecl let binding" (
    let decl : SimpleLocalDecl := {
      fvarId := 1
      userName := "y"
      localType := SimpleExpr.const "Nat" []
      value := some (SimpleExpr.const "5" [])
      isLet := true
    }
    decl.isLet && decl.value.isSome)

-- ProofSnapshot Tests

def proofSnapshotTests : TestSeq :=
  test "ProofSnapshot creation" (
    let snapshot : ProofSnapshot := {
      stepId := 1
      goals := []
      tactic := "intro h"
      parentStep := none
      timestamp := 1000
    }
    snapshot.tactic == "intro h") $
  test "ProofSnapshot with parent" (
    let snapshot : ProofSnapshot := {
      stepId := 2
      goals := []
      tactic := "apply h"
      parentStep := some 1
      timestamp := 1001
    }
    snapshot.parentStep == some 1) $
  test "ProofSnapshot with goals" (
    let goal : SimpleGoal := {
      mvarId := 1
      userName := "goal"
      goalType := SimpleExpr.const "P" []
      localContext := []
    }
    let snapshot : ProofSnapshot := {
      stepId := 1
      goals := [goal]
      tactic := "sorry"
      parentStep := none
      timestamp := 1000
    }
    snapshot.goals.length == 1)

-- TacticTraceEntry Tests

def tacticTraceEntryTests : TestSeq :=
  test "TacticTraceEntry success" (
    let entry : TacticTraceEntry := {
      stepId := 1
      tactic := "simp"
      durationMicros := 500
      success := true
      errorMsg := none
    }
    entry.success && entry.errorMsg.isNone) $
  test "TacticTraceEntry failure" (
    let entry : TacticTraceEntry := {
      stepId := 2
      tactic := "exact h"
      durationMicros := 100
      success := false
      errorMsg := some "type mismatch"
    }
    !entry.success && entry.errorMsg.isSome)

-- Key Generation Tests

def keyGenerationTests : TestSeq :=
  test "tacticKey format" (
    let key := tacticKey "prefix" 12345
    containsSubstr key "prefix" && containsSubstr key "tactic") $
  test "theoremConclusionKey format" (
    let key := theoremConclusionKey "thm" 67890
    containsSubstr key "thm" && containsSubstr key "concl") $
  test "declKey format" (
    let key := declKey "decl" "Nat.add"
    containsSubstr key "decl" && containsSubstr key "Nat.add") $
  test "instanceCacheKey format" (
    let key := instanceCacheKey "inst" 111 222
    containsSubstr key "inst" && containsSubstr key "111") $
  test "proofStepKey format" (
    let key := proofStepKey "proof" "session1" 5
    containsSubstr key "proof" && containsSubstr key "session1") $
  test "distLockKey format" (
    let key := distLockKey "dist" "Module.Name"
    containsSubstr key "dist" && containsSubstr key "Module.Name") $
  test "proofSessionKey format" (
    let key := proofSessionKey "pfx" "sess123"
    containsSubstr key "pfx" && containsSubstr key "sess123") $
  test "distJobsKey format" (
    let key := distJobsKey "pfx"
    containsSubstr key "pfx" && containsSubstr key "jobs")

-- Utility Function Tests

def utilityTests : TestSeq :=
  test "containsSubstr finds substring" (
    containsSubstr "hello world" "world") $
  test "containsSubstr returns false when not found" (
    not (containsSubstr "hello world" "foo")) $
  test "containsSubstr empty substring" (
    containsSubstr "hello" "") $
  test "containsSubstr at start" (
    containsSubstr "hello world" "hello") $
  test "containsSubstr at end" (
    containsSubstr "hello world" "world")

-- TheoremInfo Tests

def theoremInfoTests : TestSeq :=
  test "TheoremInfo creation" (
    let info : TheoremInfo := {
      name := "Nat.add_zero"
      moduleName := "Init.Nat"
      conclusion := TypePattern.const "Eq"
      hypotheses := [TypePattern.const "Nat"]
      docstring := some "n + 0 = n"
      tags := ["simp", "algebra"]
    }
    info.name == "Nat.add_zero") $
  test "TheoremInfo without docstring" (
    let info : TheoremInfo := {
      name := "lemma1"
      moduleName := "Module"
      conclusion := TypePattern.any
      hypotheses := []
      docstring := none
      tags := []
    }
    info.docstring.isNone) $
  test "TheoremInfo with tags" (
    let info : TheoremInfo := {
      name := "fun_ext"
      moduleName := "Logic.Function"
      conclusion := TypePattern.any
      hypotheses := []
      docstring := none
      tags := ["extensionality", "funext"]
    }
    info.tags.length == 2)

-- All Mathlib Tests
def allMathlibTests : TestSeq :=
  group "SimpleExpr" simpleExprTests $
  group "TypePattern" typePatternTests $
  group "TypePattern Matching" typePatternMatchingTests $
  group "CheckStatus" checkStatusTests $
  group "Module" moduleTests $
  group "SimpleGoal" simpleGoalTests $
  group "ProofSnapshot" proofSnapshotTests $
  group "TacticTraceEntry" tacticTraceEntryTests $
  group "Key Generation" keyGenerationTests $
  group "Utility Functions" utilityTests $
  group "TheoremInfo" theoremInfoTests

end RedisTests.MathlibTests
