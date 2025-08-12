import RedisLean.Mathlib.Core

namespace Redis.Mathlib

/-!
# Distributed Proof Checking Coordination for Lean/Mathlib

Coordinates parallel proof checking across multiple worker processes,
managing job queues, dependency tracking, and progress reporting.
-/

open Redis

/-- Module to be checked -/
structure Module where
  /-- Module name -/
  name : String
  /-- Modules this depends on -/
  dependencies : List String
  /-- Relative complexity estimate -/
  complexity : Nat
  /-- Path to source file -/
  sourcePath : String
  deriving Repr, BEq

instance : Lean.ToJson Module where
  toJson m := Lean.Json.mkObj [
    ("name", Lean.toJson m.name),
    ("dependencies", Lean.toJson m.dependencies),
    ("complexity", Lean.toJson m.complexity),
    ("sourcePath", Lean.toJson m.sourcePath)
  ]

instance : Lean.FromJson Module where
  fromJson? j := do
    let name ← j.getObjValAs? String "name"
    let dependencies ← j.getObjValAs? (List String) "dependencies"
    let complexity ← j.getObjValAs? Nat "complexity"
    let sourcePath ← j.getObjValAs? String "sourcePath"
    return { name, dependencies, complexity, sourcePath }

instance : Codec Module := jsonCodec

/-- Status of a checking job -/
inductive CheckStatus where
  | pending
  | claimed (workerId : String) (claimedAt : Nat)
  | checking (workerId : String) (startedAt : Nat) (progress : Nat)
  | completed (workerId : String) (completedAt : Nat) (success : Bool)
  | failed (workerId : String) (failedAt : Nat) (errorMsg : String)
  deriving Repr, BEq

instance : Lean.ToJson CheckStatus where
  toJson
    | .pending => Lean.Json.mkObj [("status", "pending")]
    | .claimed workerId claimedAt => Lean.Json.mkObj [
        ("status", "claimed"),
        ("workerId", Lean.toJson workerId),
        ("claimedAt", Lean.toJson claimedAt)]
    | .checking workerId startedAt progress => Lean.Json.mkObj [
        ("status", "checking"),
        ("workerId", Lean.toJson workerId),
        ("startedAt", Lean.toJson startedAt),
        ("progress", Lean.toJson progress)]
    | .completed workerId completedAt success => Lean.Json.mkObj [
        ("status", "completed"),
        ("workerId", Lean.toJson workerId),
        ("completedAt", Lean.toJson completedAt),
        ("success", Lean.toJson success)]
    | .failed workerId failedAt errorMsg => Lean.Json.mkObj [
        ("status", "failed"),
        ("workerId", Lean.toJson workerId),
        ("failedAt", Lean.toJson failedAt),
        ("errorMsg", Lean.toJson errorMsg)]

instance : Lean.FromJson CheckStatus where
  fromJson? j := do
    let status ← j.getObjValAs? String "status"
    match status with
    | "pending" => return .pending
    | "claimed" =>
      let workerId ← j.getObjValAs? String "workerId"
      let claimedAt ← j.getObjValAs? Nat "claimedAt"
      return .claimed workerId claimedAt
    | "checking" =>
      let workerId ← j.getObjValAs? String "workerId"
      let startedAt ← j.getObjValAs? Nat "startedAt"
      let progress ← j.getObjValAs? Nat "progress"
      return .checking workerId startedAt progress
    | "completed" =>
      let workerId ← j.getObjValAs? String "workerId"
      let completedAt ← j.getObjValAs? Nat "completedAt"
      let success ← j.getObjValAs? Bool "success"
      return .completed workerId completedAt success
    | "failed" =>
      let workerId ← j.getObjValAs? String "workerId"
      let failedAt ← j.getObjValAs? Nat "failedAt"
      let errorMsg ← j.getObjValAs? String "errorMsg"
      return .failed workerId failedAt errorMsg
    | _ => throw s!"Unknown status: {status}"

instance : Codec CheckStatus := jsonCodec

/-- A checking job -/
structure Job where
  /-- Unique job identifier -/
  jobId : String
  /-- Module to check -/
  jobModule : Module
  /-- Current status -/
  status : CheckStatus
  /-- Priority (higher = more important) -/
  priority : Float
  /-- Retry count -/
  retries : Nat
  deriving Repr, BEq

