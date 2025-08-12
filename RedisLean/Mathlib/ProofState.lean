import RedisLean.Mathlib.Core

namespace Redis.Mathlib

/-!
# Proof State Snapshots for Time-Travel Debugging

Enables recording and replaying proof states during tactic-based
proof development, supporting debugging and analysis of proof construction.
-/

open Redis

/-- Simplified representation of a local declaration in a goal context -/
structure SimpleLocalDecl where
  /-- Free variable ID (hashed) -/
  fvarId : UInt64
  /-- User-visible name -/
  userName : String
  /-- Type of the local -/
  localType : SimpleExpr
  /-- Value (for let bindings) -/
  value : Option SimpleExpr
  /-- Whether this is a let binding -/
  isLet : Bool
  deriving Repr, BEq

instance : Lean.ToJson SimpleLocalDecl where
  toJson d := Lean.Json.mkObj [
    ("fvarId", Lean.toJson d.fvarId.toNat),
    ("userName", Lean.toJson d.userName),
    ("localType", Lean.toJson d.localType.toEncodedString),
    ("value", match d.value with
      | some v => Lean.toJson v.toEncodedString
      | none => Lean.Json.null),
    ("isLet", Lean.toJson d.isLet)
  ]

instance : Lean.FromJson SimpleLocalDecl where
  fromJson? j := do
    let fvarId ← j.getObjValAs? Nat "fvarId"
    let userName ← j.getObjValAs? String "userName"
    let typeStr ← j.getObjValAs? String "localType"
    let value := match j.getObjVal? "value" with
      | .ok (.str s) => some (SimpleExpr.other s)
      | _ => none
    let isLet ← j.getObjValAs? Bool "isLet"
    return {
      fvarId := UInt64.ofNat fvarId
      userName
      localType := .other typeStr
      value, isLet
    }

instance : Codec SimpleLocalDecl := jsonCodec

/-- Simplified representation of a proof goal -/
structure SimpleGoal where
  /-- Metavariable ID (hashed) -/
  mvarId : UInt64
  /-- User-visible name for the goal -/
  userName : String
  /-- Type (what needs to be proved) -/
  goalType : SimpleExpr
  /-- Local context (hypotheses available) -/
  localContext : List SimpleLocalDecl
  deriving Repr, BEq

instance : Lean.ToJson SimpleGoal where
  toJson g := Lean.Json.mkObj [
    ("mvarId", Lean.toJson g.mvarId.toNat),
    ("userName", Lean.toJson g.userName),
    ("goalType", Lean.toJson g.goalType.toEncodedString),
    ("localContext", Lean.toJson g.localContext)
  ]

instance : Lean.FromJson SimpleGoal where
  fromJson? j := do
    let mvarId ← j.getObjValAs? Nat "mvarId"
    let userName ← j.getObjValAs? String "userName"
    let typeStr ← j.getObjValAs? String "goalType"
    let localContext ← j.getObjValAs? (List SimpleLocalDecl) "localContext"
    return {
      mvarId := UInt64.ofNat mvarId
      userName
      goalType := .other typeStr
      localContext
    }

instance : Codec SimpleGoal := jsonCodec

/-- Snapshot of a proof state at a specific step -/
structure ProofSnapshot where
  /-- Step number in the proof -/
  stepId : Nat
  /-- Current goals -/
  goals : List SimpleGoal
  /-- Tactic that led to this state -/
  tactic : String
  /-- Parent step (for tree structure) -/
  parentStep : Option Nat
  /-- Timestamp when snapshot was taken -/
  timestamp : Nat
  deriving Repr, BEq

instance : Lean.ToJson ProofSnapshot where
  toJson s := Lean.Json.mkObj [
    ("stepId", Lean.toJson s.stepId),
    ("goals", Lean.toJson s.goals),
    ("tactic", Lean.toJson s.tactic),
    ("parentStep", match s.parentStep with
      | some p => Lean.toJson p
      | none => Lean.Json.null),
    ("timestamp", Lean.toJson s.timestamp)
  ]

