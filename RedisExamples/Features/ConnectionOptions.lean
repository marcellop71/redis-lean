import RedisLean.FFI
import RedisLean.Log

namespace FeaturesConnectionOptionsExample

open Redis

/-!
# Connection Options Examples

Demonstrates connection configuration options:
- Connection timeouts
- Command timeouts
- TCP keepalive settings
- Unix socket connections

These features help build robust, production-ready Redis clients.
-/

/-- Example: Connect with timeout -/
def exConnectWithTimeout : IO Unit := do
  Log.info "Example: Connect with timeout"

  -- Connect with 5 second timeout
  let result ← (FFI.connectWithTimeout "127.0.0.1" 6379 5000).toBaseIO
  match result with
  | .ok ctx =>
    Log.info "  Connected successfully with 5s timeout"

    -- Test the connection
    let pingResult ← (FFI.ping ctx "test".toUTF8).toBaseIO
    match pingResult with
    | .ok _ => Log.info "  PING successful"
    | .error e => Log.error s!"  PING failed: {e}"

    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.error s!"  Connection failed: {e}"

/-- Example: Connect with short timeout (demonstrates timeout behavior) -/
def exShortTimeout : IO Unit := do
  Log.info "Example: Short timeout (may fail on slow networks)"

  -- Try to connect with a very short timeout (100ms)
  -- This might fail on slow networks or distant servers
  let result ← (FFI.connectWithTimeout "127.0.0.1" 6379 100).toBaseIO
  match result with
  | .ok ctx =>
    Log.info "  Connected with 100ms timeout"
    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.info s!"  Connection with 100ms timeout: {e}"
    Log.info "  (This is expected if server is slow to respond)"

/-- Example: Set command timeout on existing connection -/
def exCommandTimeout : IO Unit := do
  Log.info "Example: Command timeout on existing connection"

  let result ← (FFI.connectPlain "127.0.0.1" 6379).toBaseIO
  match result with
  | .ok ctx =>
    Log.info "  Connected"

    -- Set command timeout to 2 seconds
    let timeoutResult ← (FFI.setTimeout ctx 2000).toBaseIO
    match timeoutResult with
    | .ok _ => Log.info "  Set command timeout to 2000ms"
    | .error e => Log.error s!"  Failed to set timeout: {e}"

    -- Commands will now timeout after 2 seconds
    let pingResult ← (FFI.ping ctx "hello".toUTF8).toBaseIO
    match pingResult with
    | .ok _ => Log.info "  PING completed within timeout"
    | .error e => Log.error s!"  PING failed: {e}"

    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.error s!"  Connection failed: {e}"

/-- Example: Enable TCP keepalive -/
def exKeepAlive : IO Unit := do
  Log.info "Example: TCP keepalive settings"

  let result ← (FFI.connectPlain "127.0.0.1" 6379).toBaseIO
  match result with
  | .ok ctx =>
    Log.info "  Connected"

    -- Enable keepalive
    let keepaliveResult ← (FFI.enableKeepAlive ctx).toBaseIO
    match keepaliveResult with
    | .ok _ => Log.info "  Enabled TCP keepalive"
    | .error e => Log.error s!"  Failed to enable keepalive: {e}"

    -- Set keepalive interval to 60 seconds
    let intervalResult ← (FFI.setKeepAliveInterval ctx 60).toBaseIO
    match intervalResult with
    | .ok _ => Log.info "  Set keepalive interval to 60s"
    | .error e => Log.error s!"  Failed to set interval: {e}"

    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.error s!"  Connection failed: {e}"

/-- Example: Unix socket connection -/
def exUnixSocket : IO Unit := do
  Log.info "Example: Unix socket connection"

  -- Common Unix socket paths:
  -- - /var/run/redis/redis.sock
  -- - /tmp/redis.sock
  -- - /var/run/redis.sock

  let socketPath := "/var/run/redis/redis.sock"

  let result ← (FFI.connectUnix socketPath).toBaseIO
  match result with
  | .ok ctx =>
    Log.info s!"  Connected via Unix socket: {socketPath}"

    -- Unix sockets are faster for local connections
    let pingResult ← (FFI.ping ctx "fast".toUTF8).toBaseIO
    match pingResult with
    | .ok _ => Log.info "  PING successful (Unix socket is faster!)"
    | .error e => Log.error s!"  PING failed: {e}"

    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.info s!"  Unix socket connection skipped: {e}"
    Log.info "  To enable: set 'unixsocket' in redis.conf"

/-- Example: Unix socket with timeout -/
def exUnixSocketWithTimeout : IO Unit := do
  Log.info "Example: Unix socket with timeout"

  let socketPath := "/var/run/redis/redis.sock"

  let result ← (FFI.connectUnixWithTimeout socketPath 1000).toBaseIO
  match result with
  | .ok ctx =>
    Log.info "  Connected via Unix socket with 1s timeout"
    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.info s!"  Unix socket connection skipped: {e}"

/-- Example: Using withRedisUnix for auto-cleanup -/
def exWithRedisUnix : IO Unit := do
  Log.info "Example: Unix socket with auto-cleanup"

  let socketPath := "/var/run/redis/redis.sock"

  let result ← (FFI.withRedisUnix socketPath fun ctx => do
    let _ ← FFI.ping ctx "auto".toUTF8
    Log.EIO.info "  Connected and PING successful"
    -- Connection automatically freed when scope exits
    pure ()
  ).toBaseIO

  match result with
  | .ok _ => Log.info "  Connection auto-closed"
  | .error e => Log.info s!"  Unix socket connection skipped: {e}"

/-- Example: Production connection setup -/
def exProductionSetup : IO Unit := do
  Log.info "Example: Production-ready connection setup"

  -- Connect with reasonable timeout
  let result ← (FFI.connectWithTimeout "127.0.0.1" 6379 5000).toBaseIO
  match result with
  | .ok ctx =>
    Log.info "  Connected with 5s timeout"

    -- Set command timeout
    let _ ← (FFI.setTimeout ctx 3000).toBaseIO
    Log.info "  Command timeout: 3s"

    -- Enable keepalive for long-lived connections
    let _ ← (FFI.enableKeepAlive ctx).toBaseIO
    let _ ← (FFI.setKeepAliveInterval ctx 30).toBaseIO
    Log.info "  Keepalive: enabled (30s interval)"

    -- Verify connection works
    let pingResult ← (FFI.ping ctx "prod".toUTF8).toBaseIO
    match pingResult with
    | .ok _ => Log.info "  Connection verified with PING"
    | .error e => Log.error s!"  PING failed: {e}"

    let _ ← (FFI.free ctx).toBaseIO
  | .error e =>
    Log.error s!"  Production setup failed: {e}"

/-- Run all connection options examples -/
def runConnectionOptionsExamples : IO Unit := do
  let logOk ← Log.initZlog "config/zlog.conf" "connection-examples"
  if !logOk then
    IO.eprintln "Warning: Failed to initialize zlog"

  Log.info "=== Redis Connection Options Examples ==="

  exConnectWithTimeout
  exShortTimeout
  exCommandTimeout
  exKeepAlive
  exUnixSocket
  exUnixSocketWithTimeout
  exWithRedisUnix
  exProductionSetup

  Log.info "=== Connection Options Examples Complete ==="
  Log.finiZlog

end FeaturesConnectionOptionsExample
