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
      for (var doc in snapshot.docs) {
        final dateStr = doc.id;
        try {
          final data = doc.data() as Map<String, dynamic>?;
          final tasks = (data?['tasks'] as List?) ?? [];
          print('Date: $dateStr - Found ${tasks.length} tasks');

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

        // Don't skip if already scheduled - allow rescheduling for all days
        // This ensures notifications trigger on all scheduled dates (e.g., 3 days = Dec 17, 18, 19)

        // Parse time format with AM/PM conversion
        int hour = 0;
        int minute = 0;

        // Check if time includes AM/PM
        final isPM = RegExp(r'PM|pm').hasMatch(timeStr);
        final isAM = RegExp(r'AM|am').hasMatch(timeStr);

        String cleanTimeStr =
            timeStr.replaceAll(RegExp(r'\s+(AM|PM|am|pm)$'), '').trim();
        final timeParts = cleanTimeStr.split(':');
        if (timeParts.length != 2) {
          print(
              '    ❌ INVALID TIME FORMAT: "$timeStr" (cannot parse - expected HH:MM format)');
          continue;
        }

        hour = int.tryParse(timeParts[0]) ?? 0;
        minute = int.tryParse(timeParts[1]) ?? 0;

        // Convert to 24-hour format if AM/PM is present
        if (isPM && hour != 12) {
          hour += 12; // 1 PM = 13:00, 2 PM = 14:00, etc.
        } else if (isAM && hour == 12) {
          hour = 0; // 12 AM = 00:00
        }

        print(
            '    → Parsed time: $timeStr → $hour:${minute.toString().padLeft(2, '0')}');

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
              '    ⏰ SCHEDULING NOTIFICATION: $medicineName at $tzScheduledDateTime');
          await _notificationsPlugin.zonedSchedule(
            scheduledDateTime.hashCode + i,
            'Time to take your medicine',
            'Take $medicineName now',
            tzScheduledDateTime,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'medicine_channel',
                'Medicine Reminders',
                channelDescription: 'Notifications for medicine reminders',
                importance: Importance.max,
                priority: Priority.high,
                enableVibration: true,
                vibrationPattern:
                    Int64List.fromList([0, 500, 250, 500, 250, 500]),
                playSound: true,
                fullScreenIntent: true,
                styleInformation:
                    BigTextStyleInformation('Take $medicineName now'),
              ),
              iOS: DarwinNotificationDetails(
                presentAlert: true,
                presentBadge: true,
                presentSound: true,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.alarmClock,
            uiLocalNotificationDateInterpretation:
                UILocalNotificationDateInterpretation.absoluteTime,
          );
          _scheduledNotifications[notificationKey] = true;
          print(
              '    ✅ SUCCESS: Notification scheduled for $medicineName at $tzScheduledDateTime');
        } on PlatformException catch (e) {
          print(
              '    ❌ PlatformException: Code=${e.code}, Message=${e.message}');
          if (e.code == 'exact_alarms_not_permitted') {
            print('Exact alarms not permitted, using inexact alarm instead');
            // Fallback to inexact alarm if exact alarm is not permitted
            try {
              print(
                  'Scheduling fallback inexact notification for $medicineName at $tzScheduledDateTime');
              await _notificationsPlugin.zonedSchedule(
                scheduledDateTime.hashCode + i,
                'Time to take your medicine',
                'Take $medicineName now',
                tzScheduledDateTime,
                NotificationDetails(
                  android: AndroidNotificationDetails(
                    'medicine_channel',
                    'Medicine Reminders',
                    channelDescription: 'Notifications for medicine reminders',
                    importance: Importance.max,
                    priority: Priority.high,
                    enableVibration: true,
                    vibrationPattern:
                        Int64List.fromList([0, 500, 250, 500, 250, 500]),
                    playSound: true,
                    styleInformation:
                        BigTextStyleInformation('Take $medicineName now'),
                  ),
                  iOS: DarwinNotificationDetails(
                    presentAlert: true,
                    presentBadge: true,
                    presentSound: true,
                  ),
                ),
                androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
                uiLocalNotificationDateInterpretation:
                    UILocalNotificationDateInterpretation.absoluteTime,
              );
              _scheduledNotifications[notificationKey] = true;
              print('✓ Fallback notification scheduled successfully');
            } catch (fallbackError) {
              print('Error scheduling fallback notification: $fallbackError');
            }
          } else {
            print('Unexpected error scheduling notification: $e');
            rethrow;
          }
        } catch (e) {
          print('Error scheduling notification: $e');
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

  void dispose() {
    _taskSubscription?.cancel();
  }
}
