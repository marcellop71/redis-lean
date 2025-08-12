import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesHyperLogLogExample

open Redis

/-!
# Redis HyperLogLog Examples

Demonstrates HyperLogLog operations for probabilistic cardinality estimation.
HyperLogLog provides:
- Constant memory usage (~12KB per key)
- Approximate unique count with ~0.81% standard error
- Perfect for counting unique visitors, events, etc.
-/

/-- Example: Basic HyperLogLog operations -/
def exBasicHyperLogLog : RedisM Unit := do
  Log.info "Example: Basic HyperLogLog operations"

  let key := "hll:visitors"

  -- Add elements to HyperLogLog
  let _ ← pfadd key ["user1", "user2", "user3"]
  let _ ← pfadd key ["user4", "user5"]
  Log.info "Added 5 unique users"

  -- Adding duplicates doesn't increase count
  let _ ← pfadd key ["user1", "user2", "user3"]
  Log.info "Added same 3 users again (duplicates)"

  -- Get estimated cardinality
  let count ← pfcount [key]
  Log.info s!"Estimated unique visitors: {count}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Counting unique page views -/
def exUniquePageViews : RedisM Unit := do
  Log.info "Example: Counting unique page views"

  let homePageKey := "hll:page:home"
  let aboutPageKey := "hll:page:about"
  let contactPageKey := "hll:page:contact"

  -- Simulate visitors to different pages
  let _ ← pfadd homePageKey ["visitor_1", "visitor_2", "visitor_3", "visitor_4", "visitor_5"]
  let _ ← pfadd aboutPageKey ["visitor_2", "visitor_3", "visitor_6"]
  let _ ← pfadd contactPageKey ["visitor_1", "visitor_4", "visitor_7"]

  -- Count unique visitors per page
  let homeCount ← pfcount [homePageKey]
  let aboutCount ← pfcount [aboutPageKey]
  let contactCount ← pfcount [contactPageKey]

  Log.info "Unique visitors by page:"
  Log.info s!"  Home: {homeCount}"
  Log.info s!"  About: {aboutCount}"
  Log.info s!"  Contact: {contactCount}"

  -- Count total unique visitors across all pages
  let totalUnique ← pfcount [homePageKey, aboutPageKey, contactPageKey]
  Log.info s!"Total unique visitors (across all pages): {totalUnique}"

  -- Cleanup
  let _ ← del [homePageKey, aboutPageKey, contactPageKey]

/-- Example: Merging HyperLogLogs -/
def exMergeHyperLogLog : RedisM Unit := do
  Log.info "Example: Merging HyperLogLogs"

  let day1Key := "hll:day:1"
  let day2Key := "hll:day:2"
  let day3Key := "hll:day:3"
  let weekKey := "hll:week:1"

  -- Visitors per day
  let _ ← pfadd day1Key ["user_a", "user_b", "user_c"]
  let _ ← pfadd day2Key ["user_b", "user_c", "user_d", "user_e"]
  let _ ← pfadd day3Key ["user_a", "user_e", "user_f"]

  -- Count per day
  let count1 ← pfcount [day1Key]
  let count2 ← pfcount [day2Key]
  let count3 ← pfcount [day3Key]

  Log.info "Daily unique visitors:"
  Log.info s!"  Day 1: {count1}"
  Log.info s!"  Day 2: {count2}"
  Log.info s!"  Day 3: {count3}"
  Log.info s!"  Sum: {count1 + count2 + count3} (includes duplicates)"

  -- Merge into weekly aggregate
  pfmerge weekKey [day1Key, day2Key, day3Key]

  -- Get true weekly unique count
  let weekCount ← pfcount [weekKey]
  Log.info s!"Weekly unique visitors (deduplicated): {weekCount}"

  -- Cleanup
  let _ ← del [day1Key, day2Key, day3Key, weekKey]

