import 'package:flutter/material.dart';
import 'package:care_connect/models/prescription_message.dart';

/// Dialog for doctors to send prescriptions through chat.
/// Auto-populates patient info based on the current chat context.
class SendPrescriptionDialog extends StatefulWidget {
  final String patientId;
  final String patientName;
  final Function(PrescriptionMessage) onSend;

  const SendPrescriptionDialog({
    required this.patientId,
    required this.patientName,
    required this.onSend,
  });

  @override
  _SendPrescriptionDialogState createState() => _SendPrescriptionDialogState();
}

class _SendPrescriptionDialogState extends State<SendPrescriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  late String _medicineName;
  late String _dosage;
  late String _frequency;
  late String _instructions;
  late String _time;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Send Prescription'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Patient info display (auto-filled)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Patient Information (Auto-filled)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Name: ${widget.patientName}'),
                    Text('ID: ${widget.patientId}'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Medicine name input field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Medicine Name',
                  hintText: 'e.g., Aspirin, Paracetamol',
                  prefixIcon: Icon(Icons.local_pharmacy),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Medicine name is required';
                  }
                  return null;
                },
                onSaved: (value) => _medicineName = value ?? '',
              ),
              const SizedBox(height: 12),

              // Dosage input field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Dosage',
                  hintText: 'e.g., 500mg, 2 tablets',
                  prefixIcon: Icon(Icons.medical_information),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Dosage is required';
                  }
                  return null;
                },
                onSaved: (value) => _dosage = value ?? '',
              ),
              const SizedBox(height: 12),

              // Frequency input field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Frequency',
                  hintText: 'e.g., Twice daily, Every 6 hours',
                  prefixIcon: Icon(Icons.schedule),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Frequency is required';
                  }
                  return null;
                },
                onSaved: (value) => _frequency = value ?? '',
              ),
              const SizedBox(height: 12),

              // Time input field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Preferred Time',
                  hintText: 'e.g., 09:00 AM, 02:30 PM',
                  prefixIcon: Icon(Icons.access_time),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Time is required';
                  }
                  if (!RegExp(r'^\d{1,2}:\d{2}\s?(AM|PM|am|pm)$')
                      .hasMatch(value)) {
                    return 'Use format: HH:MM AM/PM';
                  }
                  return null;
                },
                onSaved: (value) => _time = value ?? '',
              ),
              const SizedBox(height: 12),

              // Instructions input field
              TextFormField(
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Instructions (Optional)',
                  hintText: 'e.g., Take with food, Avoid dairy',
                  prefixIcon: Icon(Icons.notes),
                  border: OutlineInputBorder(),
                ),
                onSaved: (value) => _instructions = value ?? '',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send Prescription'),
        ),
      ],
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    // Create prescription message
    final prescription = PrescriptionMessage(
      medicineName: _medicineName,
      dosage: _dosage,
      frequency: _frequency,
      instructions: _instructions,
      time: _time,
      status: 'pending',
      patientId: widget.patientId,
      patientName: widget.patientName,
    );

    // Call the callback
    widget.onSend(prescription);

    // Close dialog
    Navigator.pop(context);
  }
}
