import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:cloud_firestore/cloud_firestore.dart';

class SchedulePage extends StatefulWidget {
  final DateTime date;
  final String patientUID;
  SchedulePage({required this.date, required this.patientUID});

  @override
  _SchedulePageState createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final _notif = FlutterLocalNotificationsPlugin();
  List<Map<String, dynamic>> medicines = [];

  @override
  void initState() {
    super.initState();
    _initNotif();
    _loadMedicines(widget.patientUID);
  }

  void _initNotif() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notif.initialize(initSettings);
    // Initialize timezone database - use local timezone by default
    tz.initializeTimeZones();
  }

  void _loadMedicines(String patientUID) async {
    final formattedDate = DateFormat('MM-dd-yyyy').format(widget.date);
    final snap = await FirebaseFirestore.instance
        .collection('accounts')
        .doc(patientUID)
        .collection('task')
        .doc(formattedDate)
        .get();

    if (snap.exists && snap.data() != null) {
      final data = snap.data() as Map<String, dynamic>?;
      final tasksList = (data?['tasks'] as List<dynamic>?) ?? [];
      setState(() {
        medicines = List<Map<String, dynamic>>.from(tasksList);
      });
    }
  }

  void _scheduleNotifications() {
    for (var med in medicines) {
      for (String time in med['time']) {
        final parts = time.split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);

        final scheduled = DateTime(
          widget.date.year,
          widget.date.month,
          widget.date.day,
          hour,
          minute,
        );

        final tzScheduled = tz.TZDateTime.from(scheduled, tz.local);

        _notif.zonedSchedule(
          scheduled.hashCode,
          'Medicine Reminder',
          'Time to take ${med['name']}',
          tzScheduled,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'med_channel',
              'Medicine Reminders',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.alarmClock,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      }
    }
  }

  void _markAsDone(int index) async {
    setState(() => medicines[index]['done'] = true);
    // Update Firestore status
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Schedule for ${widget.date.toLocal()}')),
      body: ListView.builder(
        itemCount: medicines.length,
        itemBuilder: (context, i) {
          final med = medicines[i];
          return ListTile(
            title: Text(med['name']),
            subtitle: Text('Time: ${med['time'].join(', ')}'),
            trailing: IconButton(
              icon: Icon(
                med['done'] ? Icons.check_circle : Icons.alarm,
                color: med['done'] ? Colors.green : Colors.grey,
              ),
              onPressed: () => _markAsDone(i),
            ),
          );
        },
      ),
    );
  }
}
