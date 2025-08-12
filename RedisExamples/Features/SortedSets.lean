import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesSortedSetsExample

open Redis

/-!
# Redis Sorted Sets Examples

Demonstrates Redis sorted set operations for implementing:
- Leaderboards and rankings
- Priority queues
- Time-based data (with timestamps as scores)
- Rate limiting
-/

/-- Example: Basic sorted set operations -/
def exBasicSortedSet : RedisM Unit := do
  Log.info "Example: Basic sorted set operations"

  let key := "zset:basic"

  -- Add members with scores
  let _ ← zadd key 100.0 "alice"
  let _ ← zadd key 200.0 "bob"
  let _ ← zadd key 150.0 "charlie"
  Log.info "Added: alice(100), bob(200), charlie(150)"

  -- Get all members (sorted by score ascending)
  let members ← zrange key 0 (-1)
  Log.info s!"Members (ascending): {members.map String.fromUTF8!}"

  -- Get cardinality
  let count ← zcard key
  Log.info s!"Total members: {count}"

  -- Get score of a member
  let aliceScore ← zscore key "alice"
  Log.info s!"Alice's score: {aliceScore}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Leaderboard implementation -/
def exLeaderboard : RedisM Unit := do
  Log.info "Example: Leaderboard implementation"

  let key := "leaderboard:game1"

  -- Add players with scores
  let players := [
    ("player1", 1500.0),
    ("player2", 2300.0),
    ("player3", 1800.0),
    ("player4", 2100.0),
    ("player5", 1950.0)
  ]

  for (player, score) in players do
    let _ ← zadd key score player

  Log.info "Leaderboard created"

  -- Get top 3 players (highest scores first)
  let top3 ← zrevrange key 0 2
  Log.info "Top 3 players:"
  let mut idx := 1
  for player in top3 do
    let score ← zscore key (String.fromUTF8! player)
    Log.info s!"  #{idx}: {String.fromUTF8! player} - {score.getD 0}"
    idx := idx + 1

  -- Get player rank (0-indexed, reverse order for leaderboard)
  let rank ← zrevrank key "player3"
  Log.info s!"player3's rank: #{rank.map (· + 1)}"

  -- Increment score (player scored more points)
  let newScore ← zincrby key 500.0 "player1"
  Log.info s!"player1's new score after +500: {newScore}"

  -- Updated top 3
  let newTop3 ← zrevrange key 0 2
  Log.info s!"Updated top 3: {newTop3.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Range by score -/
def exRangeByScore : RedisM Unit := do
  Log.info "Example: Range by score"

  let key := "zset:scores"

  -- Add items with various scores
  for i in List.range 10 do
    let score := Float.ofNat (i * 10 + 5)
    let _ ← zadd key score s!"item_{i}"

  -- Get items with score between 25 and 65
  let rangeItems ← zrangebyscore key "25" "65"
  Log.info s!"Items with score 25-65: {rangeItems.map String.fromUTF8!}"

  -- Count items in score range
  let count ← zcount key "25" "65"
  Log.info s!"Count of items in range: {count}"

  -- Get items with score > 50
  let highScores ← zrangebyscore key "50" "+inf"
  Log.info s!"Items with score > 50: {highScores.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Priority queue -/
def exPriorityQueue : RedisM Unit := do
  Log.info "Example: Priority queue"

  let key := "pqueue:tasks"

  -- Add tasks with priority (lower score = higher priority)
  let _ ← zadd key 1.0 "critical_task"
  let _ ← zadd key 5.0 "normal_task"
  let _ ← zadd key 10.0 "low_priority_task"
  let _ ← zadd key 3.0 "important_task"

  Log.info "Added tasks with priorities"

  -- Get highest priority task (lowest score)
  let highestPriority ← zpopmin key (some 1)
  Log.info s!"Processing highest priority: {highestPriority.map String.fromUTF8!}"

  -- Get next two highest priority tasks
  let next2 ← zpopmin key (some 2)
  Log.info s!"Next 2 tasks: {next2.map String.fromUTF8!}"

  -- Remaining tasks
  let remaining ← zrange key 0 (-1)
  Log.info s!"Remaining tasks: {remaining.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Time-series data -/
