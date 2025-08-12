import RedisLean.Metrics
import RedisLean.Error
import RedisLean.Config
import RedisLean.FFI
import RedisLean.Enums

namespace RedisLean

-- enhanced Redis environment with ctx, config, and metrics
structure Env where
  ctx : FFI.Ctx
  config : Config
  metrics : Metrics
  enableMetrics : Bool := true
  recordLatency : String → Nat → IO Unit := fun _ _ => pure ()

namespace Env

def make (ctx : FFI.Ctx) (config : Config) (metrics : Metrics) (enableMetrics : Bool := true) : Env :=
  { ctx, config, metrics, enableMetrics
  , recordLatency := fun cmd microseconds =>
      if enableMetrics then Metrics.recordLatency metrics cmd microseconds else pure () }

end Env

-- Redis monad transformer
-- Redis α is the type of a computation that can fail with a RedisError and return a value of type α
-- even though `EIO RedisError α` is definitionally `ExceptT RedisError IO α`
-- Lean doesn’t coerce it automatically, so we need to define an explicit conversion eioToExceptT
abbrev RedisT (m : Type → Type) := ReaderT Env (ExceptT RedisError m)
abbrev Result (α : Type) := Except RedisError α
abbrev Redis (α : Type) := RedisT IO α

-- ...existing code...
def getConfig : Redis Config := do
  let env ← read
  return env.config

def getMetrics : Redis Metrics := do
  let env ← read
  return env.metrics

-- lift an EIO operation that uses the Redis context with latency recording
def liftRedisEIO {α}
  (cmd : RedisCmd) (f : FFI.Ctx → EIO RedisError α) : Redis α :=
  fun env => do
    if env.enableMetrics then
      let start ← IO.monoNanosNow
      try
        let result ← ExceptT.mk (EIO.toIO' (f env.ctx))
        let stop ← IO.monoNanosNow
        let micros := (stop - start) / 1000
        Metrics.recordLatency env.metrics (toString cmd) micros
        return result
      catch e =>
        let stop ← IO.monoNanosNow
        let micros := (stop - start) / 1000
        Metrics.recordLatency env.metrics (toString cmd) micros
        Metrics.recordError env.metrics (toString e)
        throw e
    else
      ExceptT.mk (EIO.toIO' (f env.ctx))

-- connect to Redis with given configuration and create environment
def connect (config : Config := {}) (enableMetrics : Bool := true) : IO Env := do
  let ctxResult ← EIO.toIO (fun e => IO.userError (toString e)) (FFI.hiredis.connect config.host (UInt32.ofNat config.port))
  let metrics ← Metrics.make
  if enableMetrics then
    Metrics.recordEvent metrics "connection_established"
  return Env.make ctxResult config metrics enableMetrics

-- run a Redis computation with automatic connection management (no metrics)
def runRedis (config : Config := {}) (comp : Redis α) : IO (Result α) := do
  let env ← connect config false
  try
    (comp.run env).run
  finally
    discard $ EIO.toIO (fun _ => IO.userError "Failed to free Redis context") (FFI.hiredis.free env.ctx)

-- run a Redis computation with an existing environment
def runRedisWithEnv (env : Env) (comp : Redis α) : IO (Result α) :=
  (comp.run env).run

-- run a Redis computation and return both result and metrics
def runRedisWithMetrics (config : Config := {}) (comp : Redis α) : IO (Result α × Metrics) := do
  let env ← connect config true
  try
    let result ← (comp.run env).run
    return (result, env.metrics)
  finally
    Metrics.recordEvent env.metrics "connection_closed"
    discard $ EIO.toIO (fun _ => IO.userError "Failed to free Redis context") (FFI.hiredis.free env.ctx)

end RedisLean
