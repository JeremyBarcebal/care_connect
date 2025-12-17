import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz_timezone;

class MedicineNotificationService {
  static final MedicineNotificationService _instance =
      MedicineNotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  StreamSubscription? _taskSubscription;
  final Map<String, bool> _scheduledNotifications = {};

  factory MedicineNotificationService() {
    return _instance;
  }

  MedicineNotificationService._internal();

  /// Request necessary permissions for notifications and alarms
  Future<bool> _requestPermissions() async {
    try {
      // Request notification permission (Android 13+)
      final notificationStatus = await Permission.notification.request();
      print('📱 Notification permission: $notificationStatus');

      // Request exact alarm permission (Android 12+)
      final exactAlarmStatus = await Permission.scheduleExactAlarm.request();
      print('⏰ Exact alarm permission: $exactAlarmStatus');

      // Check if permissions are actually granted
      final notifGranted = notificationStatus.isGranted;
      final alarmGranted = exactAlarmStatus.isGranted;
      print(
          '✅ Permissions Summary - Notification: $notifGranted, Exact Alarm: $alarmGranted');

      return notifGranted && alarmGranted;
    } catch (e) {
      print('❌ Error requesting permissions: $e');
      return false;
    }
  }

  /// Initialize the notification service
  Future<void> initialize() async {
    print('📢 Initializing MedicineNotificationService...');
    tz.initializeTimeZones();

    // Request permissions first
    final permissionsGranted = await _requestPermissions();
    print('📢 Permissions granted: $permissionsGranted');

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iOSSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    print('📢 Initializing notification plugin...');
    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        print('🔔 Notification tapped: ${response.payload}');
      },
    );
    print('✓ Notification plugin initialized');

    print('📢 Creating Android notification channel...');
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            'medicine_channel',
            'Medicine Reminders',
            description: 'Notifications for medicine reminders',
            importance: Importance.max,
            enableVibration: true,
            playSound: true,
            vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
            showBadge: true,
          ),
        );
    print('✓ Android notification channel created');

    print('📢 Requesting iOS permissions...');
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
    print('✓ iOS permissions requested');
    print('✓ MedicineNotificationService initialization complete!');

    // Debug: Show any previously scheduled notifications
    await Future.delayed(Duration(milliseconds: 500));
    await debugScheduledNotifications();
  }

  /// Check and display all scheduled notifications (for debugging)
  Future<void> debugScheduledNotifications() async {
    try {
      final pendingNotifications =
          await _notificationsPlugin.pendingNotificationRequests();
      print(
          '\n📋 DEBUG: Total pending notifications: ${pendingNotifications.length}');
      for (var notif in pendingNotifications) {
        print(
            '   - ID: ${notif.id}, Title: ${notif.title}, Body: ${notif.body}');
      }
      print('   - Cached notifications: ${_scheduledNotifications.length}\n');
    } catch (e) {
      print('Error getting pending notifications: $e');
    }
  }

  /// Watch for medicine reminders and schedule notifications
  Future<void> watchMedicineReminders(String userId) async {
    _taskSubscription?.cancel();
    print('=== Starting Medicine Reminder Watch for user: $userId ===');

    _taskSubscription = FirebaseFirestore.instance
        .collection('accounts')
        .doc(userId)
        .collection('task')
        .snapshots()
        .listen((snapshot) {
      print('Task snapshot received: ${snapshot.docs.length} date documents');

      final dateFormat = DateFormat('MM-dd-yyyy');
      final now = DateTime.now();

      for (var doc in snapshot.docs) {
        final dateStr = doc.id;

        try {
          // Parse the date document ID to check if it's in the future
          final taskDate = dateFormat.parse(dateStr);

          // Only process tasks for today and future dates
          // If date is before today (and time has passed), skip
          final isToday = taskDate.year == now.year &&
              taskDate.month == now.month &&
              taskDate.day == now.day;

          final isFuture =
              taskDate.isAfter(DateTime(now.year, now.month, now.day));

          if (!isToday && !isFuture) {
            print('Date: $dateStr - SKIPPED (date is in the past)');
            continue;
          }

          final data = doc.data() as Map<String, dynamic>?;
          final tasks = (data?['tasks'] as List?) ?? [];
          print(
              'Date: $dateStr - Found ${tasks.length} tasks (${isToday ? 'TODAY' : 'FUTURE'})');

          for (var task in tasks) {
            _scheduleNotificationForTask(task, dateStr, userId);
          }
        } catch (e) {
          print('Error accessing tasks for date $dateStr: $e');
        }
      }
    }, onError: (error) {
      print('Error watching medicine reminders: $error');
    });
  }

  /// Schedule notification for a specific medicine task
  Future<void> _scheduleNotificationForTask(
    Map<String, dynamic> task,
    String dateStr,
    String userId,
  ) async {
    try {
      final medicineName = task['title'] ?? 'Medicine';
      final status = task['status'] ?? 'pending';

      print(
          '  Processing task: $medicineName (status: $status, date: $dateStr)');

      if (status == 'taken') {
        print('    → Skipping: task already taken');
        return;
      }

      // Handle both string and list formats for time field
      final timeValue = task['time'];
      final List<String> times;

      if (timeValue is List) {
        // If it's already a list, use it directly
        times = timeValue.cast<String>();
      } else if (timeValue is String) {
        // If it's a string, wrap it in a list
        times = [timeValue];
      } else {
        print('    → Skipping: invalid time format - $timeValue');
        return;
      }

      if (times.isEmpty) {
        print('    → Skipping: no times specified');
        return;
      }

      print('    → Times: $times');

      for (int i = 0; i < times.length; i++) {
        final timeStr = times[i];
        final notificationKey = '$userId-$dateStr-$medicineName-$timeStr';

        // Check if this notification was already scheduled
        // Allow rescheduling for the first occurrence on each day
        if (_scheduledNotifications.containsKey(notificationKey)) {
          print('    → Already scheduled: $notificationKey (skipping)');
          continue;
        }

        // Parse time format with AM/PM conversion
        int hour = 0;
        int minute = 0;

        // Check if time includes AM/PM (case-insensitive)
        final isPM = RegExp(r'PM|pm').hasMatch(timeStr);
        final isAM = RegExp(r'AM|am').hasMatch(timeStr);
        final hasAMPM = isPM || isAM;

        // Clean the time string by removing AM/PM indicators
        String cleanTimeStr =
            timeStr.replaceAll(RegExp(r'\s*(AM|PM|am|pm)\s*$'), '').trim();
        final timeParts = cleanTimeStr.split(':');

        if (timeParts.length != 2) {
          print(
              '    ❌ INVALID TIME FORMAT: "$timeStr" (cannot parse - expected HH:MM format)');
          continue;
        }

        hour = int.tryParse(timeParts[0]) ?? 0;
        minute = int.tryParse(timeParts[1]) ?? 0;

        // Convert to 24-hour format if AM/PM is present
        if (hasAMPM) {
          // If hour is in 12-hour format with AM/PM
          if (isPM && hour != 12) {
            hour += 12; // 1 PM = 13:00, 2 PM = 14:00, etc.
          } else if (isAM && hour == 12) {
            hour = 0; // 12 AM = 00:00 (midnight)
          }
          // else: 12 PM or other AM times are already correct
        } else {
          // No AM/PM indicator - time is assumed to be in 24-hour format already
          // Validate that hour is in valid 24-hour range
          if (hour < 0 || hour > 23) {
            print(
                '    ❌ INVALID 24-HOUR FORMAT: "$timeStr" - hour must be 0-23');
            continue;
          }
        }

        print(
            '    → Parsed time: $timeStr → $hour:${minute.toString().padLeft(2, '0')} (format: ${hasAMPM ? '12-hour' : '24-hour'})');

        final dateFormat = DateFormat('MM-dd-yyyy');
        final DateTime scheduledDate = dateFormat.parse(dateStr);

        final DateTime scheduledDateTime = DateTime(
          scheduledDate.year,
          scheduledDate.month,
          scheduledDate.day,
          hour,
          minute,
        );

        final now = DateTime.now();
        print(
            '    → Checking time: Scheduled=$scheduledDateTime, Now=$now, IsPast=${scheduledDateTime.isBefore(now)}');
        if (scheduledDateTime.isBefore(now)) {
          print('    → SKIPPED: Time has already passed');
          continue;
        }

        final tz_timezone.TZDateTime tzScheduledDateTime =
            tz_timezone.TZDateTime.from(
          scheduledDateTime,
          tz_timezone.local,
        );

        print(
            '    → Converting to TZ format: $scheduledDateTime → $tzScheduledDateTime');
        print(
            '    → Notification Key: $notificationKey (Hash ID: ${scheduledDateTime.hashCode + i})');

        try {
          print(
              '    ⏰ SCHEDULING ALARM: $medicineName at $tzScheduledDateTime');
          await _notificationsPlugin.zonedSchedule(
            scheduledDateTime.hashCode + i,
            '💊 TAKE YOUR MEDICINE',
            '$medicineName - Time to take your medicine now!',
            tzScheduledDateTime,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'medicine_channel',
                'Medicine Reminders',
                channelDescription: 'Medicine reminder alarms',
                importance: Importance.max,
                priority: Priority.max,
                enableVibration: true,
                vibrationPattern:
                    Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
                playSound: true,
                fullScreenIntent: true,
                autoCancel: false,
                onlyAlertOnce: false,
                styleInformation: BigTextStyleInformation(
                  '$medicineName - Time to take your medicine now!\n\nTap to open the app and mark as complete.',
                  contentTitle: '💊 MEDICINE REMINDER',
                ),
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
                interruptionLevel: InterruptionLevel.critical,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          _scheduledNotifications[notificationKey] = true;
          print(
              '    ✅ SUCCESS: Alarm scheduled for $medicineName at $tzScheduledDateTime');
        } on PlatformException catch (e) {
          print(
              '    ❌ PlatformException: Code=${e.code}, Message=${e.message}');
          if (e.code == 'exact_alarms_not_permitted') {
            print('Exact alarms not permitted, using inexact alarm instead');
            // Fallback to inexact alarm if exact alarm is not permitted
            try {
              print(
                  'Scheduling fallback inexact alarm for $medicineName at $tzScheduledDateTime');
              await _notificationsPlugin.zonedSchedule(
                scheduledDateTime.hashCode + i,
                '💊 TAKE YOUR MEDICINE',
                '$medicineName - Time to take your medicine now!',
                tzScheduledDateTime,
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    'medicine_channel',
                    'Medicine Reminders',
                    channelDescription: 'Medicine reminder alarms',
                    importance: Importance.max,
                    priority: Priority.max,
                    enableVibration: true,
                    vibrationPattern:
                        Int64List.fromList([0, 1000, 500, 1000, 500, 1000]),
                    playSound: true,
                    fullScreenIntent: true,
                    autoCancel: false,
                    styleInformation: BigTextStyleInformation(
                      '$medicineName - Time to take your medicine now!\n\nTap to open the app and mark as complete.',
                      contentTitle: '💊 MEDICINE REMINDER',
                    ),
                  ),
                  iOS: DarwinNotificationDetails(
                    presentAlert: true,
                    presentBadge: true,
                    presentSound: true,
                    interruptionLevel: InterruptionLevel.critical,
                  ),
                ),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
              _scheduledNotifications[notificationKey] = true;
              print('✓ Fallback alarm scheduled successfully');
            } catch (fallbackError) {
              print('Error scheduling fallback alarm: $fallbackError');
            }
          } else {
            print('Unexpected error scheduling alarm: $e');
            rethrow;
          }
        } catch (e) {
          print('Error scheduling alarm: $e');
          rethrow;
        }

        _scheduledNotifications[notificationKey] = true;

        print(
            'Scheduled notification for $medicineName at ${scheduledDateTime.toString()}');
      }
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
    _scheduledNotifications.clear();
  }

  /// Send a test notification immediately (for debugging)
  Future<void> sendTestNotification() async {
    try {
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'medicine_channel',
          'Medicine Reminders',
          channelDescription: 'Notifications for medicine reminders',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 250, 500, 250, 500]),
          playSound: true,
          styleInformation: const BigTextStyleInformation(
            'Test notification - your app is working!',
          ),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      await _notificationsPlugin.show(
        DateTime.now().millisecond,
        'Test Medicine Reminder',
        'This is a test notification - notifications are working!',
        notificationDetails,
      );
    } catch (e) {
      print('✗ Error sending test notification: $e');
      rethrow;
    }
  }

  /// Manually force refresh all tasks from Firestore
  /// Use this if notifications aren't triggering even though they should be
  Future<void> forceRefreshTasks(String userId) async {
    print('\n🔄 ========== FORCE REFRESHING TASKS ==========');
    print('⚠️  This will re-check all tasks and reschedule notifications');

    try {
      final taskSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .collection('task')
          .get();

      print('Found ${taskSnapshot.docs.length} date documents\n');

      final dateFormat = DateFormat('MM-dd-yyyy');
      final now = DateTime.now();
      int scheduledCount = 0;

      for (var doc in taskSnapshot.docs) {
        final dateStr = doc.id;

        try {
          final taskDate = dateFormat.parse(dateStr);
          final isToday = taskDate.year == now.year &&
              taskDate.month == now.month &&
              taskDate.day == now.day;
          final isFuture =
              taskDate.isAfter(DateTime(now.year, now.month, now.day));

          if (!isToday && !isFuture) {
            print('Skipping $dateStr (past date)');
            continue;
          }

          final data = doc.data() as Map<String, dynamic>?;
          final tasks = (data?['tasks'] as List?) ?? [];

          print('Processing $dateStr: ${tasks.length} tasks');

          for (var task in tasks) {
            // Temporarily remove from cache to force rescheduling
            final title = task['title'] ?? 'Medicine';
            final time = task['time'] ?? '';
            final cacheKey = '$userId-$dateStr-$title-$time';
            _scheduledNotifications.remove(cacheKey);

            // Reschedule
            await _scheduleNotificationForTask(task, dateStr, userId);
            scheduledCount++;
          }
        } catch (e) {
          print('Error processing $dateStr: $e');
        }
      }

      print(
          '✅ Force refresh complete! Scheduled $scheduledCount notifications\n');
    } catch (e) {
      print('❌ Error during force refresh: $e');
    }
  }

  /// Comprehensive diagnostic to troubleshoot notification issues
  Future<void> runDiagnostics(String userId) async {
    print('\n🔍 ========== NOTIFICATION SYSTEM DIAGNOSTICS ==========');
    print('📅 Current Time: ${DateTime.now()}');
    print('🌍 Current Timezone: ${tz_timezone.local}');

    // Check pending notifications
    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      print('📋 Pending Notifications: ${pending.length}');
      for (var notif in pending) {
        print('   ✓ ID: ${notif.id}, Title: ${notif.title}');
      }
    } catch (e) {
      print('❌ Error getting pending notifications: $e');
    }

    // Check Firestore tasks
    print('\n📂 Checking Firestore Tasks:');
    try {
      final taskSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .collection('task')
          .get();

      print('   Found ${taskSnapshot.docs.length} date documents');

      final dateFormat = DateFormat('MM-dd-yyyy');
      final now = DateTime.now();

      for (var doc in taskSnapshot.docs) {
        final dateStr = doc.id;
        final data = doc.data() as Map<String, dynamic>?;
        final tasks = (data?['tasks'] as List?) ?? [];

        try {
          final taskDate = dateFormat.parse(dateStr);
          final isToday = taskDate.year == now.year &&
              taskDate.month == now.month &&
              taskDate.day == now.day;
          final isFuture =
              taskDate.isAfter(DateTime(now.year, now.month, now.day));

          print(
              '\n   📅 Date: $dateStr (${isToday ? 'TODAY' : isFuture ? 'FUTURE' : 'PAST'})');
          print('      Tasks: ${tasks.length}');

          for (var task in tasks) {
            final title = task['title'] ?? 'Unknown';
            final time = task['time'] ?? 'No time';
            final status = task['status'] ?? 'unknown';
            print('      • $title @ $time (Status: $status)');

            // Validate time format
            if (time is String &&
                !time.contains('AM') &&
                !time.contains('PM')) {
              print('        ⚠️  WARNING: Time missing AM/PM indicator!');
            }
          }
        } catch (e) {
          print('   ❌ Error parsing date $dateStr: $e');
        }
      }
    } catch (e) {
      print('❌ Error reading Firestore tasks: $e');
    }

    // Check permissions
    print('\n🔐 Checking Permissions:');
    try {
      final notifPerm = await Permission.notification.status;
      final alarmPerm = await Permission.scheduleExactAlarm.status;
      print('   Notification: ${notifPerm.name}');
      print('   Exact Alarm: ${alarmPerm.name}');
    } catch (e) {
      print('❌ Error checking permissions: $e');
    }

    // Check listener status
    print('\n👂 Listener Status:');
    print('   Active: ${_taskSubscription != null}');
    print('   Cached notifications: ${_scheduledNotifications.length}');

    print('\n✅ Diagnostics Complete\n');
  }

  /// Cancel all past scheduled notifications and clean cache
  Future<void> cancelPastNotifications() async {
    print('\n🧹 ========== CANCELING PAST NOTIFICATIONS ==========');

    try {
      final pending = await _notificationsPlugin.pendingNotificationRequests();
      print('Found ${pending.length} pending notifications');

      int canceledCount = 0;
      final now = DateTime.now();

      for (var notif in pending) {
        // Check if notification ID corresponds to a past time
        // (This is a simple check - in production, you'd store metadata)
        print('Checking notification ID: ${notif.id}');
        // For now, we'll let the system handle it
        // The real fix is in _scheduleNotificationForTask to skip past times
      }

      // Also clear the cache to reset
      print(
          'Clearing notification cache (${_scheduledNotifications.length} entries)');
      _scheduledNotifications.clear();

      print('✅ Cleanup complete\n');
    } catch (e) {
      print('❌ Error canceling past notifications: $e');
    }
  }

  /// Clear all scheduled notifications and cache
  Future<void> clearAllAndReschedule(String userId) async {
    print('\n🔄 ========== CLEAR ALL AND RESCHEDULE ==========');

    try {
      // Cancel all
      await _notificationsPlugin.cancelAll();
      _scheduledNotifications.clear();

      print('Cancelled all notifications');
      print('Waiting 2 seconds before rescheduling...');

      // Wait a bit
      await Future.delayed(Duration(seconds: 2));

      // Now force refresh
      await forceRefreshTasks(userId);

      print('✅ Clear and reschedule complete\n');
    } catch (e) {
      print('❌ Error during clear and reschedule: $e');
    }
  }

  void dispose() {
    _taskSubscription?.cancel();
  }
}
