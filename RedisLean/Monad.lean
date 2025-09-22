import RedisLean.Metrics
import RedisLean.Error
import RedisLean.Config
import RedisLean.FFI
import RedisLean.Enums

namespace RedisLean

-- Configuration for Redis connections
structure RedisConfig where
  config : Config
  enableMetrics : Bool := true
  deriving Repr

-- State maintained during Redis operations
structure RedisState where
  ctx : FFI.Ctx
  isConnected : Bool := false
  metrics : Metrics
  recordLatency : String → Nat → IO Unit := fun _ _ => pure ()

abbrev RedisM := ReaderT RedisConfig $ StateRefT RedisState $ ExceptT RedisError IO
abbrev RedisStateRef := ST.Ref IO.RealWorld RedisState

def getConfig : RedisM Config := do
  let redisConfig ← read
  return redisConfig.config

def getMetrics : RedisM Metrics := do
  let redisState ← get
  return redisState.metrics

def getState : RedisM RedisState := get

def isConnected : RedisM Bool := do
  let redisState ← get
  return redisState.isConnected

def getContext : RedisM FFI.Ctx := do
  let redisState ← get
  return redisState.ctx

-- lift an EIO operation that uses the Redis context with latency recording
def liftRedisEIO {α}
  (cmd : RedisCmd) (f : FFI.Ctx → EIO RedisError α) : RedisM α := do
  let redisConfig ← read
  let redisState ← get
  if redisConfig.enableMetrics then
    let start ← IO.monoNanosNow
    try
      let result ← ExceptT.mk (EIO.toIO' (f redisState.ctx))
      let stop ← IO.monoNanosNow
      let micros := (stop - start) / 1000
      redisState.recordLatency (toString cmd) micros
      return result
    catch e =>
      let stop ← IO.monoNanosNow
      let micros := (stop - start) / 1000
      redisState.recordLatency (toString cmd) micros
      Metrics.recordError redisState.metrics (toString e)
      throw e
  else
    ExceptT.mk (EIO.toIO' (f redisState.ctx))

def connect (redisConfig : RedisConfig) : ExceptT RedisError IO RedisState := do
  let ctxResult ← ExceptT.mk (EIO.toIO' (FFI.hiredis.connect redisConfig.config.host (UInt32.ofNat redisConfig.config.port)))
  let metrics ← Metrics.make
  if redisConfig.enableMetrics then
    Metrics.recordEvent metrics "connection_established"
  let redisState : RedisState := {
    ctx := ctxResult,
    isConnected := true,
    metrics,
    recordLatency := fun cmd microseconds =>
      if redisConfig.enableMetrics then Metrics.recordLatency metrics cmd microseconds else pure ()
  }
  return redisState

def initWithConnect (redisConfig : RedisConfig) : IO (Except RedisError RedisStateRef) := do
  let result ← ExceptT.run do
    let redisState ← connect redisConfig
    let stateRef ← ST.mkRef redisState
    pure stateRef
  pure result

def runRedis {α : Type}
    (redisConfig : RedisConfig)
    (stateRef : RedisStateRef)
    (comp : RedisM α) : IO (Except RedisError α) := do
  ExceptT.run $ (comp.run redisConfig) stateRef

def runRedisFromState
    (redisConfig : RedisConfig)
    (redisState : RedisState)
    (comp : RedisM α) : IO (Except RedisError α) := do
  let stateRef ← ST.mkRef redisState
  runRedis redisConfig stateRef comp

def runRedisFromStateReturnsMetrics
    (redisConfig : RedisConfig)
    (redisState : RedisState)
    (comp : RedisM α) : IO (Except RedisError α × Metrics) := do
  let stateRef ← ST.mkRef redisState
  let result ← (comp.run redisConfig) stateRef
  match result with
  | Except.ok value =>
    let finalState ← stateRef.get
    return (Except.ok value, finalState.metrics)
  | Except.error e => return (Except.error e, redisState.metrics)

def runRedisNoState
    (redisConfig : RedisConfig)
    (comp : RedisM α) : IO (Except RedisError α) := do
  let result ← connect redisConfig |>.run
  match result with
  | Except.error e => return Except.error e
  | Except.ok redisState =>
    try
      runRedisFromState redisConfig redisState comp
    finally
      discard $ EIO.toIO (fun _ => IO.userError "Failed to free Redis context") (FFI.hiredis.free redisState.ctx)

end RedisLean