instance : Lean.FromJson ProofSnapshot where
  fromJson? j := do
    let stepId ← j.getObjValAs? Nat "stepId"
    let goals ← j.getObjValAs? (List SimpleGoal) "goals"
    let tactic ← j.getObjValAs? String "tactic"
    let parentStep := match j.getObjVal? "parentStep" with
      | .ok (.num n) => some n.mantissa.toNat
      | _ => none
    let timestamp ← j.getObjValAs? Nat "timestamp"
    return { stepId, goals, tactic, parentStep, timestamp }

instance : Codec ProofSnapshot := jsonCodec

/-- Entry in the tactic execution trace -/
structure TacticTraceEntry where
  /-- Step ID -/
  stepId : Nat
  /-- Tactic text -/
  tactic : String
  /-- Execution time in microseconds -/
  durationMicros : Nat
  /-- Whether tactic succeeded -/
  success : Bool
  /-- Error message if failed -/
  errorMsg : Option String
  deriving Repr, BEq

instance : Lean.ToJson TacticTraceEntry where
  toJson e := Lean.Json.mkObj [
    ("stepId", Lean.toJson e.stepId),
    ("tactic", Lean.toJson e.tactic),
    ("durationMicros", Lean.toJson e.durationMicros),
    ("success", Lean.toJson e.success),
    ("errorMsg", match e.errorMsg with
      | some err => Lean.toJson err
      | none => Lean.Json.null)
  ]

instance : Lean.FromJson TacticTraceEntry where
  fromJson? j := do
    let stepId ← j.getObjValAs? Nat "stepId"
    let tactic ← j.getObjValAs? String "tactic"
    let durationMicros ← j.getObjValAs? Nat "durationMicros"
    let success ← j.getObjValAs? Bool "success"
    let errorMsg := match j.getObjVal? "errorMsg" with
      | .ok (.str s) => some s
      | _ => none
    return { stepId, tactic, durationMicros, success, errorMsg }

instance : Codec TacticTraceEntry := jsonCodec

/-- Active proof session -/
structure Session where
  /-- Unique session identifier -/
  sessionId : String
  /-- Theorem being proved -/
  theoremName : String
  /-- Initial goal type -/
  goalType : SimpleExpr
  /-- When session started -/
  startedAt : Nat
  /-- Current step count -/
  stepCount : Nat
  deriving Repr, BEq

instance : Lean.ToJson Session where
  toJson s := Lean.Json.mkObj [
    ("sessionId", Lean.toJson s.sessionId),
    ("theoremName", Lean.toJson s.theoremName),
    ("goalType", Lean.toJson s.goalType.toEncodedString),
    ("startedAt", Lean.toJson s.startedAt),
    ("stepCount", Lean.toJson s.stepCount)
  ]

instance : Lean.FromJson Session where
  fromJson? j := do
    let sessionId ← j.getObjValAs? String "sessionId"
    let theoremName ← j.getObjValAs? String "theoremName"
    let goalTypeStr ← j.getObjValAs? String "goalType"
    let startedAt ← j.getObjValAs? Nat "startedAt"
    let stepCount ← j.getObjValAs? Nat "stepCount"
    return {
      sessionId, theoremName
      goalType := .other goalTypeStr
      startedAt, stepCount
    }

instance : Codec Session := jsonCodec

/-- Configuration for proof state tracking -/
structure ProofStateConfig where
  /-- Key prefix -/
  keyPrefix : String := "mathlib"
  /-- TTL for sessions in seconds (0 = no expiry) -/
  sessionTtl : Nat := 86400  -- 24 hours
  /-- Maximum steps to retain per session -/
  maxSteps : Nat := 1000
  deriving Repr

namespace ProofState

/-- Create proof state config -/
def createConfig (kPrefix : String := "mathlib") (ttl : Nat := 86400) : ProofStateConfig :=
  { keyPrefix := kPrefix, sessionTtl := ttl }

