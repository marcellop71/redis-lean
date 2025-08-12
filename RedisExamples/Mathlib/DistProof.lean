import RedisLean.Mathlib
import RedisLean.Log
import RedisLean.Monad

namespace MathlibDistProofExample

open Redis Redis.Mathlib

/-!
# Distributed Proof Checking Example

Demonstrates coordinating parallel proof checking across multiple workers.
This is useful for:
- Parallelizing Mathlib compilation across machines
- Managing dependencies for incremental builds
- Tracking progress of large proof checking tasks
- Recovering from worker failures
-/

/-- Sample modules representing a simplified dependency graph -/
def sampleModules : List Module := [
  -- Base modules (no dependencies)
  { name := "Init.Prelude", dependencies := [], complexity := 10, sourcePath := "Init/Prelude.lean" },
  { name := "Init.Core", dependencies := ["Init.Prelude"], complexity := 15, sourcePath := "Init/Core.lean" },

  -- Data modules
  { name := "Data.Nat.Basic", dependencies := ["Init.Core"], complexity := 25, sourcePath := "Data/Nat/Basic.lean" },
  { name := "Data.Int.Basic", dependencies := ["Data.Nat.Basic"], complexity := 30, sourcePath := "Data/Int/Basic.lean" },
  { name := "Data.List.Basic", dependencies := ["Data.Nat.Basic"], complexity := 35, sourcePath := "Data/List/Basic.lean" },

  -- Algebra modules (depend on Data)
  { name := "Algebra.Group.Basic", dependencies := ["Data.Nat.Basic", "Data.Int.Basic"], complexity := 40, sourcePath := "Algebra/Group/Basic.lean" },
  { name := "Algebra.Ring.Basic", dependencies := ["Algebra.Group.Basic"], complexity := 45, sourcePath := "Algebra/Ring/Basic.lean" },

  -- Higher-level modules
  { name := "Analysis.Real", dependencies := ["Algebra.Ring.Basic", "Data.List.Basic"], complexity := 60, sourcePath := "Analysis/Real.lean" },
  { name := "Topology.Basic", dependencies := ["Analysis.Real"], complexity := 50, sourcePath := "Topology/Basic.lean" }
]

/-- Example: Initialize the job queue -/
def exInitializeJobs : RedisM Unit := do
  Log.info "Example: Initializing distributed proof checking"

  let config := DistProof.createConfig "example"

  -- Initialize the job queue with modules
  DistProof.initializeJobs config sampleModules
  Log.info s!"Initialized job queue with {sampleModules.length} modules"

  -- Show initial progress
  let progress ← DistProof.getProgress config
  Log.info s!"Initial state:"
  Log.info s!"  Total: {progress.totalModules}"
  Log.info s!"  Pending: {progress.pending}"
  Log.info s!"  In Progress: {progress.inProgress}"
  Log.info s!"  Completed: {progress.completed}"

/-- Example: Register workers -/
def exRegisterWorkers : RedisM Unit := do
  Log.info "Example: Registering workers"

  let config := DistProof.createConfig "example"
  let now ← nowSeconds

  -- Register multiple workers
  let workers : List Worker := [
    { workerId := "worker-1", host := "node1.cluster.local", startedAt := now, lastHeartbeat := now, claimedJobs := [] },
    { workerId := "worker-2", host := "node2.cluster.local", startedAt := now, lastHeartbeat := now, claimedJobs := [] },
    { workerId := "worker-3", host := "node3.cluster.local", startedAt := now, lastHeartbeat := now, claimedJobs := [] }
  ]

  for worker in workers do
    DistProof.registerWorker config worker
    Log.info s!"  Registered: {worker.workerId} on {worker.host}"

  -- List all workers
  let allWorkers ← DistProof.listWorkers config
  Log.info s!"Total workers registered: {allWorkers.length}"

/-- Example: Claim and process jobs -/
def exClaimAndProcess : RedisM Unit := do
  Log.info "Example: Claiming and processing jobs"

  let config := DistProof.createConfig "example"

  -- Worker 1 claims a job
  Log.info "Worker-1 attempting to claim a job..."
  match ← DistProof.claimJob config "worker-1" with
  | some job =>
    Log.info s!"  Claimed: {job.jobModule.name} (priority: {job.priority})"
    Log.info s!"  Dependencies: {job.jobModule.dependencies}"

    -- Simulate processing with progress updates
    Log.info "  Processing..."
    DistProof.updateProgress config job.jobId 25
    DistProof.updateProgress config job.jobId 50
    DistProof.updateProgress config job.jobId 75
    DistProof.updateProgress config job.jobId 100

    -- Complete the job
    DistProof.completeJob config job.jobId true
    Log.info s!"  Completed: {job.jobModule.name}"

  | none =>
    Log.info "  No jobs available (dependencies not satisfied)"

/-- Example: Check ready modules -/
def exCheckReadyModules : RedisM Unit := do
  Log.info "Example: Checking which modules are ready to build"

  let config := DistProof.createConfig "example"

  let ready ← DistProof.getReadyModules config
  Log.info s!"Modules with satisfied dependencies ({ready.length}):"
  for moduleName in ready do
    Log.info s!"  - {moduleName}"

