import RedisLean.Mathlib
import RedisLean.Log
import RedisLean.Monad

namespace MathlibProofStateExample

open Redis Redis.Mathlib

/-!
# Proof State Snapshots Example

Demonstrates time-travel debugging for proof development.
This is useful for:
- Recording proof state at each tactic step
- Navigating proof history (undo/redo across sessions)
- Debugging failed proof attempts
- Analyzing proof strategies
-/

/-- Example: Start a proof session -/
def exStartSession : RedisM Session := do
  Log.info "Example: Starting a proof session"

  let config := ProofState.createConfig "example" 3600  -- 1 hour TTL

  -- Start a new proof session for a theorem
  let goalType := SimpleExpr.forallE "n"
    (.const "Nat" [])
    (.forallE "m" (.const "Nat" []) (.app (.app (.const "Eq" []) (.const "Nat" [])) (.const "Nat.add" [])))

  let session ← ProofState.startSession config "Nat.add_comm_example" goalType
  Log.info s!"Started session: {session.sessionId}"
  Log.info s!"  Theorem: {session.theoremName}"
  Log.info s!"  Goal type: {session.goalType.toEncodedString}"

  return session

/-- Example: Record proof steps -/
def exRecordSteps (session : Session) : RedisM Unit := do
  Log.info "Example: Recording proof steps"

  let config := ProofState.createConfig "example" 3600

  -- Simulate a proof with multiple steps
  let natType : SimpleExpr := .const "Nat" []

  let localN : SimpleLocalDecl := {
    fvarId := 100, userName := "n", localType := natType, value := none, isLet := false
  }
  let localM : SimpleLocalDecl := {
    fvarId := 101, userName := "m", localType := natType, value := none, isLet := false
  }

  let goal0 : SimpleGoal := {
    mvarId := 1, userName := "goal1",
    goalType := .other "∀ m, n + m = m + n",
    localContext := [localN]
  }
  let goal1 : SimpleGoal := {
    mvarId := 2, userName := "goal1",
    goalType := .other "n + m = m + n",
    localContext := [localN, localM]
  }

  let steps : List (Nat × String × List SimpleGoal × Option Nat) := [
    (0, "intro n", [goal0], none),
    (1, "intro m", [goal1], some 0),
    (2, "induction m with | zero => rfl | succ m ih => simp [Nat.add_succ, ih]", [], some 1)
  ]

  for (stepId, tactic, goals, parent) in steps do
    let now ← nowSeconds
    let snapshot : ProofSnapshot := {
      stepId := stepId
      goals := goals
      tactic := tactic
      parentStep := parent
      timestamp := now
    }
    ProofState.recordStep config session snapshot
    Log.info s!"  Step {stepId}: {tactic}"
    Log.info s!"    Goals remaining: {goals.length}"

/-- Example: Record tactic trace -/
def exRecordTrace (session : Session) : RedisM Unit := do
  Log.info "Example: Recording tactic trace"

  let config := ProofState.createConfig "example" 3600

  -- Record timing information for each tactic
  let traceEntries : List TacticTraceEntry := [
    { stepId := 0, tactic := "intro n", durationMicros := 150, success := true, errorMsg := none },
    { stepId := 1, tactic := "intro m", durationMicros := 120, success := true, errorMsg := none },
    { stepId := 2, tactic := "induction m", durationMicros := 5000, success := true, errorMsg := none }
  ]

  for entry in traceEntries do
    ProofState.recordTrace config session entry
    Log.info s!"  Traced: {entry.tactic} ({entry.durationMicros}μs)"

