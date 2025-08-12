import LSpec
import RedisLean.Error

open Redis LSpec

namespace RedisTests.Error

-- Helper function to check if a string contains a substring
def hasSubstring (s : String) (sub : String) : Bool :=
  let parts := s.splitOn sub
  parts.length > 1

-- Helper to test error construction
def testConnectErrorIO (msg : String) : Bool :=
  match ConnectError.IOError msg with
  | ConnectError.IOError m => m == msg
  | _ => false

def testConnectErrorEOF (msg : String) : Bool :=
  match ConnectError.EOFError msg with
  | ConnectError.EOFError m => m == msg
  | _ => false

-- ConnectError Construction Tests
def connectErrorConstructionTests : TestSeq :=
  test "IOError creation" (testConnectErrorIO "Connection refused") $
  test "EOFError creation" (testConnectErrorEOF "Unexpected end of file") $
  test "protocolError creation" (
    match ConnectError.protocolError "Invalid protocol" with
    | ConnectError.protocolError msg => msg == "Invalid protocol"
    | _ => false) $
  test "ConnectError otherError creation" (
    match ConnectError.otherError "Unknown issue" with
    | ConnectError.otherError msg => msg == "Unknown issue"
    | _ => false)

-- ConnectError ToString Tests
def connectErrorToStringTests : TestSeq :=
  test "IOError toString non-empty" ((toString (ConnectError.IOError "test message")).length > 0) $
  test "EOFError toString non-empty" ((toString (ConnectError.EOFError "eof message")).length > 0) $
  test "protocolError toString non-empty" ((toString (ConnectError.protocolError "protocol message")).length > 0) $
  test "ConnectError otherError toString non-empty" ((toString (ConnectError.otherError "other message")).length > 0)

-- Error Construction Tests
def errorConstructionTests : TestSeq :=
  test "connectError creation" (
    match Error.connectError (ConnectError.IOError "Failed to connect") with
    | Error.connectError (ConnectError.IOError msg) => msg == "Failed to connect"
    | _ => false) $
  test "nullReplyError creation" (
    match Error.nullReplyError "Received null" with
    | Error.nullReplyError msg => msg == "Received null"
    | _ => false) $
  test "replyError creation" (
    match Error.replyError "INVALID COMMAND" with
    | Error.replyError msg => msg == "INVALID COMMAND"
    | _ => false) $
  test "unexpectedReplyTypeError creation" (
    match Error.unexpectedReplyTypeError "Expected string, got int" with
    | Error.unexpectedReplyTypeError msg => msg == "Expected string, got int"
    | _ => false) $
  test "keyNotFoundError creation" (
    match Error.keyNotFoundError "mykey" with
    | Error.keyNotFoundError key => key == "mykey"
    | _ => false) $
  test "noExpiryDefinedError creation" (
    match Error.noExpiryDefinedError "persistent-key" with
    | Error.noExpiryDefinedError key => key == "persistent-key"
    | _ => false) $
  test "otherError creation" (
    match Error.otherError "Unknown error" with
    | Error.otherError msg => msg == "Unknown error"
    | _ => false)

-- Error ToString Tests
def errorToStringTests : TestSeq :=
  test "connectError toString non-empty" (
    (toString (Error.connectError (ConnectError.IOError "Connection failed"))).length > 0) $
  test "nullReplyError toString non-empty" (
    (toString (Error.nullReplyError "Null response")).length > 0) $
  test "replyError toString non-empty" (
    (toString (Error.replyError "Bad command")).length > 0) $
  test "unexpectedReplyTypeError toString non-empty" (
    (toString (Error.unexpectedReplyTypeError "Type mismatch")).length > 0) $
  test "keyNotFoundError toString non-empty" (
    (toString (Error.keyNotFoundError "missing-key")).length > 0) $
  test "noExpiryDefinedError toString non-empty" (
    (toString (Error.noExpiryDefinedError "no-ttl-key")).length > 0) $
  test "otherError toString non-empty" (
    (toString (Error.otherError "Misc error")).length > 0)

-- Error Differentiation Tests
def errorDifferentiationTests : TestSeq :=
  test "Different error types are distinguishable" (
    match (Error.connectError (ConnectError.IOError "test"), Error.replyError "test") with
    | (Error.connectError _, Error.replyError _) => true
    | _ => false) $
  test "Same error type with different messages" (
    match (Error.replyError "msg1", Error.replyError "msg2") with
    | (Error.replyError msg1, Error.replyError msg2) => msg1 != msg2
    | _ => false) $
  test "ConnectError variants are distinguishable" (
    match (ConnectError.IOError "io", ConnectError.EOFError "eof") with
    | (ConnectError.IOError _, ConnectError.EOFError _) => true
    | _ => false)

-- Error Pattern Matching Tests
def classifyError (err : Error) : String :=
  match err with
  | Error.connectError _ => "connect"
  | Error.sslError _ => "ssl"
  | Error.nullReplyError _ => "null"
  | Error.replyError _ => "reply"
  | Error.unexpectedReplyTypeError _ => "unexpected"
  | Error.keyNotFoundError _ => "keynotfound"
  | Error.noExpiryDefinedError _ => "noexpiry"
  | Error.otherError _ => "other"

