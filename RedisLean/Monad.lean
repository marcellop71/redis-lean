import RedisLean.Metrics
import RedisLean.Error
import RedisLean.Config
import RedisLean.FFI
import RedisLean.Enums

namespace Redis

-- Configuration for Redis connections
structure Read where
  config : Config := Config.default
  enableMetrics : Bool := true
  deriving Repr

-- State maintained during Redis operations
structure State where
  ctx : FFI.Ctx
  isConnected : Bool := false
  metrics : Metrics
  recordLatency : String → Nat → IO Unit := fun _ _ => pure ()

abbrev RedisM := ReaderT Read $ StateRefT State $ ExceptT Error IO
abbrev StateRef := ST.Ref IO.RealWorld State

def getConfig : RedisM Config := do
  let r ← read
  return r.config

def getMetrics : RedisM Metrics := do
  let s ← get
  return s.metrics

def getState : RedisM State := get

def isConnected : RedisM Bool := do
  let s ← get
  return s.isConnected

def getContext : RedisM FFI.Ctx := do
  let s ← get
  return s.ctx

-- lift an EIO operation that uses the Redis context with latency recording
def liftRedisEIO {α}
  (cmd : RedisCmd) (f : FFI.Ctx → EIO Error α) : RedisM α := do
  let r ← read
  let s ← get
  if r.enableMetrics then
    let start ← IO.monoNanosNow
    try
      let result ← ExceptT.mk (EIO.toIO' (f s.ctx))
      let stop ← IO.monoNanosNow
      let micros := (stop - start) / 1000
      s.recordLatency (toString cmd) micros
      return result
    catch e =>
      let stop ← IO.monoNanosNow
      let micros := (stop - start) / 1000
      s.recordLatency (toString cmd) micros
      Metrics.recordError s.metrics (toString e)
      throw e
  else
    ExceptT.mk (EIO.toIO' (f s.ctx))

def connect (r : Read) : ExceptT Error IO State := do
  let ctxResult ← ExceptT.mk (EIO.toIO' (FFI.connect r.config.host (UInt32.ofNat r.config.port) r.config.ssl))
  let metrics ← Metrics.make
  if r.enableMetrics then
    Metrics.recordEvent metrics "connection_established"
    if r.config.ssl.isSome then
      Metrics.recordEvent metrics "ssl_connection"
  let s : State := {
    ctx := ctxResult,
    isConnected := true,
    metrics,
    recordLatency := fun cmd microseconds =>
      if r.enableMetrics then Metrics.recordLatency metrics cmd microseconds else pure ()
  }
  return s

def init (r : Read) : IO (Except Error StateRef) := do
  try
    let result ← ExceptT.run do
      let s ← connect r
      let sRef ← ST.mkRef s
      pure sRef
    pure result
  catch e =>
    pure <| Except.error <| Error.otherError s!"Failed to initialize Redis connection: {e}"

def runRedis {α : Type}
    (r : Read)
    (sRef : StateRef)
    (comp : RedisM α) : IO (Except Error α) := do
  ExceptT.run $ (comp.run r) sRef

def runRedisFromState
    (r : Read)
    (s : State)
    (comp : RedisM α) : IO (Except Error α) := do
  let sRef ← ST.mkRef s
  runRedis r sRef comp

def runRedisFromStateReturnsMetrics
    (r : Read)
    (s : State)
    (comp : RedisM α) : IO (Except Error α × Metrics) := do
  let sRef ← ST.mkRef s
  let result ← (comp.run r) sRef
  match result with
  | Except.ok value =>
    let finalState ← sRef.get
    return (Except.ok value, finalState.metrics)
  | Except.error e => return (Except.error e, s.metrics)

def runRedisNoState
    (r : Read)
    (comp : RedisM α) : IO (Except Error α) := do
  let result ← connect r |>.run
  match result with
  | Except.error e => return Except.error e
  | Except.ok s =>
    try
      runRedisFromState r s comp
    finally
      discard $ EIO.toIO (fun _ => IO.userError "Failed to free Redis context") (FFI.free s.ctx)

end Redis
