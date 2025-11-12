/// Model class for prescription messages sent in chat.
/// This allows doctors to send structured prescriptions that patients can accept or decline.
class PrescriptionMessage {
  final String medicineName;
  final String dosage; // e.g., "500mg", "2 tablets"
  final String frequency; // e.g., "Twice daily", "Every 6 hours"
  final String instructions; // Additional instructions
  final String time; // Preferred time to take (e.g., "09:00 AM")
  final String status; // 'pending', 'accepted', 'declined'
  final String patientId;
  final String patientName;

  PrescriptionMessage({
    required this.medicineName,
    required this.dosage,
    required this.frequency,
    required this.instructions,
    required this.time,
    required this.status,
    required this.patientId,
    required this.patientName,
  });

  /// Convert to Map for Firestore storage
  Map<String, dynamic> toMap() {
    return {
      'type': 'prescription', // Message type identifier
      'medicineName': medicineName,
      'dosage': dosage,
      'frequency': frequency,
      'instructions': instructions,
      'time': time,
      'status': status,
      'patientId': patientId,
      'patientName': patientName,
    };
  }

  /// Create PrescriptionMessage from Firestore data
  factory PrescriptionMessage.fromMap(Map<String, dynamic> data) {
    return PrescriptionMessage(
      medicineName: data['medicineName'] ?? '',
      dosage: data['dosage'] ?? '',
      frequency: data['frequency'] ?? '',
      instructions: data['instructions'] ?? '',
      time: data['time'] ?? '',
      status: data['status'] ?? 'pending',
      patientId: data['patientId'] ?? '',
      patientName: data['patientName'] ?? '',
    );
  }
}
