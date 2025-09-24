import Init.System.IO
import Init.System.FilePath
import Std.Time
import RedisLean.Error

namespace Redis

namespace Log

inductive Level where
  | Trace
  | Debug
  | Info
  | Warn
  | Error
  | Fatal
deriving Repr, BEq, Ord

instance : ToString Level where
  toString
  | .Trace => "TRACE"
  | .Debug => "DEBUG"
  | .Info  => "INFO"
  | .Warn  => "WARN"
  | .Error => "ERROR"
  | .Fatal => "FATAL"

instance : LE Level := leOfOrd

/-- ANSI color codes for log levels -/
inductive ANSIColor where
  | White
  | Cyan
  | Green
  | Yellow
  | Red
  | Magenta
  | Reset

def ANSIColor.toTerminal : ANSIColor → String
  | .White   => "\x1b[37m"
  | .Cyan    => "\x1b[36m"
  | .Green   => "\x1b[32m"
  | .Yellow  => "\x1b[33m"
  | .Red     => "\x1b[31m"
  | .Magenta => "\x1b[35m"
  | .Reset   => "\x1b[0m"

/-- Associate Level with ANSI color codes for terminal output -/
def Level.toANSIColor : Level → ANSIColor
  | .Trace => .White
  | .Debug => .Cyan
  | .Info  => .Green
  | .Warn  => .Yellow
  | .Error => .Red
  | .Fatal => .Magenta

structure LogEntry where
  level : Level
  msg : String
  timestamp : Std.Time.PlainDateTime

/-- Logger configuration -/
structure LogConfig where
  minLevel : Level := Level.Trace
  toStdout : Bool := true
  file? : Option System.FilePath := none
  -- jsonOutput : Bool := false
  -- deriving Inhabited

def defaultLogConfig : LogConfig := {}

/-- Logger function type - takes a LogEntry and performs the actual logging -/
abbrev Logger := LogEntry → IO Unit

def getCurrentTimestamp : IO Std.Time.PlainDateTime := do
  let now ← Std.Time.PlainDateTime.now
  pure now

/-- LoggerT monad transformer - just ReaderT Logger -/
abbrev LoggerT (m : Type → Type) := ReaderT Logger m

/-- Logger monad (LoggerT IO) -/
abbrev LoggerM := LoggerT IO

namespace LoggerT

variable {m : Type → Type} [Monad m] {α β : Type}

/-- Run a LoggerT computation with a specific logger function -/
def runLoggerT (action : LoggerT m α) (logger : Logger) : m α :=
  action.run logger

/-- Log a message at a specific level -/
def logWith (level : Level) (msg : String) [MonadLift IO m] : LoggerT m Unit := do
  let logger ← read
  let timestamp ← liftM (getCurrentTimestamp)
  liftM (logger { level, msg, timestamp })

/-- Lift a computation from the underlying monad -/
def lift (action : m α) : LoggerT m α :=
  liftM action

end LoggerT

-- Utility functions for creating timestamps and formatting

/-- Check if a log level should be printed -/
def shouldLog (level : Level) (config : LogConfig) : Bool :=
  level >= config.minLevel

/-- Format a PlainDateTime with microsecond precision -/
def formatTimestampMicros (dt : Std.Time.PlainDateTime) : String :=
  let s := toString dt
  let chars := s.toList
  match chars.findIdx? (· == '.') with
  | none => s
  | some dotIndex =>
    let beforeDot := chars.take (dotIndex + 1)
    let afterDot := chars.drop (dotIndex + 1)
    if afterDot.length >= 6 then
      String.mk (beforeDot ++ afterDot.take 6)
    else
      s

/-- Format a log entry according to configuration -/
def formatLogEntry (entry : LogEntry) (_config : LogConfig) : IO String := do
  let mut parts : List String := []

  let timestamp := s!"[{formatTimestampMicros entry.timestamp}]"
  parts := timestamp :: parts

  let levelStr := s!"{entry.level.toANSIColor.toTerminal}[{toString entry.level}]{ANSIColor.Reset.toTerminal}"
  parts := levelStr :: parts

  parts := entry.msg :: parts

  return String.intercalate " " parts.reverse

/-- Create a standard IO logger with configuration -/
def mkIOLogger (config : LogConfig := defaultLogConfig) : Logger :=
  fun entry => do
    if shouldLog entry.level config then
      let formatted ← formatLogEntry entry config
      IO.println formatted

/-- Create a logger that writes to a specific handle -/
def mkHandleLogger (handle : IO.FS.Handle) (config : LogConfig := defaultLogConfig) : Logger :=
  fun entry => do
    if shouldLog entry.level config then
      let formatted ← formatLogEntry entry config
      handle.putStrLn formatted

/-- Create a logger that collects messages into a list (for testing) -/
def mkCollectingLogger (ref : IO.Ref (List LogEntry)) : Logger :=
  fun entry => do
    let current ← ref.get
    ref.set (entry :: current)