/-- Example: Checking for new elements -/
def exCheckNewElements : RedisM Unit := do
  Log.info "Example: Checking for new elements"

  let key := "hll:seen"

  -- Add initial elements
  let _ ← pfadd key ["item_1", "item_2", "item_3"]

  -- PFADD returns true if cardinality changed (new elements)
  let added1 ← pfadd key ["item_4"]  -- New element
  Log.info s!"Adding 'item_4' (new): changed = {added1}"

  let added2 ← pfadd key ["item_2"]  -- Already seen
  Log.info s!"Adding 'item_2' (duplicate): changed = {added2}"

  let added3 ← pfadd key ["item_5", "item_2"]  -- Mixed
  Log.info s!"Adding 'item_5' + 'item_2' (one new): changed = {added3}"

  let finalCount ← pfcount [key]
  Log.info s!"Final unique count: {finalCount}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Real-time analytics -/
def exRealTimeAnalytics : RedisM Unit := do
  Log.info "Example: Real-time analytics"

  let activeUsersKey := "hll:active:users"
  let apiCallersKey := "hll:api:callers"
  let errorUsersKey := "hll:error:users"

  -- Simulate real-time events
  Log.info "Simulating user activity..."

  -- Active users (many users, some overlap)
  for i in List.range 100 do
    let _ ← pfadd activeUsersKey [s!"user_{i % 50}"]  -- 50 unique users

  -- API callers (subset of active users)
  for i in List.range 30 do
    let _ ← pfadd apiCallersKey [s!"user_{i}"]

  -- Users who experienced errors (small subset)
  for i in [5, 10, 15, 20, 25] do
    let _ ← pfadd errorUsersKey [s!"user_{i}"]

  -- Get analytics
  let activeCount ← pfcount [activeUsersKey]
  let apiCount ← pfcount [apiCallersKey]
  let errorCount ← pfcount [errorUsersKey]

  Log.info "Real-time analytics:"
  Log.info s!"  Active users: ~{activeCount}"
  Log.info s!"  API callers: ~{apiCount}"
  Log.info s!"  Users with errors: ~{errorCount}"
  Log.info s!"  API usage rate: ~{apiCount * 100 / activeCount}%"
  Log.info s!"  Error rate: ~{errorCount * 100 / activeCount}%"

  -- Cleanup
  let _ ← del [activeUsersKey, apiCallersKey, errorUsersKey]

/-- Example: Memory efficiency comparison -/
def exMemoryEfficiency : RedisM Unit := do
  Log.info "Example: Memory efficiency"

  let hllKey := "hll:efficiency"
  let setKey := "set:efficiency"

  -- Add many unique elements to both
  let numElements := 1000

  Log.info s!"Adding {numElements} unique elements..."

  for i in List.range numElements do
    let _ ← pfadd hllKey [s!"element_{i}"]
    let _ ← sadd setKey s!"element_{i}"

  -- Compare cardinality
  let hllCount ← pfcount [hllKey]
  let setCount ← scard setKey

  Log.info "Cardinality comparison:"
  Log.info s!"  HyperLogLog estimate: {hllCount}"
  Log.info s!"  Set exact count: {setCount}"
  Log.info s!"  Difference: {Int.ofNat setCount - Int.ofNat hllCount}"

  Log.info "Memory comparison (approximate):"
  Log.info s!"  HyperLogLog: ~12 KB (constant)"
  Log.info s!"  Set: ~{numElements * 15 / 1024} KB (grows with elements)"

  -- Cleanup
  let _ ← del [hllKey, setKey]

/-- Run all HyperLogLog examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Redis HyperLogLog Examples ==="
  exBasicHyperLogLog
  exUniquePageViews
  exMergeHyperLogLog
  exCheckNewElements
  exRealTimeAnalytics
  exMemoryEfficiency
  Log.info "=== Redis HyperLogLog Examples Complete ==="

end FeaturesHyperLogLogExample
