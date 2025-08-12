import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesListsExample

open Redis

/-!
# Redis Lists Examples

Demonstrates Redis list operations for implementing:
- Message queues (FIFO/LIFO)
- Activity feeds
- Recent items lists
- Task queues
-/

/-- Example: Basic list operations -/
def exBasicList : RedisM Unit := do
  Log.info "Example: Basic list operations"

  let key := "list:basic"

  -- Push items to left (head) of list
  let len1 ← lpush key ["item3", "item2", "item1"]
  Log.info s!"After LPUSH: list length = {len1}"

  -- Push items to right (tail) of list
  let len2 ← rpush key ["item4", "item5"]
  Log.info s!"After RPUSH: list length = {len2}"

  -- Get all items
  let items ← lrange key 0 (-1)
  let itemStrs := items.map String.fromUTF8!
  Log.info s!"List contents: {itemStrs}"

  -- Get list length
  let listLen ← llen key
  Log.info s!"List length: {listLen}"

  -- Get item by index
  let item ← lindex key 2
  Log.info s!"Item at index 2: {String.fromUTF8! item}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Queue pattern (FIFO) -/
def exQueuePattern : RedisM Unit := do
  Log.info "Example: Queue pattern (FIFO)"

  let queueKey := "queue:tasks"

  -- Enqueue tasks (push to right)
  let _ ← rpush queueKey ["task1", "task2", "task3"]
  Log.info "Enqueued: task1, task2, task3"

  -- Dequeue tasks (pop from left)
  let task1 ← lpop queueKey none
  let task2 ← lpop queueKey none
  Log.info s!"Dequeued: {task1.map String.fromUTF8!}"
  Log.info s!"Dequeued: {task2.map String.fromUTF8!}"

  -- Check remaining
  let remaining ← lrange queueKey 0 (-1)
  Log.info s!"Remaining in queue: {remaining.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [queueKey]

/-- Example: Stack pattern (LIFO) -/
def exStackPattern : RedisM Unit := do
  Log.info "Example: Stack pattern (LIFO)"

  let stackKey := "stack:undo"

  -- Push items onto stack (push to left)
  let _ ← lpush stackKey ["action1"]
  let _ ← lpush stackKey ["action2"]
  let _ ← lpush stackKey ["action3"]
  Log.info "Pushed: action1, action2, action3"

  -- Pop from stack (pop from left)
  let top1 ← lpop stackKey none
  let top2 ← lpop stackKey none
  Log.info s!"Popped: {top1.map String.fromUTF8!}"
  Log.info s!"Popped: {top2.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [stackKey]

/-- Example: Recent items list with capping -/
def exRecentItems : RedisM Unit := do
  Log.info "Example: Recent items list with capping"

  let key := "recent:views"
  let maxItems := 5

  -- Add items, keeping only the most recent N
  for i in List.range 10 do
    let _ ← lpush key [s!"page_{i}"]
    ltrim key 0 (maxItems - 1)  -- Keep only first N items

  -- Get recent items
  let recent ← lrange key 0 (-1)
  Log.info s!"Recent {maxItems} items (most recent first):"
  for item in recent do
    Log.info s!"  - {String.fromUTF8! item}"

  -- Cleanup
  let _ ← del [key]

/-- Example: List modification operations -/
def exListModification : RedisM Unit := do
  Log.info "Example: List modification operations"

  let key := "list:modify"

  -- Create initial list
  let _ ← rpush key ["a", "b", "c", "d", "e"]
  let initial ← lrange key 0 (-1)
  Log.info s!"Initial: {initial.map String.fromUTF8!}"

  -- Set element at index
  lset key 2 "C"
  let afterSet ← lrange key 0 (-1)
  Log.info s!"After LSET index 2 to 'C': {afterSet.map String.fromUTF8!}"

  -- Insert before element
  let _ ← linsertBefore key "d" "x"
  let afterInsert ← lrange key 0 (-1)
  Log.info s!"After LINSERT BEFORE 'd' 'x': {afterInsert.map String.fromUTF8!}"

  -- Remove elements
  let removed ← lrem key 1 "x"
  let afterRem ← lrange key 0 (-1)
  Log.info s!"After LREM 'x' (removed {removed}): {afterRem.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Range operations -/
def exRangeOperations : RedisM Unit := do
  Log.info "Example: Range operations"

  let key := "list:range"

  -- Create list with 10 items
  let items := (List.range 10).map (s!"item_{·}")
  let _ ← rpush key items

  -- Get first 3 items
  let first3 ← lrange key 0 2
  Log.info s!"First 3 items: {first3.map String.fromUTF8!}"

  -- Get last 3 items (negative indices)
  let last3 ← lrange key (-3) (-1)
  Log.info s!"Last 3 items: {last3.map String.fromUTF8!}"

  -- Get middle items
  let middle ← lrange key 3 6
  Log.info s!"Items 3-6: {middle.map String.fromUTF8!}"

  -- Note: GETRANGE works on strings, not lists
  Log.info "Note: GETRANGE is for strings, use LRANGE for lists"

  -- Cleanup
  let _ ← del [key]

/-- Example: Conditional push operations -/
def exConditionalPush : RedisM Unit := do
  Log.info "Example: Conditional push operations"

  let key := "list:conditional"

  -- LPUSHX - only push if list exists
  let result1 ← lpushx key ["value"]
  Log.info s!"LPUSHX on non-existent list: {result1} (0 = not pushed)"

  -- Create the list
  let _ ← lpush key ["initial"]

  -- Now LPUSHX works
  let result2 ← lpushx key ["prepended"]
  Log.info s!"LPUSHX on existing list: {result2}"

  -- Similarly for RPUSHX
  let result3 ← rpushx key ["appended"]
  Log.info s!"RPUSHX on existing list: {result3}"

  let final ← lrange key 0 (-1)
  Log.info s!"Final list: {final.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Multi-pop operations -/
def exMultiPop : RedisM Unit := do
  Log.info "Example: Multi-pop operations"

  let key := "list:multipop"

  -- Create list
  let _ ← rpush key ["a", "b", "c", "d", "e", "f"]
  Log.info "Created list: [a, b, c, d, e, f]"

  -- Pop multiple items from left
  let left2 ← lpop key (some 2)
  Log.info s!"LPOP 2 items: {left2.map String.fromUTF8!}"

  -- Pop multiple items from right
  let right2 ← rpop key (some 2)
  Log.info s!"RPOP 2 items: {right2.map String.fromUTF8!}"

  -- Check remaining
  let remaining ← lrange key 0 (-1)
  Log.info s!"Remaining: {remaining.map String.fromUTF8!}"

  -- Cleanup
  let _ ← del [key]

/-- Run all list examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Redis Lists Examples ==="
  exBasicList
  exQueuePattern
  exStackPattern
  exRecentItems
  exListModification
  exRangeOperations
  exConditionalPush
  exMultiPop
  Log.info "=== Redis Lists Examples Complete ==="

end FeaturesListsExample