-- Convenience logging functions

variable {m : Type → Type} [Monad m] [MonadLift IO m]

def logTrace (msg : String) : LoggerT m Unit :=
  LoggerT.logWith Level.Trace msg

def logDebug (msg : String) : LoggerT m Unit :=
  LoggerT.logWith Level.Debug msg

def logInfo (msg : String) : LoggerT m Unit :=
  LoggerT.logWith Level.Info msg

def logWarn (msg : String) : LoggerT m Unit :=
  LoggerT.logWith Level.Warn msg

def logError (msg : String) : LoggerT m Unit :=
  LoggerT.logWith Level.Error msg

def logFatal (msg : String) : LoggerT m Unit :=
  LoggerT.logWith Level.Fatal msg

-- Higher-level convenience functions

/-- Log the execution of an action with trace level -/
def traceExecution {α : Type} [ToString α] (name : String) (action : LoggerT m α) : LoggerT m α := do
  logTrace s!"Starting {name}"
  let result ← action
  logTrace s!"Completed {name}: {result}"
  return result

/-- Log the execution of an action with debug level -/
def debugExecution {α : Type} [ToString α] (name : String) (action : LoggerT m α) : LoggerT m α := do
  logDebug s!"Executing {name}"
  let result ← action
  logDebug s!"Finished {name}: {result}"
  return result

/-- Log an error and return a default value -/
def logErrorAndReturn {α ε : Type} [ToString ε] (err : ε) (defaultValue : α) : LoggerT m α := do
  logError s!"Error occurred: {err}"
  return defaultValue

/-- Map over the logger function -/
def mapLogger {α : Type} (f : Logger → Logger) (action : LoggerT m α) : LoggerT m α :=
  fun env => action.run (f env)

/-- Add a prefix to all log messages -/
def logWithPrefix {α : Type} : String → LoggerT m α → LoggerT m α :=
  fun pre action => mapLogger (fun logger => fun entry => logger { entry with msg := s!"{pre}: {entry.msg}" }) action

/-- Filter logs by minimum level -/
def withMinLevel {α : Type} (minLevel : Level) (action : LoggerT m α) : LoggerT m α :=
  mapLogger (fun logger => fun entry =>
    if entry.level >= minLevel then logger entry else pure ()) action

-- Simple IO-based convenience functions (for backwards compatibility)

/-- Initialize development logging (for backward compatibility) -/
def initDevelopment : IO Unit :=
  pure () -- Previously this might have set global state, now it's a no-op

/-- Simple trace logging to stdout -/
def trace (msg : String) : IO Unit := do
  let logger := mkIOLogger
  let timestamp ← getCurrentTimestamp
  logger { level := Level.Trace, msg, timestamp }

/-- Simple debug logging to stdout -/
def debug (msg : String) : IO Unit := do
  let logger := mkIOLogger
  let timestamp ← getCurrentTimestamp
  logger { level := Level.Debug, msg, timestamp }

/-- Simple info logging to stdout -/
def info (msg : String) : IO Unit := do
  let logger := mkIOLogger
  let timestamp ← getCurrentTimestamp
  logger { level := Level.Info, msg, timestamp }

/-- Simple warn logging to stdout -/
def warn (msg : String) : IO Unit := do
  let logger := mkIOLogger
  let timestamp ← getCurrentTimestamp
  logger { level := Level.Warn, msg, timestamp }

/-- Simple error logging to stdout -/
def error (msg : String) : IO Unit := do
  let logger := mkIOLogger
  let timestamp ← getCurrentTimestamp
  logger { level := Level.Error, msg, timestamp }

/-- Simple fatal logging to stdout -/
def fatal (msg : String) : IO Unit := do
  let logger := mkIOLogger
  let timestamp ← getCurrentTimestamp
  logger { level := Level.Fatal, msg, timestamp }

namespace EIO

-- Helper to lift IO into EIO
private def liftIO {ε α} (ioa : IO α) (handleError : IO.Error → ε) : EIO ε α :=
  IO.toEIO handleError ioa

def trace (msg : String) : EIO RedisError Unit :=
  liftIO (Log.trace msg) (fun e => RedisError.otherError (toString e))

def debug (msg : String) : EIO RedisError Unit :=
  liftIO (Log.debug msg) (fun e => RedisError.otherError (toString e))

def info (msg : String) : EIO RedisError Unit :=
  liftIO (Log.info msg) (fun e => RedisError.otherError (toString e))

def warn (msg : String) : EIO RedisError Unit :=
  liftIO (Log.warn msg) (fun e => RedisError.otherError (toString e))

def error (msg : String) : EIO RedisError Unit :=
  liftIO (Log.error msg) (fun e => RedisError.otherError (toString e))

def fatal (msg : String) : EIO RedisError Unit :=
  liftIO (Log.fatal msg) (fun e => RedisError.otherError (toString e))

end EIO

end Log

end Redis
