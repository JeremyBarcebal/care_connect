import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Service class for managing prescription tasks in Firestore.
class TaskService {
  final FirebaseFirestore _firestore;

  /// Constructor that accepts a FirebaseFirestore instance for dependency injection.
  /// Defaults to [FirebaseFirestore.instance] if not provided.
  TaskService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Adds a prescription task for a patient on today's date.
  ///
  /// Parameters:
  /// - [patientId]: The UID of the patient receiving the prescription.
  /// - [title]: The name or description of the medicine/task.
  /// - [time]: The time the task should be completed (e.g., "09:00 AM").
  ///
  /// Throws an exception if the Firestore operation fails.
  Future<void> addPrescriptionTask(
    String patientId,
    String title,
    String time,
  ) async {
    String formattedDate = DateFormat('MM-dd-yyyy').format(DateTime.now());

    await _firestore
        .collection('accounts')
        .doc(patientId)
        .collection('task')
        .doc(formattedDate)
        .set({
      'tasks': FieldValue.arrayUnion([
        {'title': title, 'time': time, 'status': 'pending'}
      ])
    }, SetOptions(merge: true));
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
  Future<void> addPrescriptionTaskWithDuration(
    String patientId,
    String title,
    List<String> times,
    int days,
  ) async {
    final int totalDays = (days <= 0) ? 1 : days;

    for (int dayIndex = 0; dayIndex < totalDays; dayIndex++) {
      final DateTime date = DateTime.now().add(Duration(days: dayIndex));
      final String formattedDate = DateFormat('MM-dd-yyyy').format(date);

      // Create a task for each time in the times array
      for (final time in times) {
        await _firestore
            .collection('accounts')
            .doc(patientId)
            .collection('task')
            .doc(formattedDate)
            .set({
          'tasks': FieldValue.arrayUnion([
            {'title': title, 'time': time, 'status': 'pending'}
          ])
        }, SetOptions(merge: true));
      }
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

      await _firestore
          .collection('accounts')
          .doc(patientId)
          .collection('task')
          .doc(formattedDate)
          .set({
        'tasks': FieldValue.arrayUnion([
          {'title': title, 'time': time, 'status': 'pending'}
        ])
      }, SetOptions(merge: true));
    }
  }
}
