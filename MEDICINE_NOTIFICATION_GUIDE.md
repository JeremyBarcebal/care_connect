# Medicine Notification System - Complete Guide

## Overview
The medicine notification system automatically sends notifications to patients when it's time to take their prescribed medicines. It's fully integrated into the Care Connect app and works seamlessly in the background.

## System Architecture

### 1. **Notification Service** (`MedicineNotificationService`)
**Location:** `lib/services/medicine_notification_service.dart`

The service:
- Monitors Firestore for medicine tasks for the logged-in patient
- Automatically schedules local notifications for each medicine at the prescribed time
- Uses device-level alarms (Android: AlarmClock, iOS: Local Notifications)
- Handles permissions and notification channels
- Caches scheduled notifications to prevent duplicates

### 2. **Initialization Flow**
The service is initialized in `lib/pages/client_page.dart`:

```dart
// In ClientPage initState():
_medicineNotificationService = MedicineNotificationService();
await _medicineNotificationService.initialize();
await _medicineNotificationService.watchMedicineReminders(userId);
```

This happens automatically when a patient opens the app.

### 3. **Data Structure**
Medicine tasks are stored in Firestore under:
```
accounts/{userId}/task/{dateKey}
  └── tasks: [
      {
        title: "Aspirin",
        status: "pending" | "taken",
        time: ["09:00 AM", "09:00 PM"],  // Can be single string or array
        // ... other fields
      }
    ]
```

## How Notifications Work

### Step 1: Medicine Task Created
When a doctor sends a prescription and the patient accepts it, a medicine task is created in Firestore with:
- Medicine name
- Dosage and frequency
- Scheduled times (e.g., "09:00 AM", "02:00 PM")
- Date
- Status: "pending"

### Step 2: Service Watches for Changes
The `MedicineNotificationService.watchMedicineReminders()` continuously monitors the patient's task collection.

When a new task arrives or the collection changes:
1. Service reads all tasks for the current date and future dates
2. Skips tasks with status = "taken"
3. Schedules a local notification for each time

### Step 3: Notification Triggered
When the scheduled time arrives (e.g., 09:00 AM):
- **Android:** Shows full-screen notification with vibration and sound
- **iOS:** Shows alert notification with badge
- **Payload:** Contains medicine name and reminder text

Notification appears as:
```
📱 NOTIFICATION
├── Title: "Time to take your medicine"
├── Message: "Take Aspirin now"
└── Sound: Enabled, Vibration: Enabled
```

### Step 4: Patient Interaction
Patient can:
- **Tap notification** → Opens app (handled by `onDidReceiveNotificationResponse`)
- **Mark as taken** → Goes to TaskPage and marks task status as "taken"
- **Dismiss** → Notification closes (no action needed)

## Features

### ✅ Auto-Rescheduling
- If a medicine time has passed, it's automatically skipped
- Future times are scheduled
- No manual rescheduling needed

### ✅ Multi-Time Support
Medicines with multiple times per day:
```dart
time: ["09:00 AM", "02:00 PM", "09:00 PM"]
// Three separate notifications scheduled
```

### ✅ Permission Handling
Automatically requests and handles:
- Notification permission (Android 13+)
- Exact alarm permission (Android 12+)
- iOS alert, badge, sound permissions

### ✅ Fallback Mechanism
If exact alarms aren't permitted:
- Automatically falls back to inexact alarms
- Still delivers notifications on time (with slight variance)

### ✅ Duplicate Prevention
Uses a map `_scheduledNotifications` to track scheduled times:
```dart
notificationKey = "$userId-$dateStr-$medicineName-$timeStr"
// Prevents scheduling the same notification twice
```

## Integration Points

### 1. **App Launch** (`client_page.dart`)
```dart
void initState() {
  _initializeMedicineNotifications();
}

Future<void> _initializeMedicineNotifications() async {
  final userId = _auth.currentUser?.uid;
  _medicineNotificationService = MedicineNotificationService();
  await _medicineNotificationService.initialize();
  await _medicineNotificationService.watchMedicineReminders(userId);
}
```