instance : Lean.ToJson Job where
  toJson j := Lean.Json.mkObj [
    ("jobId", Lean.toJson j.jobId),
    ("jobModule", Lean.toJson j.jobModule),
    ("status", Lean.toJson j.status),
    ("priority", Lean.toJson j.priority),
    ("retries", Lean.toJson j.retries)
  ]

instance : Lean.FromJson Job where
  fromJson? j := do
    let jobId ← j.getObjValAs? String "jobId"
    let jobModule ← j.getObjValAs? Module "jobModule"
    let status ← j.getObjValAs? CheckStatus "status"
    let priority ← j.getObjValAs? Float "priority"
    let retries ← j.getObjValAs? Nat "retries"
    return { jobId, jobModule, status, priority, retries }

instance : Codec Job := jsonCodec

/-- Worker information -/
structure Worker where
  /-- Unique worker identifier -/
  workerId : String
  /-- Host running the worker -/
  host : String
  /-- When worker started -/
  startedAt : Nat
  /-- Last heartbeat timestamp -/
  lastHeartbeat : Nat
  /-- Currently claimed jobs -/
  claimedJobs : List String
  deriving Repr, BEq

instance : Lean.ToJson Worker where
  toJson w := Lean.Json.mkObj [
    ("workerId", Lean.toJson w.workerId),
    ("host", Lean.toJson w.host),
    ("startedAt", Lean.toJson w.startedAt),
    ("lastHeartbeat", Lean.toJson w.lastHeartbeat),
    ("claimedJobs", Lean.toJson w.claimedJobs)
  ]

instance : Lean.FromJson Worker where
  fromJson? j := do
    let workerId ← j.getObjValAs? String "workerId"
    let host ← j.getObjValAs? String "host"
    let startedAt ← j.getObjValAs? Nat "startedAt"
    let lastHeartbeat ← j.getObjValAs? Nat "lastHeartbeat"
    let claimedJobs ← j.getObjValAs? (List String) "claimedJobs"
    return { workerId, host, startedAt, lastHeartbeat, claimedJobs }

instance : Codec Worker := jsonCodec

/-- Overall progress tracking -/
structure Progress where
  /-- Total modules to check -/
  totalModules : Nat
  /-- Modules pending -/
  pending : Nat
  /-- Modules in progress -/
  inProgress : Nat
  /-- Modules completed successfully -/
  completed : Nat
  /-- Modules failed -/
  failed : Nat
  /-- Estimated time remaining in seconds -/
  etaSeconds : Option Nat
  deriving Repr, BEq

/-- Configuration for distributed checking -/
structure DistConfig where
  /-- Key prefix -/
  keyPrefix : String := "mathlib"
  /-- Lock timeout in seconds -/
  lockTimeoutSeconds : Nat := 300
  /-- Heartbeat interval in seconds -/
  heartbeatIntervalSeconds : Nat := 30
  /-- Stale claim threshold in seconds -/
  staleThresholdSeconds : Nat := 600
  /-- Maximum retries per job -/
  maxRetries : Nat := 3
  deriving Repr

namespace DistProof

/-- Create distributed proof config -/
def createConfig (kPrefix : String := "mathlib") : DistConfig :=
  { keyPrefix := kPrefix }

/-- Initialize the job queue with modules -/
def initializeJobs (config : DistConfig) (modules : List Module) : RedisM Unit := do
  -- Clear existing state
  let pattern := s!"{config.keyPrefix}:dist:*"
  let existing ← keys (α := String) (String.toUTF8 pattern)
  if !existing.isEmpty then
    let keyStrs := existing.filterMap String.fromUTF8?
    let _ ← del keyStrs

  -- Create jobs for each module
  for m in modules do
    let jobId := m.name  -- Use module name as job ID for simplicity
    let priority := 1000.0 - Float.ofNat m.complexity  -- Higher priority for simpler modules
    let job : Job := {
      jobId
      jobModule := m
      status := .pending
      priority
      retries := 0
    }

    -- Store job data
    let jobKey := distJobStatusKey config.keyPrefix jobId
    set jobKey (Codec.enc job)

    -- Add to pending queue (sorted by priority)
    let jobsKey := distJobsKey config.keyPrefix
    let _ ← zadd jobsKey priority jobId

    -- Store dependencies
    for dep in m.dependencies do
      let depsKey := s!"{config.keyPrefix}:dist:deps:{jobId}"
      let _ ← sadd depsKey dep

  -- Initialize progress counters
  let progressKey := distProgressKey config.keyPrefix
  let _ ← hset progressKey "total" (String.toUTF8 s!"{modules.length}")
  let _ ← hset progressKey "pending" (String.toUTF8 s!"{modules.length}")
  let _ ← hset progressKey "inProgress" (String.toUTF8 "0")
  let _ ← hset progressKey "completed" (String.toUTF8 "0")
  let _ ← hset progressKey "failed" (String.toUTF8 "0")

