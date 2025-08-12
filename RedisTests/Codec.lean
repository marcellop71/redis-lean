import LSpec
import RedisLean.Codec

open Redis LSpec

namespace RedisTests.Codec

-- Helper function to test codec roundtrip
def testCodecRoundtrip [Codec α] [BEq α] (original : α) : Bool :=
  let encoded := Codec.enc original
  match Codec.dec encoded with
  | .ok value => value == original
  | .error _ => false

-- Helper to test decoding failure
def testDecodeFails (bytes : ByteArray) (α : Type) [Codec α] : Bool :=
  match (Codec.dec bytes : Except String α) with
  | .ok _ => false
  | .error _ => true

-- String Codec Tests
def stringCodecTests : TestSeq :=
  test "Empty string codec" (testCodecRoundtrip "") $
  test "ASCII string codec" (testCodecRoundtrip "hello world 123") $
  test "Unicode string codec" (testCodecRoundtrip "Hello 世界") $
  test "String with special characters" (testCodecRoundtrip "line1\nline2\ttab") $
  test "Long string codec" (testCodecRoundtrip (String.ofList (List.replicate 1000 'a')))

-- Int Codec Tests
def intCodecTests : TestSeq :=
  test "Zero codec" (testCodecRoundtrip (0 : Int)) $
  test "Positive integer codec" (testCodecRoundtrip (42 : Int)) $
  test "Negative integer codec" (testCodecRoundtrip (-42 : Int)) $
  test "Large positive integer" (testCodecRoundtrip (9223372036854775807 : Int)) $
  test "Int decode invalid string fails" (testDecodeFails "not_a_number".toUTF8 Int)

-- Nat Codec Tests
def natCodecTests : TestSeq :=
  test "Zero nat codec" (testCodecRoundtrip (0 : Nat)) $
  test "Small nat codec" (testCodecRoundtrip (123 : Nat)) $
  test "Large nat codec" (testCodecRoundtrip (18446744073709551615 : Nat)) $
  test "Nat decode invalid string fails" (testDecodeFails "not_a_nat".toUTF8 Nat)

-- Bool Codec Tests
def boolCodecTests : TestSeq :=
  test "True codec" (testCodecRoundtrip true) $
  test "False codec" (testCodecRoundtrip false) $
  test "Bool encoding produces expected strings" (
    Codec.enc true == "true".toUTF8 && Codec.enc false == "false".toUTF8) $
  test "Bool decode invalid string fails" (testDecodeFails "yes".toUTF8 Bool)

-- Unit Codec Tests
def unitCodecTests : TestSeq :=
  test "Unit codec roundtrip" (testCodecRoundtrip ()) $
  test "Unit encoding produces empty bytes" (
    (Codec.enc ()).size == 0) $
  test "Unit decoding always succeeds" (
    match (Codec.dec "anything".toUTF8 : Except String Unit) with
    | .ok _ => true
    | .error _ => false)

-- ByteArray Codec Tests
def byteArrayCodecTests : TestSeq :=
  test "Empty ByteArray codec" (testCodecRoundtrip ByteArray.empty) $
  test "ByteArray with content codec" (testCodecRoundtrip "test data".toUTF8) $
  test "ByteArray with binary data" (testCodecRoundtrip (ByteArray.mk #[0, 1, 255, 128, 64])) $
  test "ByteArray identity encoding" (
    let original := ByteArray.mk #[10, 20, 30]
    Codec.enc original == original)

-- Codec Property Tests
def codecPropertyTests : TestSeq :=
  test "Encoding is deterministic" (
    Codec.enc "test" == Codec.enc "test") $
  test "Encoding preserves information" (
    (Codec.enc (42 : Int)).size > 0) $
  test "Multiple roundtrips are stable" (
    testCodecRoundtrip "stable" && testCodecRoundtrip "stable") $
  test "Different values produce different encodings" (
    Codec.enc "hello" != Codec.enc "world")

-- Edge Case Tests
def edgeCaseTests : TestSeq :=
  test "Whitespace-only string" (testCodecRoundtrip "   \t\n  ") $
  test "String with quotes" (testCodecRoundtrip "He said \"hello\"") $
  test "Int boundary value -1" (testCodecRoundtrip (-1 : Int))

-- Combined codec tests
def allCodecTests : TestSeq :=
  group "String Codec Tests" stringCodecTests $
  group "Int Codec Tests" intCodecTests $
  group "Nat Codec Tests" natCodecTests $
  group "Bool Codec Tests" boolCodecTests $
  group "Unit Codec Tests" unitCodecTests $
  group "ByteArray Codec Tests" byteArrayCodecTests $
  group "Codec Property Tests" codecPropertyTests $
  group "Edge Case Tests" edgeCaseTests

end RedisTests.Codec