/-- Example: Navigate proof history -/
def exNavigateHistory (sessionId : String) : RedisM Unit := do
  Log.info "Example: Navigating proof history"

  let config := ProofState.createConfig "example" 3600

  -- Get all steps
  let allSteps ← ProofState.getAllSteps config sessionId
  Log.info s!"Total steps in proof: {allSteps.length}"

  -- Get a specific step
  let step1 ← ProofState.getStep config sessionId 1
  match step1 with
  | some s =>
    Log.info s!"Step 1 details:"
    Log.info s!"  Tactic: {s.tactic}"
    Log.info s!"  Goals: {s.goals.length}"
    for goal in s.goals do
      Log.info s!"    - {goal.userName}: {goal.goalType.toEncodedString}"
      Log.info s!"      Context: {goal.localContext.length} local declarations"
  | none =>
    Log.info "Step 1 not found"

  -- Get parent step (for backtracking)
  let parent ← ProofState.getParentStep config sessionId 2
  match parent with
  | some p => Log.info s!"Parent of step 2: step {p.stepId} ({p.tactic})"
  | none => Log.info "Step 2 has no parent"

  -- Get path from root to a step
  let path ← ProofState.getPathToStep config sessionId 2
  Log.info s!"Path to step 2:"
  for step in path do
    Log.info s!"  {step.stepId}: {step.tactic}"

/-- Example: Get tactic trace -/
def exGetTrace (sessionId : String) : RedisM Unit := do
  Log.info "Example: Getting tactic trace"

  let config := ProofState.createConfig "example" 3600

  let trace ← ProofState.getTrace config sessionId
  Log.info s!"Tactic execution trace ({trace.length} entries):"

  let mut totalTime : Nat := 0
  for entry in trace do
    let status := if entry.success then "ok" else "FAILED"
    Log.info s!"  [{status}] {entry.tactic}: {entry.durationMicros}μs"
    totalTime := totalTime + entry.durationMicros

  Log.info s!"Total tactic time: {totalTime}μs"

/-- Example: Session management -/
def exSessionManagement : RedisM Unit := do
  Log.info "Example: Session management"

  let config := ProofState.createConfig "example" 3600

  -- List active sessions
  let activeSessions ← ProofState.listActiveSessions config
  Log.info s!"Active sessions: {activeSessions.length}"
  for sid in activeSessions do
    let sessionOpt ← ProofState.getSession config sid
    match sessionOpt with
    | some s => Log.info s!"  - {s.sessionId}: {s.theoremName} ({s.stepCount} steps)"
    | none => Log.info s!"  - {sid}: (session data not found)"

  -- Get statistics
  let (active, completed) ← ProofState.getStatistics config
  Log.info s!"Statistics: {active} active, {completed} completed"

/-- Example: End and cleanup session -/
def exEndSession (session : Session) : RedisM Unit := do
  Log.info "Example: Ending proof session"

  let config := ProofState.createConfig "example" 3600

  -- End session as successful
  ProofState.endSession config session true
  Log.info s!"Ended session {session.sessionId} as successful"

  -- Could also delete session to clean up
  -- ProofState.deleteSession config session.sessionId
  -- Log.info "Session data deleted"

/-- Example: Compare proof states -/
def exCompareStates : RedisM Unit := do
  Log.info "Example: Comparing proof states"

  let config := ProofState.createConfig "example" 3600

  -- Create two snapshots to compare
  let step1 : ProofSnapshot := {
    stepId := 0
    goals := [{ mvarId := 1, userName := "main", goalType := .const "True" [],
                localContext := [] }]
    tactic := "trivial"
    parentStep := none
    timestamp := 0
  }

  let step2 : ProofSnapshot := {
    stepId := 1
    goals := []  -- Proof complete
    tactic := "done"
    parentStep := some 0
    timestamp := 0
  }

  let diff := ProofState.diffSteps config step1 step2
  Log.info s!"Diff between steps:"
  Log.info diff

/-- Run all proof state examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Proof State Examples ==="

  -- Start a session and record steps
  let session ← exStartSession
  exRecordSteps session
  exRecordTrace session

  -- Navigate and analyze
  exNavigateHistory session.sessionId
  exGetTrace session.sessionId
  exSessionManagement
  exCompareStates

  -- End session
  exEndSession session

  Log.info "=== Proof State Examples Complete ==="

end MathlibProofStateExample
