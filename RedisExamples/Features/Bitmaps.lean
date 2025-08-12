import RedisLean.Ops
import RedisLean.Log
import RedisLean.Monad

namespace FeaturesBitmapsExample

open Redis

/-!
# Redis Bitmaps Examples

Demonstrates Redis bitmap operations for:
- User activity tracking (daily active users)
- Feature flags
- Permission bits
- Efficient boolean storage
-/

/-- Example: Basic bitmap operations -/
def exBasicBitmap : RedisM Unit := do
  Log.info "Example: Basic bitmap operations"

  let key := "bitmap:basic"

  -- Set individual bits
  let _ ← setbit key 0 true
  let _ ← setbit key 2 true
  let _ ← setbit key 4 true
  Log.info "Set bits at positions 0, 2, 4"

  -- Get individual bits
  let bit0 ← getbit key 0
  let bit1 ← getbit key 1
  let bit2 ← getbit key 2

  Log.info s!"Bit at position 0: {bit0}"
  Log.info s!"Bit at position 1: {bit1}"
  Log.info s!"Bit at position 2: {bit2}"

  -- Count set bits
  let count ← bitcount key none none
  Log.info s!"Total bits set to 1: {count}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Daily active users tracking -/
def exDailyActiveUsers : RedisM Unit := do
  Log.info "Example: Daily active users tracking"

  let key := "dau:2024-01-15"

  -- Simulate users logging in (user IDs as bit positions)
  let activeUsers := [1, 5, 10, 15, 20, 100, 500, 1000]

  for userId in activeUsers do
    let _ ← setbit key userId true

  Log.info s!"Marked {activeUsers.length} users as active"

  -- Count daily active users
  let dauCount ← bitcount key none none
  Log.info s!"Daily Active Users: {dauCount}"

  -- Check if specific user was active
  let user10Active ← getbit key 10
  let user50Active ← getbit key 50

  Log.info s!"User 10 was active: {user10Active}"
  Log.info s!"User 50 was active: {user50Active}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Feature flags -/
def exFeatureFlags : RedisM Unit := do
  Log.info "Example: Feature flags"

  let key := "features:user:123"

  -- Define feature bit positions
  let darkModePos := 0
  let betaFeaturesPos := 1
  let notificationsPos := 2
  let premiumPos := 3
  let _analyticsPos := 4  -- Reserved for future use

  -- Set user's features
  let _ ← setbit key darkModePos true
  let _ ← setbit key notificationsPos true
  let _ ← setbit key premiumPos true

  Log.info "Feature flags set for user 123"

  -- Check features
  let hasDarkMode ← getbit key darkModePos
  let hasBeta ← getbit key betaFeaturesPos
  let hasNotifications ← getbit key notificationsPos
  let isPremium ← getbit key premiumPos

  Log.info "User features:"
  Log.info s!"  Dark mode: {hasDarkMode}"
  Log.info s!"  Beta features: {hasBeta}"
  Log.info s!"  Notifications: {hasNotifications}"
  Log.info s!"  Premium: {isPremium}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Tracking user actions -/
def exUserActionTracking : RedisM Unit := do
  Log.info "Example: Tracking user actions"

  let userId := "user:456"
  let actionsKey := s!"actions:{userId}"

  -- Define action bit positions
  let viewedProfilePos := 0
  let _editedSettingsPos := 1  -- Not used in this example
  let uploadedFilePos := 2
  let _sentMessagePos := 3     -- Not used in this example
  let completedTutorialPos := 4

  -- Mark actions as completed
  let _ ← setbit actionsKey viewedProfilePos true
  let _ ← setbit actionsKey uploadedFilePos true
  let _ ← setbit actionsKey completedTutorialPos true

  Log.info "Recorded user actions"

  -- Count completed actions
  let completedCount ← bitcount actionsKey none none
  Log.info s!"Completed actions: {completedCount}/5"

  -- Check onboarding completion
  let tutorial ← getbit actionsKey completedTutorialPos
  let profile ← getbit actionsKey viewedProfilePos
  let onboardingComplete := tutorial && profile

  Log.info s!"Onboarding complete: {onboardingComplete}"

  -- Cleanup
  let _ ← del [actionsKey]

