import LSpec
import RedisLean.TypedKey

open Redis LSpec

namespace RedisTests.TypedKeyTests

/-!
# TypedKey Tests

Tests for phantom-typed keys and namespace functionality.
-/

-- TypedKey Construction Tests

def typedKeyConstructionTests : TestSeq :=
  test "TypedKey.mk creates key with correct string" (
    let key : TypedKey String := ⟨"test:key"⟩
    key.key == "test:key") $
  test "TypedKey preserves key name" (
    let key : TypedKey Int := ⟨"counter:visits"⟩
    key.key == "counter:visits") $
  test "Different phantom types same string" (
    let strKey : TypedKey String := ⟨"mykey"⟩
    let intKey : TypedKey Int := ⟨"mykey"⟩
    strKey.key == intKey.key) $
  test "Empty key name allowed" (
    let key : TypedKey String := ⟨""⟩
    key.key == "") $
  test "Key with special characters" (
    let key : TypedKey String := ⟨"user:123:profile"⟩
    key.key == "user:123:profile") $
  test "Key with unicode" (
    let key : TypedKey String := ⟨"user:日本語"⟩
    key.key == "user:日本語")

-- Namespace Tests

def namespaceCreationTests : TestSeq :=
  test "Namespace.create creates namespace" (
    let ns := Namespace.create "app"
    ns.nsPrefix == "app") $
  test "Namespace with empty prefix" (
    let ns := Namespace.create ""
    ns.nsPrefix == "") $
  test "Namespace with special characters" (
    let ns := Namespace.create "my-app_v2"
    ns.nsPrefix == "my-app_v2")

def namespaceNestedTests : TestSeq :=
  test "Nested namespace creates correct prefix" (
    let root := Namespace.create "app"
    let nested := root.nested "cache"
    nested.nsPrefix == "app:cache") $
  test "Multiple levels of nesting" (
    let l1 := Namespace.create "app"
    let l2 := l1.nested "cache"
    let l3 := l2.nested "users"
    l3.nsPrefix == "app:cache:users") $
  test "Deep nesting preserves structure" (
    let ns := Namespace.create "a"
    let ns := ns.nested "b"
    let ns := ns.nested "c"
    let ns := ns.nested "d"
    ns.nsPrefix == "a:b:c:d")

def namespaceKeyTests : TestSeq :=
  test "Namespace.key creates prefixed TypedKey" (
    let ns := Namespace.create "app"
    let key : TypedKey String := ns.key "user:123"
    key.key == "app:user:123") $
  test "Nested namespace key has full prefix" (
    let ns := Namespace.create "myapp"
    let cache := ns.nested "cache"
    let key : TypedKey Int := cache.key "counter"
    key.key == "myapp:cache:counter") $
  test "Empty key after namespace" (
    let ns := Namespace.create "prefix"
    let key : TypedKey String := ns.key ""
    key.key == "prefix:") $
  test "Key with colon after namespace" (
    let ns := Namespace.create "app"
    let key : TypedKey String := ns.key "user:123:data"
    key.key == "app:user:123:data")

-- TypedHashField Tests

def typedHashFieldTests : TestSeq :=
  test "TypedHashField.create creates field" (
    let field : TypedHashField String := TypedHashField.create "name"
    field.field == "name") $
  test "TypedHashField preserves field name" (
    let field : TypedHashField Int := TypedHashField.create "age"
    field.field == "age") $
  test "Empty field name" (
    let field : TypedHashField Bool := TypedHashField.create ""
    field.field == "") $
  test "Field with special characters" (
    let field : TypedHashField String := TypedHashField.create "user:profile"
    field.field == "user:profile")

-- Key Naming Convention Tests

def keyNamingConventionTests : TestSeq :=
  test "Standard Redis key naming (colon separator)" (
    let key : TypedKey String := ⟨"user:123:profile"⟩
    key.key.splitOn ":" == ["user", "123", "profile"]) $
  test "Namespace follows colon convention" (
    let ns := Namespace.create "service"
    let key : TypedKey String := ns.key "entity:1"
    key.key.splitOn ":" == ["service", "entity", "1"]) $
  test "Multiple colons in key" (
    let key : TypedKey String := ⟨"a:b:c:d:e"⟩
    (key.key.splitOn ":").length == 5)

-- Type Safety Verification Tests (compile-time type tracking)

def typeSafetyTests : TestSeq :=
  test "TypedKey type parameter is preserved (String)" (
    let key : TypedKey String := ⟨"str"⟩
    key.key == "str") $
  test "TypedKey type parameter is preserved (Nat)" (
    let key : TypedKey Nat := ⟨"nat"⟩
    key.key == "nat") $
  test "TypedKey type parameter is preserved (Bool)" (
    let key : TypedKey Bool := ⟨"bool"⟩
    key.key == "bool") $
  test "TypedKey type parameter is preserved (custom type)" (
    let key : TypedKey (List String) := ⟨"list"⟩
    key.key == "list")

-- Edge Cases Tests

def edgeCaseTests : TestSeq :=
  test "Very long key name" (
    let longName := String.join (List.replicate 100 "segment:")
    let key : TypedKey String := ⟨longName⟩
    key.key == longName) $
  test "Key with only colons" (
    let key : TypedKey String := ⟨":::"⟩
    key.key == ":::") $
  test "Key with spaces" (
    let key : TypedKey String := ⟨"key with spaces"⟩
    key.key == "key with spaces") $
  test "Key with newlines" (
    let key : TypedKey String := ⟨"line1\nline2"⟩
    key.key == "line1\nline2") $
  test "Namespace with only colons" (
    let ns := Namespace.create ":"
    let key : TypedKey String := ns.key ":"
    key.key == ":::")

-- Practical Usage Patterns

def practicalPatternTests : TestSeq :=
  test "User session key pattern" (
    let sessions := Namespace.create "sessions"
    let key : TypedKey String := sessions.key "user:abc123"
    key.key == "sessions:user:abc123") $
  test "Cache key pattern" (
    let cache := Namespace.create "cache"
    let api := cache.nested "api"
    let key : TypedKey String := api.key "endpoint:users"
    key.key == "cache:api:endpoint:users") $
  test "Counter key pattern" (
    let metrics := Namespace.create "metrics"
    let counters := metrics.nested "counters"
    let key : TypedKey Nat := counters.key "page_views"
    key.key == "metrics:counters:page_views") $
  test "Feature flag pattern" (
    let flags := Namespace.create "flags"
    let key : TypedKey Bool := flags.key "dark_mode"
    key.key == "flags:dark_mode")

-- All TypedKey Tests
def allTypedKeyTests : TestSeq :=
  group "TypedKey Construction" typedKeyConstructionTests $
  group "Namespace Creation" namespaceCreationTests $
  group "Namespace Nesting" namespaceNestedTests $
  group "Namespace Key Generation" namespaceKeyTests $
  group "TypedHashField" typedHashFieldTests $
  group "Key Naming Conventions" keyNamingConventionTests $
  group "Type Safety" typeSafetyTests $
  group "Edge Cases" edgeCaseTests $
  group "Practical Patterns" practicalPatternTests

end RedisTests.TypedKeyTests
