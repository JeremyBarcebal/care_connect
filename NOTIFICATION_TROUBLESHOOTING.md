# Medicine Notification Troubleshooting Guide

## Why Notifications Aren't Showing

If you're not seeing medicine notifications pop up, follow these steps to diagnose the issue:

---

## Step 1: Check App Logs

Run the app and open Flutter console/logcat. Look for these logs:

### ✅ Successful Setup
```
📢 Initializing MedicineNotificationService...
📢 Permissions granted: true
📢 Initializing notification plugin...
✓ Notification plugin initialized
📢 Creating Android notification channel...
✓ Android notification channel created
📢 Requesting iOS permissions...
✓ iOS permissions requested
✓ MedicineNotificationService initialization complete!
```

### ✅ Watching Tasks
```
=== Starting Medicine Reminder Watch for user: {userId} ===
Task snapshot received: 15 date documents
Date: 12-17-2025 - Found 5 tasks
```

### ✅ Processing Tasks
```
Processing task: neizep (status: pending, date: 12-17-2025)
→ Times: ["12:35 PM"]
→ Parsed time: 12:35 PM → 12:35
→ Checking time: Scheduled=2025-12-17 12:35:00.000, Now=2025-12-17 11:30:00.000, IsPast=false
Scheduling notification for neizep at 2025-12-17 12:35:00.000
✓ Notification scheduled successfully for neizep at 2025-12-17 12:35:00.000
```

### ❌ If You See These Errors

**Error: `exact_alarms_not_permitted`**
```
Exact alarms not permitted, using inexact alarm instead
Scheduling fallback inexact notification for neizep at 2025-12-17 12:35:00.000
✓ Fallback notification scheduled successfully
```
→ **Solution:** This is OK! Notifications will still work, just slightly less precise.

**Error: `Permission denied`**
```
NotificationPermission: false
ExactAlarmPermission: false
```
→ **Solution:** See Step 2 below

**Error: `Task snapshot not received`**
```
Error watching medicine reminders: {error}
```
→ **Solution:** Check Firestore rules and data

---

## Step 2: Check Notification Permissions

### Android 13+ (API 33+)

1. Go to **Settings → Apps → Care Connect**
2. Tap **Notifications**
3. Toggle **Allow notifications** ✅

If still not working:
1. Go to **Settings → Apps → Care Connect → Permissions**
2. Enable **Schedule exact alarms** ✅
3. Enable **Nearby devices** ✅

### Android 12 (API 31-32)

1. Go to **Settings → Apps → Care Connect**
2. Tap **Permissions**
3. Enable **Schedule exact alarms** ✅

### iOS

1. Go to **Settings → Care Connect**
2. Enable **Notifications** ✅
3. Select **Alerts, Sounds, Badges** ✅

---

## Step 3: Check Device Time

Notifications are scheduled for a specific time. If your device time is wrong, they won't fire.

**Check:**
1. Go to **Settings → Date & Time**
2. Ensure **Automatic time** is enabled ✅
3. Check timezone is correct ✅

**Example:**
- You accept medicine at "12:35 PM" for today (12-17-2025)
- Device time: 11:30 AM ✓ (notification will fire in 1 hour)
- Device time: 12:36 PM ✗ (time has passed, notification skipped)
- Device time: 12-18-2025 ✗ (wrong date, notification skipped)

---

## Step 4: Check Firestore Data

Verify your medicine task exists in the correct format:

**Path:** `accounts/{userId}/task/12-17-2025`

**Required Fields:**
```
{
  tasks: [
    {
      title: "neizep",              ✅ Required - medicine name
      time: "12:35 PM",             ✅ Required - time in HH:MM AM/PM format
      status: "pending",            ✅ Required - must be "pending" (not "taken")
      dosage: "1",
      frequency: "Once daily",
      duration: "30",
      type: "Tablet",
      remarks: ""
    }
  ]
}
```

**Common Issues:**
- ❌ `time: "12:35"` (missing AM/PM) → May not parse correctly
- ❌ `time: "2:35 PM"` (missing leading zero) → Should still work, but be careful
- ❌ `status: "taken"` → Task is skipped automatically
- ❌ `status: "completed"` → Task is skipped (only "pending" works)
- ❌ Missing date document → No tasks loaded