### 2. **Prescription Acceptance** (in `chat_page.dart`)
When patient accepts prescription → Task created → Service auto-schedules notification

### 3. **TaskPage Display** (`task_page.dart`)
Shows all medicines for selected date with status indicators:
- 🟢 "pending" - Not taken yet
- 🟢 "taken" - Completed
- Time display: "09:00 AM"

## Testing the Notification System

### 1. **Create a Test Prescription**
```
Doctor: Select patient → Create prescription
Prescription:
  - Medicine: "Test Medicine"
  - Time: "09:00 AM" (set to 2 minutes from now for testing)
  - Date: Today
  - Duration: 1 day
```

### 2. **Patient Accepts**
- Patient receives notification in chat
- Clicks "Accept"
- Task is created in Firestore

### 3. **Wait for Notification**
- At the scheduled time, full-screen notification appears
- Device shows: "Time to take your medicine - Take Test Medicine now"

### 4. **Mark as Taken**
- Patient goes to TaskPage
- Clicks on the medicine
- Marks status as "taken"
- Task no longer appears in notifications

## Notification Payload

```dart
NotificationDetails(
  android: AndroidNotificationDetails(
    'medicine_channel',          // Channel ID
    'Medicine Reminders',        // Channel name
    importance: Importance.max,  // Max priority
    priority: Priority.high,     // High priority
    enableVibration: true,       // Vibrate on notify
    vibrationPattern: [0, 500, 250, 500],
    playSound: true,             // Play sound
    fullScreenIntent: true,      // Full-screen on Android
    styleInformation: BigTextStyleInformation('Take $medicineName now'),
  ),
  iOS: DarwinNotificationDetails(
    presentAlert: true,          // Show alert
    presentBadge: true,          // Show badge
    presentSound: true,          // Play sound
  ),
)
```

## Debugging

### Check Logs
```
I/flutter: =  === Starting Medicine Reminder Watch for user: {userId} ===
I/flutter: Task snapshot received: X date documents
I/flutter: Date: MM-dd-yyyy - Found Y tasks
I/flutter: Processing task: Medicine Name (status: pending, date: MM-dd-yyyy)
I/flutter: Scheduling notification for Medicine Name at {dateTime}
I/flutter: ✓ Notification scheduled successfully
```

### Verify Firestore Data
```
Firestore Path: accounts/{patientId}/task/{dateKey}/tasks
Expected Structure:
{
  "title": "Aspirin",
  "status": "pending",
  "time": ["09:00 AM", "02:00 PM"],
  "dosage": "500mg",
  "frequency": "Twice a day"
}
```

### Common Issues

| Issue | Solution |
|-------|----------|
| No notifications | 1. Check notification permission<br>2. Verify task exists in Firestore<br>3. Check if status is "taken"<br>4. Verify time format (HH:MM AM/PM) |
| Notifications not at right time | Check system time is correct on device |
| Duplicate notifications | Service uses cache to prevent, check service restart |
| Permission denied | Manually enable in Settings → Notifications |

## File Locations

| Component | File |
|-----------|------|
| Service | `lib/services/medicine_notification_service.dart` |
| Initialization | `lib/pages/client_page.dart` |
| Task Display | `lib/pages/client/task_page.dart` |
| Task Service | `lib/pages/doctor/task_service.dart` |
| Chat Integration | `lib/pages/client/chat_page.dart` |

## Next Steps

To further enhance the notification system:

1. **Add Snooze Feature** - Let patients snooze notification for 5/10/15 minutes
2. **Add Medication History** - Track when medicines were taken
3. **Add Recurring Prescriptions** - Auto-renew daily prescriptions
4. **Add Do Not Disturb** - Let patients set quiet hours
5. **Add Notification Actions** - Quick "Mark Taken" button in notification
6. **Add Sound Selection** - Let patients choose notification sound

---

**Status:** ✅ Fully Implemented and Active
**Tested On:** Android 12+, iOS 14+
**Last Updated:** December 17, 2025
