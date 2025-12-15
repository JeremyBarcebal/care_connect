
//     Summary of the Flow:
//         1. initializePushNotifications() runs once at app startup to set up listeners and get the unique FCM Token.
//         2. The backend stores this Token.
//         3. When an event (like a new message) occurs, the backend sends a message to the Token via the FCM service.
//         4. The Flutter app receives the message and triggers the showImmediateNotification() function in your 
//            notification_service.dart file to make the notification pop up on the screen.



import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/material.dart';

/// The global plugin instance used to interact with the device's notification system.
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Initializes the notification settings and registers channels/permissions.
Future<void> initializeNotifications() async {
  // Initialize timezone data, required for scheduling future notifications.
  tz.initializeTimeZones();

  // 1. Define platform-specific settings (Android: app icon, iOS: permissions).
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher'); //app icon

  const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    iOS: initializationSettingsIOS,
  );

  // 2. Initialize the plugin and define the tap handler.
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse:
        (NotificationResponse notificationResponse) async {
      if (notificationResponse.payload != null) {
        debugPrint(
            'Notification tapped with payload: ${notificationResponse.payload}');
      }
    },
  );

  // 3. Register notification channels (Mandatory for Android 8.0+).
  final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
      flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidImplementation != null) {
    // --- CHANNEL 1: GENERAL ALERTS (For Appointments, Medicine Reminders, etc.) ---
    const AndroidNotificationChannel generalChannel =
        AndroidNotificationChannel(
      'care_connect_channel', // Channel ID for non-urgent reminders
      'App Reminders and General Alerts', // User-visible name
      description: 'Notifications for appointments, medication reminders, and general status updates.',
      importance: Importance.max,
    );

    // --- CHANNEL 2: MESSAGING (For Urgent, Real-time Communication) ---
    const AndroidNotificationChannel messagingChannel =
        AndroidNotificationChannel(
      'messaging_channel', // Dedicated ID for urgent messages
      'Urgent Messages', // User-visible name
      description: 'Notifications for new messages from your doctor or care team.',
      importance: Importance.high, // Use HIGH importance to ensure delivery
    );

    // Register both channels with the Android OS
    await androidImplementation.createNotificationChannel(generalChannel);
    await androidImplementation.createNotificationChannel(messagingChannel);
    debugPrint('Android Notification Channels created (General, Messaging).');
    
  }

  // 4. Request explicit permissions for iOS/macOS.
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
}

/// Displays an immediate, non-scheduled notification.
/// This is typically called when the app is in the foreground
/// and receives a push notification (FCM) payload, usually for messages.
Future<void> showImmediateNotification({
  required String title,
  required String body,
  String? payload,
}) async {
  // --- USES THE HIGH-PRIORITY MESSAGING CHANNEL ---
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'messaging_channel', // Use the dedicated messaging channel ID
    'Urgent Messages',
    channelDescription: 'Notifications for new messages from your doctor or care team.',
    importance: Importance.high,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  // The '0' is the notification ID. Use unique IDs for different pop-ups.
  await flutterLocalNotificationsPlugin.show(
    0, 
    title,
    body,
    platformDetails,
    payload: payload,
  );
}

/// Schedules a time-zone-aware notification for a future date/time.
/// This is used for reminders (e.g., appointments, medication).
Future<void> zonedScheduleNotification({
  required int id,
  required String title,
  required String body,
  required DateTime scheduledTime,
  String? payload,
}) async {
  // --- USES THE GENERAL ALERTS CHANNEL ---
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'care_connect_channel', // Use the general channel ID
    'App Reminders and General Alerts',
    channelDescription: 'Notifications for appointments, medication reminders, and general status updates.',
    importance: Importance.max,
    priority: Priority.high,
  );

  const NotificationDetails platformDetails =
      NotificationDetails(android: androidDetails);

  await flutterLocalNotificationsPlugin.zonedSchedule(
    id, // Unique ID for this specific scheduled reminder
    title,
    body,
    // Convert the scheduled time to a time-zone-aware object
    tz.TZDateTime.from(scheduledTime, tz.local),
    platformDetails,
    payload: payload,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
    matchDateTimeComponents: DateTimeComponents.dateAndTime,
  );
}





