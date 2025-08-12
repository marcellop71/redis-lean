import LSpec
import RedisLean.Config

open Redis LSpec

namespace RedisTests.Config

-- Helper functions
def testFromString (input : String) (expectedHost : String) (expectedPort : Nat) : Bool :=
  match Config.fromString input with
  | some config => config.host == expectedHost && config.port == expectedPort
  | none => false

def testFromStringWithDb (input : String) (expectedHost : String) (expectedPort : Nat) (expectedDb : Nat) : Bool :=
  match Config.fromString input with
  | some config => config.host == expectedHost && config.port == expectedPort && config.database == expectedDb
  | none => false

def testFromUrl (input : String) (expectedHost : String) (expectedPort : Nat) : Bool :=
  match Config.fromUrl input with
  | some config => config.host == expectedHost && config.port == expectedPort
  | none => false

def testFromUrlWithDb (input : String) (expectedHost : String) (expectedPort : Nat) (expectedDb : Nat) : Bool :=
  match Config.fromUrl input with
  | some config => config.host == expectedHost && config.port == expectedPort && config.database == expectedDb
  | none => false

def testFromUrlHostOnly (input : String) (expectedHost : String) : Bool :=
  match Config.fromUrl input with
  | some config => config.host == expectedHost
  | none => false

-- Default Configuration Tests
def defaultConfigTests : TestSeq :=
  test "Default config has expected host" (Config.default.host == "127.0.0.1") $
  test "Default config has expected port" (Config.default.port == 6379) $
  test "Default config has expected database" (Config.default.database == 0) $
  test "Empty struct literal equals default" (
    let config : Config := {}
    config.host == Config.default.host &&
    config.port == Config.default.port &&
    config.database == Config.default.database)

-- Builder Function Tests
def builderFunctionTests : TestSeq :=
  test "withHost creates config with custom host" (
    let config := Config.withHost "redis.example.com"
    config.host == "redis.example.com" && config.port == 6379 && config.database == 0) $
  test "withPort creates config with custom port" (
    let config := Config.withPort 1234
    config.host == "127.0.0.1" && config.port == 1234 && config.database == 0) $
  test "withDatabase creates config with custom database" (
    let config := Config.withDatabase 5
    config.host == "127.0.0.1" && config.port == 6379 && config.database == 5) $
  test "make creates config with all custom values" (
    let config := Config.make "myhost" 9999 3
    config.host == "myhost" && config.port == 9999 && config.database == 3)

-- Config Creation Tests
def configCreationTests : TestSeq :=
  test "Custom host config" (
    let config : Config := { host := "redis.example.com" }
    config.host == "redis.example.com" && config.port == 6379) $
  test "Custom port config" (
    let config : Config := { port := 1234 }
    config.host == "127.0.0.1" && config.port == 1234) $
  test "Custom host and port" (
    let config : Config := { host := "redis.example.com", port := 1234 }
    config.host == "redis.example.com" && config.port == 1234) $
  test "Custom database config" (
    let config : Config := { database := 1 }
    config.database == 1) $
  test "All custom fields" (
    let config : Config := { host := "myhost", port := 8080, database := 15 }
    config.host == "myhost" && config.port == 8080 && config.database == 15)

-- Config fromString Tests
def fromStringTests : TestSeq :=
  test "fromString host only returns some" ((Config.fromString "redis.example.com").isSome) $
  test "fromString host only parses correctly" (testFromString "redis.example.com" "redis.example.com" 6379) $
  test "fromString host and port returns some" ((Config.fromString "redis.example.com:1234").isSome) $
  test "fromString host and port parses correctly" (testFromString "redis.example.com:1234" "redis.example.com" 1234) $
  test "fromString with database returns some" ((Config.fromString "redis.example.com:1234/5").isSome) $
  test "fromString with database parses correctly" (testFromStringWithDb "redis.example.com:1234/5" "redis.example.com" 1234 5) $
  test "fromString localhost" (testFromString "localhost:6379" "localhost" 6379) $
  test "fromString IP address" (testFromString "192.168.1.100:6379" "192.168.1.100" 6379) $
  test "fromString with invalid port returns none" ((Config.fromString "host:notaport").isNone)