/-- Register a worker -/
def registerWorker (config : DistConfig) (worker : Worker) : RedisM Unit := do
  let workerKey := distWorkerKey config.keyPrefix worker.workerId
  set workerKey (Codec.enc worker)

  -- Add to active workers set
  let _ ← sadd s!"{config.keyPrefix}:dist:workers" worker.workerId

/-- Update worker heartbeat -/
def heartbeat (config : DistConfig) (workerId : String) : RedisM Unit := do
  let workerKey := distWorkerKey config.keyPrefix workerId
  let now ← nowSeconds
  let _ ← hset workerKey "lastHeartbeat" (String.toUTF8 s!"{now}")

/-- Check if a module's dependencies are satisfied -/
def dependenciesSatisfied (config : DistConfig) (jobId : String) : RedisM Bool := do
  let depsKey := s!"{config.keyPrefix}:dist:deps:{jobId}"
  let deps ← smembers depsKey
  let depNames := deps.filterMap String.fromUTF8?

  if depNames.isEmpty then return true

  -- Check if all dependencies are in completed set
  let completeKey := distCompleteKey config.keyPrefix
  for dep in depNames do
    let isComplete ← sismember completeKey dep
    if !isComplete then return false

  return true

/-- Claim a job (respects dependencies) -/
def claimJob (config : DistConfig) (workerId : String) : RedisM (Option Job) := do
  let jobsKey := distJobsKey config.keyPrefix
  let now ← nowSeconds

  -- Get all pending jobs sorted by priority
  let candidates ← zrevrange jobsKey 0 (-1)

  for candidateBs in candidates do
    match String.fromUTF8? candidateBs with
    | some jobId =>
      -- Check dependencies
      let depsOk ← dependenciesSatisfied config jobId
      if !depsOk then continue

      -- Try to acquire lock
      let lockKey := distLockKey config.keyPrefix jobId
      let _ ← setnx lockKey workerId

      -- Check if we got the lock by verifying the value
      let lockValue ← get lockKey
      match String.fromUTF8? lockValue with
      | some v =>
        if v != workerId then continue
      | none => continue

      -- Set lock expiry
      let _ ← expire lockKey config.lockTimeoutSeconds

      -- Load and update job
      let jobKey := distJobStatusKey config.keyPrefix jobId
      let jobExists ← existsKey jobKey
      if !jobExists then
        let _ ← del [lockKey]
        continue

      let bs ← get jobKey
      match Codec.dec (α := Job) bs with
      | .ok job =>
        -- Update job status
        let updatedJob := { job with status := .claimed workerId now }
        set jobKey (Codec.enc updatedJob)

        -- Update worker's claimed jobs
        let workerKey := distWorkerKey config.keyPrefix workerId
        let workerExists ← existsKey workerKey
        if workerExists then
          let wbs ← get workerKey
          match Codec.dec (α := Worker) wbs with
          | .ok worker =>
            let updatedWorker := { worker with
              claimedJobs := jobId :: worker.claimedJobs
              lastHeartbeat := now
            }
            set workerKey (Codec.enc updatedWorker)
          | .error _ => pure ()

        -- Update progress
        let progressKey := distProgressKey config.keyPrefix
        let _ ← hincrby progressKey "pending" (-1)
        let _ ← hincrby progressKey "inProgress" 1

        return some updatedJob

      | .error _ =>
        let _ ← del [lockKey]
        continue
    | none => continue

  return none

/-- Update job progress -/
def updateProgress (config : DistConfig) (jobId : String) (progress : Nat) : RedisM Unit := do
  let jobKey := distJobStatusKey config.keyPrefix jobId
  let jobExists ← existsKey jobKey
  if !jobExists then return

  let bs ← get jobKey
  match Codec.dec (α := Job) bs with
  | .ok job =>
    let now ← nowSeconds
    match job.status with
    | .claimed workerId _ =>
      let updatedJob := { job with status := .checking workerId now progress }
      set jobKey (Codec.enc updatedJob)
    | .checking workerId startedAt _ =>
      let updatedJob := { job with status := .checking workerId startedAt progress }
      set jobKey (Codec.enc updatedJob)
    | _ => pure ()
  | .error _ => pure ()