/-- Start a new proof session -/
def startSession (config : ProofStateConfig) (theoremName : String)
    (goalType : SimpleExpr) : RedisM Session := do
  let sessionId ← generateId
  let startedAt ← nowSeconds

  let session : Session := {
    sessionId, theoremName, goalType, startedAt
    stepCount := 0
  }

  let sessionKey := proofSessionKey config.keyPrefix sessionId
  set sessionKey (Codec.enc session)

  if config.sessionTtl > 0 then
    let _ ← expire sessionKey config.sessionTtl

  -- Add to active sessions set
  let _ ← sadd s!"{config.keyPrefix}:proof:active" sessionId

  return session

/-- Record a proof step -/
def recordStep (config : ProofStateConfig) (session : Session)
    (snapshot : ProofSnapshot) : RedisM Unit := do
  let stepKey := proofStepKey config.keyPrefix session.sessionId snapshot.stepId
  set stepKey (Codec.enc snapshot)

  if config.sessionTtl > 0 then
    let _ ← expire stepKey config.sessionTtl

  -- Update session step count
  let sessionKey := proofSessionKey config.keyPrefix session.sessionId
  let updatedSession := { session with stepCount := snapshot.stepId + 1 }
  set sessionKey (Codec.enc updatedSession)

  -- Add step to session's step list (sorted set for ordering)
  let stepsKey := s!"{config.keyPrefix}:proof:steps:{session.sessionId}"
  let _ ← zadd stepsKey (Float.ofNat snapshot.stepId) s!"{snapshot.stepId}"

  if config.sessionTtl > 0 then
    let _ ← expire stepsKey config.sessionTtl

/-- Record a tactic trace entry -/
def recordTrace (config : ProofStateConfig) (session : Session)
    (entry : TacticTraceEntry) : RedisM Unit := do
  let traceKey := proofTraceKey config.keyPrefix session.sessionId
  let encoded := (Lean.toJson entry).compress
  let _ ← lpush traceKey [encoded]

  if config.sessionTtl > 0 then
    let _ ← expire traceKey config.sessionTtl

/-- Get a specific proof step -/
def getStep (config : ProofStateConfig) (sessionId : String) (stepId : Nat) : RedisM (Option ProofSnapshot) := do
  let stepKey := proofStepKey config.keyPrefix sessionId stepId
  let keyExists ← existsKey stepKey
  if !keyExists then return none
  let bs ← get stepKey
  match Codec.dec bs with
  | .ok s => return some s
  | .error _ => return none

/-- Get all steps for a session -/
def getAllSteps (config : ProofStateConfig) (sessionId : String) : RedisM (List ProofSnapshot) := do
  let stepsKey := s!"{config.keyPrefix}:proof:steps:{sessionId}"
  let stepNums ← zrange stepsKey 0 (-1)

  let mut snapshots : List ProofSnapshot := []
  for numBs in stepNums do
    match String.fromUTF8? numBs with
    | some numStr =>
      match numStr.toNat? with
      | some n =>
        match ← getStep config sessionId n with
        | some s => snapshots := s :: snapshots
        | none => pure ()
      | none => pure ()
    | none => pure ()

  return snapshots.reverse

/-- Get the tactic trace for a session -/
def getTrace (config : ProofStateConfig) (sessionId : String) : RedisM (List TacticTraceEntry) := do
  let traceKey := proofTraceKey config.keyPrefix sessionId
  let entries ← lrange traceKey 0 (-1)

  let mut trace : List TacticTraceEntry := []
  for bs in entries do
    match Codec.dec bs with
    | .ok e => trace := e :: trace
    | .error _ => pure ()

  return trace.reverse

/-- Get the parent step of a given step -/
def getParentStep (config : ProofStateConfig) (sessionId : String)
    (stepId : Nat) : RedisM (Option ProofSnapshot) := do
  match ← getStep config sessionId stepId with
  | some snapshot =>
    match snapshot.parentStep with
    | some parentId => getStep config sessionId parentId
    | none => return none
  | none => return none