/-- Example: Simulate multiple workers -/
def exSimulateWorkers : RedisM Unit := do
  Log.info "Example: Simulating distributed work"

  let config := DistProof.createConfig "example"

  -- Process modules in order (simulating multiple workers)
  for _ in [:sampleModules.length] do
    -- Worker 1 claims
    match ← DistProof.claimJob config "worker-1" with
    | some job =>
      Log.info s!"Processing: {job.jobModule.name}"
      -- Simulate work
      DistProof.completeJob config job.jobId true
    | none =>
      -- Try worker 2
      match ← DistProof.claimJob config "worker-2" with
      | some job =>
        Log.info s!"Processing: {job.jobModule.name}"
        DistProof.completeJob config job.jobId true
      | none =>
        Log.info "No more jobs available"
        break

  -- Show final progress
  let progress ← DistProof.getProgress config
  Log.info s!"Final state:"
  Log.info s!"  Completed: {progress.completed}/{progress.totalModules}"
  Log.info s!"  Failed: {progress.failed}"

/-- Example: Handle job failure -/
def exHandleFailure : RedisM Unit := do
  Log.info "Example: Handling job failures"

  let config := DistProof.createConfig "example"

  -- Re-initialize to have jobs
  DistProof.initializeJobs config sampleModules

  -- Claim a job
  match ← DistProof.claimJob config "worker-1" with
  | some job =>
    Log.info s!"Claimed: {job.jobModule.name}"

    -- Simulate failure
    DistProof.completeJob config job.jobId false (some "Type mismatch at line 42")
    Log.info s!"Marked as failed: {job.jobModule.name}"

    -- Check the job status
    let jobOpt ← DistProof.getJob config job.jobId
    match jobOpt with
    | some j =>
      match j.status with
      | .failed _ _ err => Log.info s!"  Error: {err}"
      | _ => Log.info "  Unexpected status"
    | none => Log.info "  Job not found"

  | none =>
    Log.info "No jobs available"

  let progress ← DistProof.getProgress config
  Log.info s!"Failed jobs: {progress.failed}"

/-- Example: Release and requeue jobs -/
def exReleaseJob : RedisM Unit := do
  Log.info "Example: Releasing jobs for requeue"

  let config := DistProof.createConfig "example"

  -- Re-initialize
  DistProof.initializeJobs config sampleModules

  -- Claim a job
  match ← DistProof.claimJob config "worker-1" with
  | some job =>
    Log.info s!"Claimed: {job.jobModule.name}"

    -- Worker needs to stop - release the job
    DistProof.releaseJob config job.jobId
    Log.info s!"Released: {job.jobModule.name} (available for another worker)"

    -- Verify it's back in the queue
    let ready ← DistProof.getReadyModules config
    let isReady := ready.any (· == job.jobId)
    Log.info s!"  Back in queue: {isReady}"

  | none =>
    Log.info "No jobs available"

/-- Example: Handle stale workers -/
def exHandleStaleWorkers : RedisM Unit := do
  Log.info "Example: Handling stale workers"

  let config : DistConfig := {
    keyPrefix := "example"
    staleThresholdSeconds := 1  -- Very short for demo
    maxRetries := 3
  }

  -- Re-initialize
  DistProof.initializeJobs config sampleModules

  -- Claim a job with worker-1
  match ← DistProof.claimJob config "worker-1" with
  | some job =>
    Log.info s!"Worker-1 claimed: {job.jobModule.name}"

    -- Simulate worker going stale (wait > staleThreshold)
    -- In real usage, this would be a worker crash
    IO.sleep 1500  -- Wait 1.5 seconds

    -- Check for stale claims
    let staleJobs ← DistProof.checkStaleClaims config
    Log.info s!"Stale jobs found: {staleJobs.length}"

    -- Requeue stale jobs
    let requeued ← DistProof.requeueStaleJobs config
    Log.info s!"Requeued {requeued} stale jobs"

  | none =>
    Log.info "No jobs available"

/-- Example: Worker cleanup -/
def exWorkerCleanup : RedisM Unit := do
  Log.info "Example: Cleaning up dead workers"

  let config : DistConfig := {
    keyPrefix := "example"
    staleThresholdSeconds := 1
  }

  -- Register a worker with old heartbeat
  let now ← nowSeconds
  let staleWorker : Worker := {
    workerId := "stale-worker"
    host := "dead-node.local"
    startedAt := now - 1000
    lastHeartbeat := now - 100  -- Very old
    claimedJobs := []
  }
  DistProof.registerWorker config staleWorker

  let workersBefore ← DistProof.listWorkers config
  Log.info s!"Workers before cleanup: {workersBefore.length}"

  -- Clean up dead workers
  let removed ← DistProof.cleanupDeadWorkers config
  Log.info s!"Removed {removed} dead workers"

  let workersAfter ← DistProof.listWorkers config
  Log.info s!"Workers after cleanup: {workersAfter.length}"

/-- Example: Monitor overall progress -/
def exMonitorProgress : RedisM Unit := do
  Log.info "Example: Monitoring build progress"

  let config := DistProof.createConfig "example"

  -- Re-initialize and process some
  DistProof.initializeJobs config sampleModules

  Log.info "Starting build monitoring..."

  for i in [:5] do
    -- Claim and complete a job if available
    match ← DistProof.claimJob config "worker-1" with
    | some job =>
      DistProof.completeJob config job.jobId true
    | none => pure ()

    -- Show progress
    let progress ← DistProof.getProgress config
    let pct := if progress.totalModules > 0
               then (progress.completed * 100) / progress.totalModules
               else 0
    Log.info s!"[{i+1}/5] Progress: {progress.completed}/{progress.totalModules} ({pct}%)"

/-- Run all distributed proof examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Distributed Proof Checking Examples ==="

  exInitializeJobs
  exRegisterWorkers
  exCheckReadyModules
  exClaimAndProcess
  exSimulateWorkers
  exHandleFailure
  exReleaseJob
  exHandleStaleWorkers
  exWorkerCleanup
  exMonitorProgress

  Log.info "=== Distributed Proof Checking Examples Complete ==="

end MathlibDistProofExample
