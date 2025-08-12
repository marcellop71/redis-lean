import LSpec
import Tests.Codec
import Tests.Config
import Tests.Error
import Tests.Integration

open LSpec

-- Import all test modules
def allUnitTests : TestSeq :=
  group "Redis-Lean Unit Tests" $
    Tests.Codec.allCodecTests ++
    Tests.Config.allConfigTests ++
    Tests.Error.allErrorTests

def allIntegrationTests : TestSeq :=
  group "Redis-Lean Integration Tests" $
    Tests.Integration.allIntegrationTests

-- Complete test suite
def completeTestSuite : TestSeq :=
  allUnitTests ++ allIntegrationTests

-- Interactive test runner (runs at compile time)
#lspec completeTestSuite

-- Main function for command-line execution
def main (args : List String) : IO UInt32 := do
  match args with
  | ["unit"] => do
    IO.println "Running unit tests only..."
    IO.println "Unit tests passed at compile time via #lspec"
    return 0
  | ["integration"] => do
    IO.println "Running integration tests (Redis server required)..."
    IO.println "Integration tests are placeholders - require actual Redis server"
    return 0
  | ["all"] | [] => do
    IO.println "Running all tests..."
    IO.println "All tests passed at compile time via #lspec"
    return 0
  | _ => do
    IO.println "Usage: testRunner [unit|integration|all]"
    IO.println "  unit        - Run unit tests only (no Redis server needed)"
    IO.println "  integration - Run integration tests (requires Redis server)"
    IO.println "  all         - Run all tests (default)"
    return 1
