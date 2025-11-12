import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Service class for managing prescription tasks in Firestore.
class TaskService {
  final FirebaseFirestore _firestore;

  /// Constructor that accepts a FirebaseFirestore instance for dependency injection.
  /// Defaults to [FirebaseFirestore.instance] if not provided.
  TaskService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final Random _random = Random();

  String _generateTaskId() {
    return '${DateTime.now().microsecondsSinceEpoch}_${_random.nextInt(1 << 32)}';
  }

  /// Adds a prescription task for a patient on today's date.
  ///
  /// Parameters:
  /// - [patientId]: The UID of the patient receiving the prescription.
  /// - [title]: The name or description of the medicine/task.
  /// - [time]: The time the task should be completed (e.g., "09:00 AM").
  /// - [medicineData]: Optional map containing prescription details (type, dosage, frequency, duration, remarks)
  ///
  /// Throws an exception if the Firestore operation fails.
  Future<void> addPrescriptionTask(
    String patientId,
    String title,
    String time, {
    Map<String, dynamic>? medicineData,
  }) async {
    try {
      String formattedDate = DateFormat('MM-dd-yyyy').format(DateTime.now());

      final taskData = {
        'taskId': _generateTaskId(),
        'title': title.toString(),
        'time': time.toString(),
        'status': 'pending',
        if (medicineData != null)
          ...medicineData
              .map((key, value) => MapEntry(key, value?.toString() ?? '')),
      };

      print('TaskService.addPrescriptionTask:');
      print('  Patient ID: $patientId');
      print('  Date: $formattedDate');
      print('  Title: $title');
      print('  Time: $time');
      print('  Task Data: $taskData');

      await _firestore
          .collection('accounts')
          .doc(patientId)
          .collection('task')
          .doc(formattedDate)
          .set({
        'tasks': FieldValue.arrayUnion([taskData])
      }, SetOptions(merge: true));

      print('  ✓ Task created successfully');
    } catch (e) {
      print('  ✗ Error creating task: $e');
      rethrow;
    }
  }

  /// Adds a prescription task for a patient repeated for [days] days.
  ///
  /// This will create a task entry for each day starting from today and
  /// continuing for [days] days. For each day, a task is created for each
  /// time in the [times] array. Each day's document id is formatted as
  /// MM-dd-yyyy.
  ///
  /// Parameters:
  /// - [patientId]: The UID of the patient
  /// - [title]: The name/description of the medicine
  /// - [times]: List of times (e.g., ["07:30 AM", "11:30 AM", "03:30 PM"])
  /// - [days]: Number of days to create tasks for
  /// - [medicineData]: Optional map containing prescription details (type, dosage, frequency, duration, remarks)
  Future<void> addPrescriptionTaskWithDuration(
    String patientId,
    String title,
    List<String> times,
    int days, {
    Map<String, dynamic>? medicineData,
  }) async {
    try {
      final int totalDays = (days <= 0) ? 1 : days;

      print('TaskService.addPrescriptionTaskWithDuration:');
      print('  Patient ID: $patientId');
      print('  Medicine Title: $title');
      print('  Number of times: ${times.length}');
      print('  Times: $times');
      print('  Duration: $totalDays days');
      print(
          '  Starting from: ${DateFormat('MM-dd-yyyy').format(DateTime.now())}');

      for (int dayIndex = 0; dayIndex < totalDays; dayIndex++) {
        final DateTime date = DateTime.now().add(Duration(days: dayIndex));
        final String formattedDate = DateFormat('MM-dd-yyyy').format(date);

        // Create a task for each time in the times array
        for (final time in times) {
          final taskData = {
            'taskId': _generateTaskId(),
            'title': title.toString(),
            'time': time.toString(),
            'status': 'pending',
            if (medicineData != null)
              ...medicineData
                  .map((key, value) => MapEntry(key, value?.toString() ?? '')),
          };

          print(
              '  Creating task for $formattedDate at $time (id: ${taskData['taskId']})');

          await _firestore
              .collection('accounts')
              .doc(patientId)
              .collection('task')
              .doc(formattedDate)
              .set({
            'tasks': FieldValue.arrayUnion([taskData])
          }, SetOptions(merge: true));
        }
      }
      print('  ✓ All tasks created successfully');
    } catch (e) {
      print('  ✗ Error creating tasks: $e');
      rethrow;
    }
  }

  /// Marks a task as complete by taskId for a given patient and date document.
  Future<void> markTaskComplete(
      String patientId, String formattedDate, String taskId) async {
    final docRef = _firestore
        .collection('accounts')
        .doc(patientId)
        .collection('task')
        .doc(formattedDate);

    try {
      await _firestore.runTransaction((tx) async {
        final snapshot = await tx.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Task document not found');
        }

        final data = snapshot.data();
        final tasks = List<Map<String, dynamic>>.from(
            (data?['tasks'] as List<dynamic>? ?? [])
                .map((e) => Map<String, dynamic>.from(e)));

        var changed = false;
        for (var i = 0; i < tasks.length; i++) {
          final t = tasks[i];
          if (t['taskId'] == taskId) {
            tasks[i] = {...t, 'status': 'completed'};
            changed = true;
            break;
          }
        }

        if (!changed) {
          throw Exception('Task with id $taskId not found');
        }

        tx.update(docRef, {'tasks': tasks});
      });
      print(
          'TaskService.markTaskComplete: task $taskId marked completed for $patientId/$formattedDate');
    } catch (e) {
      print('TaskService.markTaskComplete failed: $e');
      rethrow;
    }
  }

  /// Legacy method - kept for backward compatibility
  /// Adds a single task for each day for [weeks] weeks with a single time
  @deprecated
  Future<void> addPrescriptionTaskWithDurationLegacy(
    String patientId,
    String title,
    String time,
    int weeks,
  ) async {
    final int totalDays = (weeks <= 0) ? 1 : weeks * 7;

    for (int i = 0; i < totalDays; i++) {
      final DateTime date = DateTime.now().add(Duration(days: i));
      final String formattedDate = DateFormat('MM-dd-yyyy').format(date);

      final taskData = {
        'taskId': _generateTaskId(),
        'title': title,
        'time': time,
        'status': 'pending',
      };

      await _firestore
          .collection('accounts')
          .doc(patientId)
          .collection('task')
          .doc(formattedDate)
          .set({
        'tasks': FieldValue.arrayUnion([taskData])
      }, SetOptions(merge: true));
    }
  }
}