/-- Complete a job -/
def completeJob (config : DistConfig) (jobId : String) (success : Bool)
    (errorMsg : Option String := none) : RedisM Unit := do
  let jobKey := distJobStatusKey config.keyPrefix jobId
  let jobExists ← existsKey jobKey
  if !jobExists then return

  let bs ← get jobKey
  match Codec.dec (α := Job) bs with
  | .ok job =>
    let now ← nowSeconds
    let workerId := match job.status with
      | .claimed w _ | .checking w _ _ => w
      | _ => "unknown"

    let newStatus := if success then
      CheckStatus.completed workerId now true
    else
      match errorMsg with
      | some e => CheckStatus.failed workerId now e
      | none => CheckStatus.failed workerId now "Unknown error"

    let updatedJob := { job with status := newStatus }
    set jobKey (Codec.enc updatedJob)

    -- Release lock
    let lockKey := distLockKey config.keyPrefix jobId
    let _ ← del [lockKey]

    -- Update progress
    let progressKey := distProgressKey config.keyPrefix
    let _ ← hincrby progressKey "inProgress" (-1)
    if success then
      let _ ← hincrby progressKey "completed" 1
      -- Add to completed set
      let completeKey := distCompleteKey config.keyPrefix
      let _ ← sadd completeKey jobId
    else
      let _ ← hincrby progressKey "failed" 1

    -- Remove from jobs queue
    let jobsKey := distJobsKey config.keyPrefix
    let _ ← zrem jobsKey [jobId]

    -- Update worker's claimed jobs
    let workerKey := distWorkerKey config.keyPrefix workerId
    let workerExists ← existsKey workerKey
    if workerExists then
      let wbs ← get workerKey
      match Codec.dec (α := Worker) wbs with
      | .ok worker =>
        let updatedWorker := { worker with
          claimedJobs := worker.claimedJobs.filter (· != jobId)
        }
        set workerKey (Codec.enc updatedWorker)
      | .error _ => pure ()

  | .error _ => pure ()

/-- Release a job (for requeuing) -/
def releaseJob (config : DistConfig) (jobId : String) : RedisM Unit := do
  let jobKey := distJobStatusKey config.keyPrefix jobId
  let jobExists ← existsKey jobKey
  if !jobExists then return

  let bs ← get jobKey
  match Codec.dec (α := Job) bs with
  | .ok job =>
    let workerId := match job.status with
      | .claimed w _ | .checking w _ _ => some w
      | _ => none

    let updatedJob := { job with
      status := .pending
      retries := job.retries + 1
    }
    set jobKey (Codec.enc updatedJob)

    -- Re-add to jobs queue
    let jobsKey := distJobsKey config.keyPrefix
    let _ ← zadd jobsKey job.priority jobId

    -- Release lock
    let lockKey := distLockKey config.keyPrefix jobId
    let _ ← del [lockKey]

    -- Update progress
    let progressKey := distProgressKey config.keyPrefix
    let _ ← hincrby progressKey "inProgress" (-1)
    let _ ← hincrby progressKey "pending" 1

    -- Update worker
    if let some wId := workerId then
      let workerKey := distWorkerKey config.keyPrefix wId
      let workerExists ← existsKey workerKey
      if workerExists then
        let wbs ← get workerKey
        match Codec.dec (α := Worker) wbs with
        | .ok worker =>
          let updatedWorker := { worker with
            claimedJobs := worker.claimedJobs.filter (· != jobId)
          }
          set workerKey (Codec.enc updatedWorker)
        | .error _ => pure ()

  | .error _ => pure ()

/-- Get overall progress -/
def getProgress (config : DistConfig) : RedisM Progress := do
  let progressKey := distProgressKey config.keyPrefix
  let all ← hgetall progressKey

  let fields := parsePairs all

  let getField (name : String) : Nat :=
    fields.find? (·.1 == name) |>.map (·.2) |>.getD 0

  return {
    totalModules := getField "total"
    pending := getField "pending"
    inProgress := getField "inProgress"
    completed := getField "completed"
    failed := getField "failed"
    etaSeconds := none  -- Could compute based on historical data
  }