/-- Example: Bitcount with range -/
def exBitcountRange : RedisM Unit := do
  Log.info "Example: Bitcount with byte range"

  let key := "bitmap:range"

  -- Set bits across multiple bytes
  -- Byte 0: bits 0-7
  -- Byte 1: bits 8-15
  -- Byte 2: bits 16-23

  let _ ← setbit key 0 true   -- byte 0
  let _ ← setbit key 3 true   -- byte 0
  let _ ← setbit key 7 true   -- byte 0
  let _ ← setbit key 8 true   -- byte 1
  let _ ← setbit key 15 true  -- byte 1
  let _ ← setbit key 16 true  -- byte 2
  let _ ← setbit key 23 true  -- byte 2

  -- Count all bits
  let totalCount ← bitcount key none none
  Log.info s!"Total bits set: {totalCount}"

  -- Count bits in byte 0 only
  let byte0Count ← bitcount key (some 0) (some 0)
  Log.info s!"Bits in byte 0: {byte0Count}"

  -- Count bits in bytes 0-1
  let bytes01Count ← bitcount key (some 0) (some 1)
  Log.info s!"Bits in bytes 0-1: {bytes01Count}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Space-efficient boolean storage -/
def exSpaceEfficient : RedisM Unit := do
  Log.info "Example: Space-efficient boolean storage"

  let key := "bitmap:efficient"

  -- Store 1000 boolean values
  let numValues := 1000
  Log.info s!"Storing {numValues} boolean values..."

  -- Set every 3rd value to true
  for i in List.range numValues do
    if i % 3 == 0 then
      let _ ← setbit key i true

  -- Count true values
  let trueCount ← bitcount key none none
  Log.info s!"True values: {trueCount}"
  Log.info s!"False values: {numValues - trueCount}"

  Log.info "Space comparison:"
  Log.info s!"  Bitmap: ~{(numValues + 7) / 8} bytes"
  Log.info s!"  Individual keys: ~{numValues * 10} bytes (estimated)"

  -- Cleanup
  let _ ← del [key]

/-- Example: Previous bit value -/
def exPreviousBitValue : RedisM Unit := do
  Log.info "Example: Getting previous bit value"

  let key := "bitmap:prev"

  -- SETBIT returns the previous value
  let prev1 ← setbit key 5 true
  Log.info s!"Set bit 5 to true, previous value: {prev1}"

  let prev2 ← setbit key 5 false
  Log.info s!"Set bit 5 to false, previous value: {prev2}"

  let prev3 ← setbit key 5 true
  Log.info s!"Set bit 5 to true again, previous value: {prev3}"

  -- Cleanup
  let _ ← del [key]

/-- Example: Attendance tracking -/
def exAttendanceTracking : RedisM Unit := do
  Log.info "Example: Attendance tracking"

  let meetingKey := "attendance:meeting:789"

  -- Simulate attendees joining (employee IDs)
  let attendees := [101, 102, 105, 110, 115, 120, 125]

  Log.info "Recording meeting attendance..."
  for empId in attendees do
    let _ ← setbit meetingKey empId true

  -- Get attendance count
  let attendanceCount ← bitcount meetingKey none none
  Log.info s!"Total attendees: {attendanceCount}"

  -- Check specific employees
  let emp102Present ← getbit meetingKey 102
  let emp103Present ← getbit meetingKey 103

  Log.info s!"Employee 102 attended: {emp102Present}"
  Log.info s!"Employee 103 attended: {emp103Present}"

  -- Cleanup
  let _ ← del [meetingKey]

/-- Run all bitmap examples -/
def runAllExamples : RedisM Unit := do
  Log.info "=== Redis Bitmaps Examples ==="
  exBasicBitmap
  exDailyActiveUsers
  exFeatureFlags
  exUserActionTracking
  exBitcountRange
  exSpaceEfficient
  exPreviousBitValue
  exAttendanceTracking
  Log.info "=== Redis Bitmaps Examples Complete ==="

end FeaturesBitmapsExample
