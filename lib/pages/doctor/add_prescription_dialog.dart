import 'package:flutter/material.dart';
import 'task_service.dart';

class AddPrescriptionDialog extends StatefulWidget {
  final TaskService taskService;

  const AddPrescriptionDialog({required this.taskService});

  @override
  _AddPrescriptionDialogState createState() => _AddPrescriptionDialogState();
}

class _AddPrescriptionDialogState extends State<AddPrescriptionDialog> {
  final _formKey = GlobalKey<FormState>();
  String _patientId = '';
  String _medicineName = '';
  String _time = '';
  bool _isLoading = false;

  /// Validates and submits the form
  void _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      await widget.taskService.addPrescriptionTask(
        _patientId,
        _medicineName,
        _time,
      );

      if (!mounted) return;

      Navigator.pop(context, true); // Close dialog and indicate success
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription added successfully!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Prescription'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Patient ID input field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Patient ID',
                  hintText: 'Enter patient unique ID',
                  prefixIcon: Icon(Icons.person),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Patient ID is required';
                  }
                  return null;
                },
                onSaved: (value) => _patientId = value ?? '',
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
              const SizedBox(height: 16),

              // Time input field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Time',
                  hintText: 'e.g., 09:00 AM, 02:30 PM',
                  prefixIcon: Icon(Icons.access_time),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Time is required';
                  }
                  // Simple validation for time format
                  if (!RegExp(r'^\d{1,2}:\d{2}\s?(AM|PM|am|pm)$')
                      .hasMatch(value)) {
                    return 'Use format: HH:MM AM/PM';
                  }
                  return null;
                },
                onSaved: (value) => _time = value ?? '',
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        // Submit button
        ElevatedButton(
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add Prescription'),
        ),
      ],
    );
  }
}
