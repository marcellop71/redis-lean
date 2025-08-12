import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesPubSubExample

open Redis

/-!
# Redis Pub/Sub Examples

Demonstrates Redis Publish/Subscribe for:
- Real-time messaging
- Event broadcasting
- Notifications
- Inter-service communication
-/

/-- Example: Basic publish -/
def exBasicPublish : RedisM Unit := do
  Log.info "Example: Basic publish"

  -- Publish messages to channels
  let channel := "notifications"

  let subscribers1 ← publish (α := String) channel ("Hello, subscribers!" : String)
  Log.info s!"Message sent to {subscribers1} subscribers"

  let subscribers2 ← publish (α := String) channel ("Another notification" : String)
  Log.info s!"Message sent to {subscribers2} subscribers"

  -- Note: Without active subscribers, count will be 0

/-- Example: Publish to different channels -/
def exMultiChannelPublish : RedisM Unit := do
  Log.info "Example: Publish to different channels"

  -- System events channel
  let sysChannel := "events:system"
  let userChannel := "events:user"
  let alertChannel := "alerts:critical"

  let _ ← publish (α := String) sysChannel ("Server started" : String)
  Log.info "Published to system events"

  let _ ← publish (α := String) userChannel ("User john logged in" : String)
  Log.info "Published to user events"

  let _ ← publish (α := String) alertChannel ("Critical: Database connection lost" : String)
  Log.info "Published to alerts"

/-- Example: JSON message publishing -/
def exJsonPublish : RedisM Unit := do
  Log.info "Example: JSON message publishing"

  let channel := "events:orders"

  -- Publish structured data (as JSON string)
  let orderEvent := "{\"type\":\"order_created\",\"order_id\":\"ORD-123\",\"amount\":99.99}"
  let _ ← publish (α := String) channel (orderEvent : String)
  Log.info s!"Published order event: {orderEvent}"

  let paymentEvent := "{\"type\":\"payment_received\",\"order_id\":\"ORD-123\",\"status\":\"success\"}"
  let _ ← publish (α := String) channel (paymentEvent : String)
  Log.info s!"Published payment event: {paymentEvent}"

/-- Example: Notification system -/
def exNotificationSystem : RedisM Unit := do
  Log.info "Example: Notification system"

  -- User-specific notification channels
  let user1Channel := "notify:user:101"
  let user2Channel := "notify:user:102"

  -- Broadcast channel for all users
  let broadcastChannel := "notify:broadcast"

  -- Send user-specific notifications
  let _ ← publish (α := String) user1Channel ("You have a new message" : String)
  Log.info "Sent notification to user 101"

  let _ ← publish (α := String) user2Channel ("Your order has shipped" : String)
  Log.info "Sent notification to user 102"

  -- Send broadcast notification
  let _ ← publish (α := String) broadcastChannel ("System maintenance at 2 AM" : String)
  Log.info "Sent broadcast notification"

/-- Example: Real-time chat simulation -/
def exChatSimulation : RedisM Unit := do
  Log.info "Example: Real-time chat simulation"

  let chatRoom := "chat:general"

  -- Simulate chat messages
  let messages : List (String × String) := [
    ("alice", "Hello everyone!"),
    ("bob", "Hi Alice!"),
    ("charlie", "Hey folks, what's up?"),
    ("alice", "Just working on some code"),
    ("bob", "Same here!")
  ]

  for (user, msg) in messages do
    let chatMessage := s!"\{\"user\":\"{user}\",\"message\":\"{msg}\"}"
    let _ ← publish (α := String) chatRoom (chatMessage : String)
    Log.info s!"[{user}]: {msg}"

/-- Example: Event-driven architecture -/
def exEventDriven : RedisM Unit := do
  Log.info "Example: Event-driven architecture"

  -- Domain event channels
  let orderChannel := "domain:orders"
  let inventoryChannel := "domain:inventory"
  let shippingChannel := "domain:shipping"

  -- Simulate order flow
  Log.info "Simulating order flow..."

  -- 1. Order created
  let _ ← publish (α := String) orderChannel ("{\"event\":\"OrderCreated\",\"orderId\":\"O-999\"}" : String)
  Log.info "  -> OrderCreated event published"

  -- 2. Inventory reserved (response to order)
  let _ ← publish (α := String) inventoryChannel ("{\"event\":\"InventoryReserved\",\"orderId\":\"O-999\"}" : String)
  Log.info "  -> InventoryReserved event published"

  -- 3. Shipping scheduled
  let _ ← publish (α := String) shippingChannel ("{\"event\":\"ShippingScheduled\",\"orderId\":\"O-999\"}" : String)
  Log.info "  -> ShippingScheduled event published"

  -- 4. Order completed
  let _ ← publish (α := String) orderChannel ("{\"event\":\"OrderCompleted\",\"orderId\":\"O-999\"}" : String)
  Log.info "  -> OrderCompleted event published"

/-- Example: Monitoring and metrics -/
def exMonitoringMetrics : RedisM Unit := do
  Log.info "Example: Monitoring and metrics"

  let metricsChannel := "metrics:app"

  -- Publish various metrics
  let metrics : List String := [
    "{\"metric\":\"cpu_usage\",\"value\":45.2,\"unit\":\"percent\"}",
    "{\"metric\":\"memory_usage\",\"value\":1024,\"unit\":\"MB\"}",
    "{\"metric\":\"request_count\",\"value\":1523,\"unit\":\"requests\"}",
    "{\"metric\":\"error_rate\",\"value\":0.5,\"unit\":\"percent\"}",
    "{\"metric\":\"latency_p99\",\"value\":120,\"unit\":\"ms\"}"
  ]

  for metric in metrics do
    let _ ← publish (α := String) metricsChannel (metric : String)

  Log.info s!"Published {metrics.length} metric events"

/-- Example: Cache invalidation via Pub/Sub -/
def exCacheInvalidation : RedisM Unit := do
  Log.info "Example: Cache invalidation via Pub/Sub"

  let invalidationChannel := "cache:invalidation"

  -- Publish cache invalidation events
  let _ ← publish (α := String) invalidationChannel ("{\"action\":\"invalidate\",\"key\":\"user:123:profile\"}" : String)
  Log.info "Published invalidation for user:123:profile"

  let _ ← publish (α := String) invalidationChannel ("{\"action\":\"invalidate_pattern\",\"pattern\":\"product:*\"}" : String)
  Log.info "Published pattern invalidation for product:*"

  let _ ← publish (α := String) invalidationChannel ("{\"action\":\"flush\",\"namespace\":\"session\"}" : String)
  Log.info "Published flush for session namespace"

/-- Run all pub/sub examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Redis Pub/Sub Examples ==="
  Log.info "(Note: Pub/Sub requires active subscribers to receive messages)"
  exBasicPublish
  exMultiChannelPublish
  exJsonPublish
  exNotificationSystem
  exChatSimulation
  exEventDriven
  exMonitoringMetrics
  exCacheInvalidation
  Log.info "=== Redis Pub/Sub Examples Complete ==="

end FeaturesPubSubExample
