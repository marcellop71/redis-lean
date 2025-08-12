import RedisLean.Codec
import RedisLean.Error
import RedisLean.Monad
import RedisLean.Ops
import RedisLean.Log

namespace Redis.Fixtures

/-- Generate a unique key with timestamp and random suffix for testing.
    Format: "{keyPrefix}:{timestamp_ns}:{random}" -/
def uniqueKey (keyPrefix : String) : IO String := do
  let timestamp ← IO.monoNanosNow
  let random ← IO.rand 0 999999
  return s!"{keyPrefix}:{timestamp}:{random}"

/-- Generate multiple unique keys with the same prefix -/
def uniqueKeys (keyPrefix : String) (count : Nat) : IO (List String) := do
  let mut keyList := []
  for _ in [:count] do
    let key ← uniqueKey keyPrefix
    keyList := key :: keyList
  return keyList.reverse

/-- Generate random bytes of specified length -/
def randomBytes (len : Nat) : IO ByteArray := do
  let mut bytes := ByteArray.empty
  for _ in [:len] do
    let byte ← IO.rand 0 255
    bytes := bytes.push (UInt8.ofNat byte)
  return bytes

/-- Generate a random string of specified length (alphanumeric) -/
def randomString (len : Nat) : IO String := do
  let chars := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".toList
  let mut result := ""
  for _ in [:len] do
    let idx ← IO.rand 0 (chars.length - 1)
    let c := chars[idx]!
    result := result ++ c.toString
  return result

/-- Generate a random integer within a range -/
def randomInt (min max : Int) : IO Int := do
  let range := (max - min).toNat + 1
  let r ← IO.rand 0 (range - 1)
  return min + Int.ofNat r

/-- Execute an action with test keys, ensuring cleanup afterwards.
    The keys are deleted even if the action throws an error. -/
def withTestKeys (keyList : List String) (action : RedisM α) : RedisM α := do
  try
    action
  finally
    let _ ← del keyList

/-- Execute an action with a single test key -/
def withTestKey (key : String) (action : RedisM α) : RedisM α :=
  withTestKeys [key] action

/-- Generate a unique test key and run action with cleanup -/
def withUniqueKey (keyPrefix : String) (action : String → RedisM α) : RedisM α := do
  let key ← uniqueKey keyPrefix
  withTestKey key (action key)

/-- Generate multiple unique test keys and run action with cleanup -/
def withUniqueKeys (keyPrefix : String) (count : Nat) (action : List String → RedisM α) : RedisM α := do
  let keyList ← uniqueKeys keyPrefix count
  withTestKeys keyList (action keyList)

/-- Test data generator for common types -/
structure TestData where
  stringValue : String
  intValue : Int
  bytesValue : ByteArray
  listValues : List String
  hashPairs : List (String × String)

/-- Generate random test data -/
def generateTestData : IO TestData := do
  let stringValue ← randomString 16
  let intValue ← randomInt (-1000) 1000
  let bytesValue ← randomBytes 32
  let listLen ← IO.rand 3 10
  let mut listValues := []
  for _ in [:listLen] do
    let s ← randomString 8
    listValues := s :: listValues
  let hashLen ← IO.rand 3 8
  let mut hashPairs := []
  for i in [:hashLen] do
    let field := s!"field{i}"
    let value ← randomString 12
    hashPairs := (field, value) :: hashPairs
  return {
    stringValue,
    intValue,
    bytesValue,
    listValues := listValues.reverse,
    hashPairs := hashPairs.reverse
  }

/-- Assert that two values are equal, throwing an error if not -/
def assertEqual [BEq α] [ToString α] (actual expected : α) (msg : String := "") : IO Unit := do
  if actual != expected then
    let errorMsg := if msg.isEmpty
      then s!"Assertion failed: expected {expected}, got {actual}"
      else s!"{msg}: expected {expected}, got {actual}"
    throw (IO.userError errorMsg)

/-- Assert that a condition is true -/
def assertTrue (condition : Bool) (msg : String := "Assertion failed") : IO Unit := do
  if !condition then
    throw (IO.userError msg)

/-- Assert that a condition is false -/
def assertFalse (condition : Bool) (msg : String := "Assertion failed: expected false") : IO Unit := do
  if condition then
    throw (IO.userError msg)

/-- Assert that an option is Some and return the value -/
def assertSome [ToString α] (opt : Option α) (msg : String := "Expected Some, got None") : IO α := do
  match opt with
  | some v => return v
  | none => throw (IO.userError msg)

/-- Assert that an option is None -/
def assertNone [ToString α] (opt : Option α) (msg : String := "Expected None, got Some") : IO Unit := do
  match opt with
  | some v => throw (IO.userError s!"{msg}: got {v}")
  | none => return ()

/-- Assert that a result is Ok and return the value -/
def assertOk (result : Except ε α) (msg : String := "Expected Ok, got Error") : IO α := do
  match result with
  | .ok v => return v
  | .error _ => throw (IO.userError msg)

/-- Assert that a result is Error -/
def assertError (result : Except ε α) (msg : String := "Expected Error, got Ok") : IO Unit := do
  match result with
  | .ok _ => throw (IO.userError msg)
  | .error _ => return ()

/-- Run a test with timing information -/
def timedTest (name : String) (test : IO Unit) : IO Unit := do
  let start ← IO.monoNanosNow
  try
    test
    let stop ← IO.monoNanosNow
    let durationMs := (stop - start) / 1000000
    Log.info s!"✓ {name} ({durationMs}ms)"
  catch e =>
    let stop ← IO.monoNanosNow
    let durationMs := (stop - start) / 1000000
    Log.error s!"✗ {name} ({durationMs}ms): {e}"
    throw e

/-- Test suite runner -/
structure TestSuite where
  name : String
  tests : List (String × IO Unit)

/-- Run a test suite and report results -/
def runTestSuite (suite : TestSuite) : IO Bool := do
  Log.info s!"\n=== {suite.name} ==="
  let mut passed := 0
  let mut failed := 0
  for (name, test) in suite.tests do
    try
      let _ ← timedTest name test
      passed := passed + 1
    catch _ =>
      failed := failed + 1
  Log.info s!"\nResults: {passed} passed, {failed} failed"
  return failed == 0

end Redis.Fixtures
