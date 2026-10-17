import RedisLean

/-!
Authentication test: `Config.username` / `Config.password`.

Run with `RedisTests/run-auth-test.sh`, which starts a throwaway redis-server with
`requirepass defaultpw` and two ACL users (`alice` with full access, `reader` limited
to GET). Never touches another Redis.
-/

open Redis

def base : Config := { port := 6394 }

initialize failures : IO.Ref Nat ← IO.mkRef 0

def check (name : String) (ok : Bool) (detail : String := "") : IO Unit := do
  IO.println s!"  {if ok then "✓" else "✗"} {name}{if ok || detail.isEmpty then "" else s!": {detail}"}"
  unless ok do failures.modify (· + 1)

/-- Run a command string, returning its reply text or the error -/
def cmd (ctx : FFI.Ctx) (c : String) : IO (Except String String) := do
  match ← (FFI.command ctx c).toBaseIO with
  | .ok b => pure (.ok (String.fromUTF8! b))
  | .error e => pure (.error (toString e))

def connect (cfg : Config) : IO (Except String FFI.Ctx) := do
  match ← (FFI.connectConfig cfg).toBaseIO with
  | .ok ctx => pure (.ok ctx)
  | .error e => pure (.error (toString e))

def isErrWith (r : Except String α) (needle : String) : Bool :=
  match r with
  | .error e => (e.splitOn needle).length > 1
  | .ok _ => false

def main : IO UInt32 := do
  IO.println "Redis authentication"
  -- No credentials: connecting works, commands are refused
  match ← connect base with
  | .error e => check "connect without credentials" false e
  | .ok ctx =>
    let r ← cmd ctx "GET k"
    check "no credentials: commands refused (NOAUTH)" (isErrWith r "NOAUTH") (repr r |>.pretty)
  -- Password only: the default user (requirepass)
  match ← connect (base.withAuth "defaultpw") with
  | .error e => check "password only" false e
  | .ok ctx =>
    let r ← cmd ctx "ACL WHOAMI"
    check "password only logs in as default" (r.toOption == some "default") (repr r |>.pretty)
  -- ACL user
  match ← connect (base.withAuth "alicepw" (some "alice")) with
  | .error e => check "username + password" false e
  | .ok ctx =>
    let r ← cmd ctx "ACL WHOAMI"
    check "username + password logs in as that user" (r.toOption == some "alice") (repr r |>.pretty)
    -- reconnect: hiredis' reconnect alone comes back unauthenticated; reconnectConfig logs in again
    let _ ← cmd ctx "CLIENT KILL USER alice SKIPME no"
    let _ ← (FFI.reconnect ctx).toBaseIO
    let plain ← cmd ctx "ACL WHOAMI"
    check "plain reconnect is unauthenticated (why reconnectConfig exists)" (isErrWith plain "NOAUTH") (repr plain |>.pretty)
    match ← (FFI.reconnectConfig ctx (base.withAuth "alicepw" (some "alice"))).toBaseIO with
    | .error e => check "reconnectConfig" false (toString e)
    | .ok () =>
      let r ← cmd ctx "ACL WHOAMI"
      check "reconnectConfig logs in again" (r.toOption == some "alice") (repr r |>.pretty)
  -- Limited user: its ACL applies
  match ← connect (base.withAuth "readerpw" (some "reader")) with
  | .error e => check "limited user" false e
  | .ok ctx =>
    let r ← cmd ctx "SET k v"
    check "limited user is limited (NOPERM)" (isErrWith r "NOPERM") (repr r |>.pretty)
  -- Rejected credentials fail the connect (and do not leak the socket)
  let wrong ← connect (base.withAuth "nope" (some "alice"))
  check "wrong password: connect fails (WRONGPASS)" (isErrWith wrong "WRONGPASS")
  let unknown ← connect (base.withAuth "x" (some "mallory"))
  check "unknown user: connect fails (WRONGPASS)" (isErrWith unknown "WRONGPASS")
  -- Database selection still applies after AUTH
  match ← connect ({ base.withAuth "alicepw" (some "alice") with database := 3 }) with
  | .error e => check "auth + database" false e
  | .ok ctx =>
    let _ ← cmd ctx "SET dbtest three"
    let r ← cmd ctx "CLIENT INFO"
    check "auth + database: SELECT applied" (match r with | .ok s => (s.splitOn " db=3 ").length > 1 | _ => false) (repr r |>.pretty)
  -- Pool connections log in
  let pool ← Pool.create (base.withAuth "alicepw" (some "alice")) { minConnections := 1, maxConnections := 2 }
  let r ← pool.withConnection (do let ctx ← getContext; ExceptT.mk (EIO.toIO' (FFI.command ctx "ACL WHOAMI")))
  check "pool connections log in" (match r with | .ok b => String.fromUTF8! b == "alice" | _ => false)
  -- The password never shows in Repr
  let shown := (repr (base.withAuth "s3cret" (some "alice"))).pretty
  check "Repr masks the password" ((shown.splitOn "s3cret").length == 1 && (shown.splitOn "alice").length > 1) shown
  let n ← failures.get
  IO.println (if n == 0 then "All authentication checks passed." else s!"{n} check(s) FAILED")
  return if n == 0 then 0 else 1
