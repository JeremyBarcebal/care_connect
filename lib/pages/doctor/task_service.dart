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
}