-- Config fromUrl Tests
def fromUrlTests : TestSeq :=
  test "fromUrl with redis:// prefix" (testFromUrl "redis://myhost:6380" "myhost" 6380) $
  test "fromUrl with database" (testFromUrlWithDb "redis://myhost:6380/2" "myhost" 6380 2) $
  test "fromUrl without prefix" (testFromUrl "myhost:6380" "myhost" 6380) $
  test "fromUrl host only with prefix" (testFromUrlHostOnly "redis://myredis" "myredis")

-- Config toString Tests
def toStringTests : TestSeq :=
  test "toString without database" (
    let config : Config := { host := "localhost", port := 6379, database := 0 }
    Config.toString config == "localhost:6379") $
  test "toString with database" (
    let config : Config := { host := "localhost", port := 6379, database := 1 }
    Config.toString config == "localhost:6379/1") $
  test "toString with large database number" (
    let config : Config := { host := "host", port := 1234, database := 15 }
    Config.toString config == "host:1234/15") $
  test "toString with custom port" (
    let config : Config := { host := "redis", port := 9999, database := 0 }
    Config.toString config == "redis:9999")

-- Roundtrip Tests
def testRoundtrip (input : String) : Bool :=
  match Config.fromString input with
  | some config =>
    let str := Config.toString config
    match Config.fromString str with
    | some config2 => config.host == config2.host && config.port == config2.port
    | none => false
  | none => false

def testRoundtripWithDb (input : String) : Bool :=
  match Config.fromString input with
  | some config =>
    let str := Config.toString config
    match Config.fromString str with
    | some config2 =>
      config.host == config2.host &&
      config.port == config2.port &&
      config.database == config2.database
    | none => false
  | none => false

def roundtripTests : TestSeq :=
  test "Roundtrip without database" (testRoundtrip "myhost:1234") $
  test "Roundtrip with database" (testRoundtripWithDb "myhost:1234/5")

-- Config Modification Tests
def configModificationTests : TestSeq :=
  test "Config modification preserves other fields" (
    let baseConfig : Config := { host := "base", port := 1111, database := 2 }
    let modifiedConfig : Config := { baseConfig with port := 2222 }
    modifiedConfig.host == "base" && modifiedConfig.port == 2222 && modifiedConfig.database == 2) $
  test "Multiple field modification" (
    let baseConfig : Config := { host := "original", port := 1000, database := 1 }
    let modifiedConfig : Config := { baseConfig with host := "new", database := 5 }
    modifiedConfig.host == "new" && modifiedConfig.port == 1000 && modifiedConfig.database == 5)

-- Port Range Tests
def portRangeTests : TestSeq :=
  test "Valid port range - minimum" (({ port := 1 } : Config).port == 1) $
  test "Valid port range - maximum" (({ port := 65535 } : Config).port == 65535) $
  test "Standard Redis port" (({ port := 6379 } : Config).port == 6379)

-- Database Range Tests
def databaseRangeTests : TestSeq :=
  test "Database 0" (({ database := 0 } : Config).database == 0) $
  test "Database 15 (common max)" (({ database := 15 } : Config).database == 15) $
  test "Database larger than 15" (({ database := 100 } : Config).database == 100)

-- Example Scenario Tests
def exampleScenarioTests : TestSeq :=
  test "Local development config" (
    let devConfig : Config := { host := "127.0.0.1", port := 6379, database := 0 }
    devConfig.host == "127.0.0.1") $
  test "Production config example" (
    let prodConfig : Config := { host := "redis.production.com", port := 6380, database := 1 }
    prodConfig.host == "redis.production.com" && prodConfig.port == 6380) $
  test "Docker config example" (
    let dockerConfig : Config := { host := "redis-container", port := 6379, database := 0 }
    dockerConfig.host == "redis-container") $
  test "Sentinel config example" (
    let sentinelConfig : Config := { host := "sentinel.cluster.local", port := 26379, database := 0 }
    sentinelConfig.port == 26379)

-- Combined config tests
def allConfigTests : TestSeq :=
  group "Default Config Tests" defaultConfigTests $
  group "Builder Function Tests" builderFunctionTests $
  group "Config Creation Tests" configCreationTests $
  group "fromString Tests" fromStringTests $
  group "fromUrl Tests" fromUrlTests $
  group "toString Tests" toStringTests $
  group "Roundtrip Tests" roundtripTests $
  group "Config Modification Tests" configModificationTests $
  group "Port Range Tests" portRangeTests $
  group "Database Range Tests" databaseRangeTests $
  group "Example Scenario Tests" exampleScenarioTests

end RedisTests.Config
