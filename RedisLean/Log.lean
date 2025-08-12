/-
  RedisLean/Log.lean - Logging facade using zlog-lean
-/

import ZlogLean
import RedisLean.Error

namespace Redis

namespace Log

/-- Initialize zlog with config file and set default category -/
def initZlog (configPath : String := "config/zlog.conf") (category : String := "redis") : IO Bool := do
  let ok ← Zlog.init configPath
  if ok then
    let _ ← Zlog.Default.setCategory category
    return true
  else
    return false

/-- Cleanup zlog -/
def finiZlog : IO Unit := Zlog.fini

def trace (msg : String) : IO Unit := Zlog.debug msg

def debug (msg : String) : IO Unit := Zlog.debug msg

def info (msg : String) : IO Unit := Zlog.info msg

def warn (msg : String) : IO Unit := Zlog.warn msg

def error (msg : String) : IO Unit := Zlog.error msg

def fatal (msg : String) : IO Unit := Zlog.fatal msg

namespace EIO

-- Helper to lift IO into EIO
private def liftIO {ε α} (ioa : IO α) (handleError : IO.Error → ε) : EIO ε α :=
  IO.toEIO handleError ioa

def trace (msg : String) : EIO Error Unit :=
  liftIO (Log.trace msg) (fun e => Error.otherError (toString e))

def debug (msg : String) : EIO Error Unit :=
  liftIO (Log.debug msg) (fun e => Error.otherError (toString e))

def info (msg : String) : EIO Error Unit :=
  liftIO (Log.info msg) (fun e => Error.otherError (toString e))

def warn (msg : String) : EIO Error Unit :=
  liftIO (Log.warn msg) (fun e => Error.otherError (toString e))

def error (msg : String) : EIO Error Unit :=
  liftIO (Log.error msg) (fun e => Error.otherError (toString e))

def fatal (msg : String) : EIO Error Unit :=
  liftIO (Log.fatal msg) (fun e => Error.otherError (toString e))

end EIO

end Log

end Redis