where
  parsePairs (bs : List ByteArray) : List (String × Nat) :=
    match bs with
    | k :: v :: rest =>
      match String.fromUTF8? k, String.fromUTF8? v with
      | some ks, some vs => (ks, vs.toNat?.getD 0) :: parsePairs rest
      | _, _ => parsePairs rest
    | _ => []

/-- Check for stale job claims (workers that stopped responding) -/
def checkStaleClaims (config : DistConfig) : RedisM (List Job) := do
  let now ← nowSeconds
  let threshold := now - config.staleThresholdSeconds

  let pattern := s!"{config.keyPrefix}:dist:job:*"
  let allKeys ← keys (α := String) (String.toUTF8 pattern)
  let keyStrs := allKeys.filterMap String.fromUTF8?

  let mut staleJobs : List Job := []
  for k in keyStrs do
    let jobExists ← existsKey k
    if jobExists then
      let bs ← get k
      match Codec.dec (α := Job) bs with
      | .ok job =>
        let isStale : Bool := match job.status with
          | .claimed _ claimedAt => claimedAt < threshold
          | .checking _ startedAt _ => startedAt < threshold
          | _ => false
        if isStale then staleJobs := job :: staleJobs
      | .error _ => pure ()

  return staleJobs

/-- Requeue stale jobs -/
def requeueStaleJobs (config : DistConfig) : RedisM Nat := do
  let staleJobs ← checkStaleClaims config
  for job in staleJobs do
    if job.retries < config.maxRetries then
      releaseJob config job.jobId
    else
      -- Mark as failed if max retries exceeded
      completeJob config job.jobId false (some "Max retries exceeded")
  return staleJobs.length

/-- Get modules that are ready to be checked (dependencies satisfied) -/
def getReadyModules (config : DistConfig) : RedisM (List String) := do
  let jobsKey := distJobsKey config.keyPrefix
  let candidates ← zrange jobsKey 0 (-1)

  let mut ready : List String := []
  for candidateBs in candidates do
    match String.fromUTF8? candidateBs with
    | some jobId =>
      let depsOk ← dependenciesSatisfied config jobId
      if depsOk then ready := jobId :: ready
    | none => pure ()

  return ready

/-- Get job by ID -/
def getJob (config : DistConfig) (jobId : String) : RedisM (Option Job) := do
  let jobKey := distJobStatusKey config.keyPrefix jobId
  let jobExists ← existsKey jobKey
  if !jobExists then return none
  let bs ← get jobKey
  match Codec.dec bs with
  | .ok j => return some j
  | .error _ => return none

/-- List all workers -/
def listWorkers (config : DistConfig) : RedisM (List Worker) := do
  let workerIds ← smembers s!"{config.keyPrefix}:dist:workers"
  let ids := workerIds.filterMap String.fromUTF8?

  let mut workers : List Worker := []
  for wId in ids do
    let workerKey := distWorkerKey config.keyPrefix wId
    let workerExists ← existsKey workerKey
    if workerExists then
      let bs ← get workerKey
      match Codec.dec (α := Worker) bs with
      | .ok w => workers := w :: workers
      | .error _ => pure ()

  return workers

/-- Remove a worker -/
def removeWorker (config : DistConfig) (workerId : String) : RedisM Unit := do
  let workerKey := distWorkerKey config.keyPrefix workerId
  let workerExists ← existsKey workerKey
  if workerExists then
    let bs ← get workerKey
    match Codec.dec (α := Worker) bs with
    | .ok worker =>
      -- Release all claimed jobs
      for jobId in worker.claimedJobs do
        releaseJob config jobId
    | .error _ => pure ()

  let _ ← del [workerKey]
  let _ ← srem s!"{config.keyPrefix}:dist:workers" [workerId]

/-- Clean up dead workers based on heartbeat -/
def cleanupDeadWorkers (config : DistConfig) : RedisM Nat := do
  let now ← nowSeconds
  let threshold := now - config.staleThresholdSeconds

  let workers ← listWorkers config
  let mut removed := 0

  for worker in workers do
    if worker.lastHeartbeat < threshold then
      removeWorker config worker.workerId
      removed := removed + 1

  return removed

end DistProof

end Redis.Mathlib