/-- Get the path from root to a step (for backtracking) -/
def getPathToStep (config : ProofStateConfig) (sessionId : String)
    (stepId : Nat) : RedisM (List ProofSnapshot) := do
  let mut path : List ProofSnapshot := []
  let mut currentStep := stepId

  for _ in [:1000] do  -- Prevent infinite loops
    match ← getStep config sessionId currentStep with
    | some snapshot =>
      path := snapshot :: path
      match snapshot.parentStep with
      | some parentId => currentStep := parentId
      | none => break
    | none => break

  return path

/-- Load a session by ID -/
def getSession (config : ProofStateConfig) (sessionId : String) : RedisM (Option Session) := do
  let sessionKey := proofSessionKey config.keyPrefix sessionId
  let keyExists ← existsKey sessionKey
  if !keyExists then return none
  let bs ← get sessionKey
  match Codec.dec bs with
  | .ok s => return some s
  | .error _ => return none

/-- End a proof session -/
def endSession (config : ProofStateConfig) (session : Session)
    (success : Bool) : RedisM Unit := do
  -- Update session with completion status
  let sessionKey := proofSessionKey config.keyPrefix session.sessionId
  let _ ← hset sessionKey "completed" (String.toUTF8 (if success then "success" else "abandoned"))
  let nowSec ← nowSeconds
  let _ ← hset sessionKey "endedAt" (String.toUTF8 s!"{nowSec}")

  -- Move from active to completed
  let _ ← srem s!"{config.keyPrefix}:proof:active" [session.sessionId]
  let _ ← sadd s!"{config.keyPrefix}:proof:completed" session.sessionId

/-- List active sessions -/
def listActiveSessions (config : ProofStateConfig) : RedisM (List String) := do
  let active ← smembers s!"{config.keyPrefix}:proof:active"
  return active.filterMap String.fromUTF8?

/-- Delete a session and all its data -/
def deleteSession (config : ProofStateConfig) (sessionId : String) : RedisM Unit := do
  -- Get all step keys
  let stepsKey := s!"{config.keyPrefix}:proof:steps:{sessionId}"
  let stepNums ← zrange stepsKey 0 (-1)
  let stepKeys := stepNums.filterMap fun bs =>
    match String.fromUTF8? bs with
    | some numStr =>
      match numStr.toNat? with
      | some n => some (proofStepKey config.keyPrefix sessionId n)
      | none => none
    | none => none

  -- Delete everything
  let keysToDelete := [
    proofSessionKey config.keyPrefix sessionId,
    stepsKey,
    proofTraceKey config.keyPrefix sessionId
  ] ++ stepKeys

  let _ ← del keysToDelete

  -- Remove from sets
  let _ ← srem s!"{config.keyPrefix}:proof:active" [sessionId]
  let _ ← srem s!"{config.keyPrefix}:proof:completed" [sessionId]

/-- Get statistics about proof sessions -/
def getStatistics (config : ProofStateConfig) : RedisM (Nat × Nat) := do
  let activeCount ← scard s!"{config.keyPrefix}:proof:active"
  let completedCount ← scard s!"{config.keyPrefix}:proof:completed"
  return (activeCount, completedCount)

/-- Find the step where a specific goal was introduced -/
def findGoalIntroduction (config : ProofStateConfig) (sessionId : String)
    (goalMvarId : UInt64) : RedisM (Option ProofSnapshot) := do
  let steps ← getAllSteps config sessionId
  for step in steps do
    for goal in step.goals do
      if goal.mvarId == goalMvarId then
        return some step
  return none

/-- Compare two proof states (for debugging) -/
def diffSteps (_config : ProofStateConfig) (s1 s2 : ProofSnapshot) : String :=
  let goalDiff :=
    if s1.goals.length != s2.goals.length then
      s!"Goal count changed: {s1.goals.length} → {s2.goals.length}\n"
    else ""
  let tacticInfo := s!"Tactic: {s2.tactic}\n"
  goalDiff ++ tacticInfo

end ProofState

end Redis.Mathlib