def classifyConnectError (err : ConnectError) : String :=
  match err with
  | ConnectError.IOError _ => "io"
  | ConnectError.EOFError _ => "eof"
  | ConnectError.protocolError _ => "protocol"
  | ConnectError.otherError _ => "other"

def errorPatternMatchingTests : TestSeq :=
  test "Classify error by type" (
    [classifyError (Error.connectError (ConnectError.IOError "test")),
     classifyError (Error.nullReplyError "test"),
     classifyError (Error.replyError "test"),
     classifyError (Error.keyNotFoundError "test"),
     classifyError (Error.otherError "test")] ==
    ["connect", "null", "reply", "keynotfound", "other"]) $
  test "Classify ConnectError by type" (
    [classifyConnectError (ConnectError.IOError "test"),
     classifyConnectError (ConnectError.EOFError "test"),
     classifyConnectError (ConnectError.protocolError "test"),
     classifyConnectError (ConnectError.otherError "test")] ==
    ["io", "eof", "protocol", "other"]) $
  test "Extract message from error" (
    let getMessage (err : Error) : String :=
      match err with
      | Error.connectError kind => toString kind
      | Error.sslError kind => toString kind
      | Error.nullReplyError msg => msg
      | Error.replyError msg => msg
      | Error.unexpectedReplyTypeError msg => msg
      | Error.keyNotFoundError key => key
      | Error.noExpiryDefinedError key => key
      | Error.otherError msg => msg
    getMessage (Error.replyError "ERR command not found") == "ERR command not found")

-- Error Handling Scenario Tests
def errorHandlingScenarioTests : TestSeq :=
  test "Network connection failure scenario" (
    match Error.connectError (ConnectError.IOError "Connection refused: localhost:6379") with
    | Error.connectError (ConnectError.IOError msg) => hasSubstring msg "Connection refused"
    | _ => false) $
  test "Server EOF scenario" (
    match Error.connectError (ConnectError.EOFError "Server closed connection") with
    | Error.connectError (ConnectError.EOFError msg) => hasSubstring msg "closed connection"
    | _ => false) $
  test "Invalid Redis command scenario" (
    match Error.replyError "ERR unknown command 'INVALIDCMD'" with
    | Error.replyError msg => hasSubstring msg "unknown command"
    | _ => false) $
  test "Key not found scenario" (
    match Error.keyNotFoundError "nonexistent-key" with
    | Error.keyNotFoundError key => key == "nonexistent-key"
    | _ => false)

-- Error Property Tests
def errorPropertyTests : TestSeq :=
  test "All error types produce non-empty toString" (
    [Error.connectError (ConnectError.IOError "conn"),
     Error.connectError (ConnectError.EOFError "eof"),
     Error.connectError (ConnectError.protocolError "proto"),
     Error.connectError (ConnectError.otherError "other"),
     Error.nullReplyError "null",
     Error.replyError "reply",
     Error.unexpectedReplyTypeError "type",
     Error.keyNotFoundError "key",
     Error.noExpiryDefinedError "noexp",
     Error.otherError "other"].all (fun err => (toString err).length > 0)) $
  test "All ConnectError types produce non-empty toString" (
    [ConnectError.IOError "io",
     ConnectError.EOFError "eof",
     ConnectError.protocolError "proto",
     ConnectError.otherError "other"].all (fun err => (toString err).length > 0))

-- Error with Empty Messages Tests
def emptyMessageTests : TestSeq :=
  test "Error with empty message" ((toString (Error.replyError "")).length > 0) $
  test "ConnectError with empty message" ((toString (ConnectError.IOError "")).length > 0) $
  test "keyNotFoundError with empty key" ((toString (Error.keyNotFoundError "")).length > 0)

-- Error with Special Characters Tests
def specialCharacterTests : TestSeq :=
  test "Error message with newlines" (hasSubstring (toString (Error.replyError "line1\nline2\nline3")) "line1") $
  test "Key with special characters" (
    match Error.keyNotFoundError "user:123:profile" with
    | Error.keyNotFoundError key => key == "user:123:profile"
    | _ => false)

-- Combined error tests
def allErrorTests : TestSeq :=
  group "ConnectError Construction Tests" connectErrorConstructionTests $
  group "ConnectError ToString Tests" connectErrorToStringTests $
  group "Error Construction Tests" errorConstructionTests $
  group "Error ToString Tests" errorToStringTests $
  group "Error Differentiation Tests" errorDifferentiationTests $
  group "Error Pattern Matching Tests" errorPatternMatchingTests $
  group "Error Handling Scenario Tests" errorHandlingScenarioTests $
  group "Error Property Tests" errorPropertyTests $
  group "Empty Message Tests" emptyMessageTests $
  group "Special Character Tests" specialCharacterTests

end RedisTests.Error