---

## Step 5: Test End-to-End

### Scenario 1: Immediate Notification (Test)
1. Create prescription with time **5 minutes from now**
2. Patient accepts prescription
3. Wait 5 minutes
4. **Notification should appear!**

If it doesn't appear:
→ Go back to Step 1 and check logs for errors

### Scenario 2: Check Notification Center

Even if notification didn't show as full-screen:
1. Go to **Settings → Notifications → Care Connect**
2. Look for notification in history

Or check recent notifications:
- **Android:** Swipe down from top → Look for "Time to take your medicine"
- **iOS:** Swipe left from top → Look for notifications

---

## Step 6: Check Service Restart

The notification service is initialized in `ClientPage`.

**Verify it's being called:**
1. Look for logs starting with `📢 Initializing MedicineNotificationService...`
2. If not present, service didn't initialize

**Solution:** Make sure you're logged in and on the patient (client) side, not doctor side.

---

## Common Causes & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| No logs about initialization | Service not running | Restart app, ensure logged in as patient |
| Logs show "Permissions granted: false" | Notification permission denied | Enable in Settings → Notifications |
| Logs show "Time has already passed" | Device time is in future | Check device date/time settings |
| Logs show "Status is not pending" | Medicine marked as taken | Check Firestore status field |
| Logs show "No times specified" | Time field missing | Verify Firestore data has `time` field |
| Logs show "Invalid time format" | Wrong time format | Must be "HH:MM AM/PM" like "09:00 AM" |
| No logs at all | App not seeing tasks | Check if patient UID is correct in Firestore |

---

## Debug Commands

### Check if service is watching (in browser console):

```dart
// This shows active subscriptions
adb logcat | grep "Medicine Reminder Watch"
```

### Create test prescription:

From doctor side:
1. Select patient
2. Create prescription
3. Set time to exactly 2 minutes from now
4. Set date to today
5. Patient accepts

### Monitor logs in real-time:

```bash
adb logcat | grep "flutter"
```

---

## Advanced: Check Task Service

Tasks are created by `TaskService` when prescription is accepted.

**Location:** `lib/pages/doctor/task_service.dart`

If notification service is watching but no tasks appear:
1. Check if `TaskService.addPrescriptionTaskWithDuration()` is being called
2. Check Firestore: Is the task document created?
3. Check date format: Should be "MM-dd-yyyy" like "12-17-2025"

---

## Performance Considerations

If you accept **many prescriptions at once**:
- Multiple notifications may queue
- They will all fire at their respective times
- Notifications are cached by key to prevent duplicates

**Example:**
```
Medicine 1: 09:00 AM → Fires at 09:00
Medicine 2: 09:00 AM → Fires at 09:00 (different medicine)
Medicine 3: 02:00 PM → Fires at 02:00
Medicine 4: 02:00 PM → Fires at 02:00
```

Each gets its own notification ID based on:
```
notificationKey = "$userId-$dateStr-$medicineName-$timeStr"
```

---

## Testing Timeline

Recommended test progression:

| Time | Action | Expected Result |
|------|--------|-----------------|
| T+0 | Patient accepts prescription for T+10 | Task created in Firestore |
| T+2 | Service reads task | Logs show "Processing task..." |
| T+5 | Check device | Should see notification scheduled in logs |
| T+10 | Wait for notification | 🔔 Notification pops up! |
| T+11 | Patient marks taken | Status changes to "taken" |
| T+12 | Next day, same medicine | New task, new notification scheduled |

---

## Reset & Restart

If nothing works, try complete restart:

1. **Uninstall app**
   ```bash
   adb uninstall com.example.care_connect
   ```

2. **Clear Firestore cache** (optional)
   ```dart
   await FirebaseFirestore.instance.clearPersistence();
   ```

3. **Reinstall and test**

---

## Still Not Working?

Collect this information and create an issue:

1. **Logs:** Paste full Flutter console output starting from app launch
2. **Firestore data:** Screenshot of task document structure
3. **Device info:** Android version, device model, app version
4. **Time:** Current device time when testing
5. **Permission status:** Screenshot of notification settings

Then refer to the logs to narrow down the issue.

---

**Last Updated:** December 17, 2025
**Status:** All debugging enhancements implemented ✅