def exTimeSeriesData : RedisM Unit := do
  Log.info "Example: Time-series data (using timestamps as scores)"

  let key := "timeseries:events"

  -- Add events with timestamps (simulated)
  let baseTime := 1700000000.0
  let events := [
    (baseTime, "event_1"),
    (baseTime + 60.0, "event_2"),
    (baseTime + 120.0, "event_3"),
    (baseTime + 180.0, "event_4"),
    (baseTime + 240.0, "event_5")
  ]

  for (timestamp, event) in events do
    let _ ← zadd key timestamp event

  Log.info "Added time-series events"

  -- Get events in time range (first 2 minutes)
  let rangeEvents ← zrangebyscore key s!"{baseTime}" s!"{baseTime + 120}"
  Log.info s!"Events in first 2 minutes: {rangeEvents.map String.fromUTF8!}"

  -- Get recent events (reverse order)
  let recentEvents ← zrevrange key 0 2
  Log.info s!"Most recent 3 events: {recentEvents.map String.fromUTF8!}"

  -- Remove old events (before baseTime + 60)
  let removed ← zremrangebyscore key "-inf" s!"{baseTime + 59}"
  Log.info s!"Removed {removed} old events"

  -- Cleanup
  let _ ← del [key]

/-- Example: Ranking with ties -/
def exRankingWithTies : RedisM Unit := do
  Log.info "Example: Ranking with ties"

  let key := "zset:ties"

  -- Add members with same scores (ties)
  let _ ← zadd key 100.0 "alice"
  let _ ← zadd key 100.0 "bob"
  let _ ← zadd key 200.0 "charlie"
  let _ ← zadd key 100.0 "diana"

  -- Get all members (ties sorted lexicographically)
  let allMembers ← zrange key 0 (-1)
  Log.info s!"Members with ties: {allMembers.map String.fromUTF8!}"

  -- Get ranks (note: different members with same score have different ranks)
  for member in ["alice", "bob", "diana"] do
    let rank ← zrank key member
    Log.info s!"  {member}'s rank: {rank}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Set operations on sorted sets -/
def exSortedSetOperations : RedisM Unit := do
  Log.info "Example: Sorted set removal operations"

  let key := "zset:ops"

  -- Create sorted set
  for i in List.range 10 do
    let _ ← zadd key (Float.ofNat i) s!"member_{i}"

  let initial ← zcard key
  Log.info s!"Initial size: {initial}"

  -- Remove by rank (remove first 3)
  let removedByRank ← zremrangebyrank key 0 2
  Log.info s!"Removed {removedByRank} members by rank (0-2)"

  -- Remove by score (remove scores > 7)
  let removedByScore ← zremrangebyscore key "7" "+inf"
  Log.info s!"Removed {removedByScore} members with score > 7"

  -- Remove specific members
  let removedMembers ← zrem key ["member_4", "member_5"]
  Log.info s!"Removed {removedMembers} specific members"

  let final ← zrange key 0 (-1)
  Log.info s!"Remaining: {final.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Scanning sorted sets -/
def exScanSortedSet : RedisM Unit := do
  Log.info "Example: Scanning sorted sets"

  let key := "zset:scan"

  -- Create large sorted set
  for i in List.range 20 do
    let _ ← zadd key (Float.ofNat i) s!"member_{i}"

  Log.info "Created sorted set with 20 members"

  -- Scan with cursor
  let (cursor1, batch1) ← zscan key 0 none (some 5)
  Log.info s!"First scan (cursor 0, count 5):"
  Log.info s!"  Returned cursor: {cursor1}"
  Log.info s!"  Batch size: {batch1.length}"

  -- Continue scanning if cursor != 0
  if cursor1 != 0 then
    let (cursor2, batch2) ← zscan key cursor1 none (some 5)
    Log.info s!"Second scan (cursor {cursor1}):"
    Log.info s!"  Returned cursor: {cursor2}"
    Log.info s!"  Batch size: {batch2.length}"

  -- Cleanup
  let _ ← del [key]

/-- Run all sorted set examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Redis Sorted Sets Examples ==="
  exBasicSortedSet
  exLeaderboard
  exRangeByScore
  exPriorityQueue
  exTimeSeriesData
  exRankingWithTies
  exSortedSetOperations
  exScanSortedSet
  Log.info "=== Redis Sorted Sets Examples Complete ==="

end FeaturesSortedSetsExample
