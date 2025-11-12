import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:care_connect/pages/doctor/task_service.dart';

// Type options
const List<String> medicineTypes = [
  'Tablet',
  'Capsule',
  'Syrup',
  'Injection',
  'Drops',
  'Cream/Ointment',
  'Inhaler',
  'Patch',
];

// Frequency options
const List<String> frequencyOptions = [
  'Once daily',
  'Twice daily',
  'Three times daily',
  'Four times daily',
  'Every 4 hours',
  'Every 6 hours',
  'Every 8 hours',
  'Every 12 hours',
  'Before meals',
  'After meals',
  'At bedtime',
  'As needed',
  'Weekly',
];

// Duration options (in days)
const List<Map<String, dynamic>> durationOptions = [
  {'label': '3 days', 'days': 3},
  {'label': '5 days', 'days': 5},
  {'label': '1 week', 'days': 7},
  {'label': '2 weeks', 'days': 14},
  {'label': '3 weeks', 'days': 21},
  {'label': '1 month', 'days': 30},
  {'label': '2 months', 'days': 60},
  {'label': '3 months', 'days': 90},
  {'label': '6 months', 'days': 180},
  {'label': 'Ongoing', 'days': 365},
  {'label': 'As needed', 'days': 0},
];

class MedicineEntry {
  String medicineName;
  String type;
  String dosage;
  List<String> times; // Changed to list for multiple times
  String frequency;
  int duration; // in days
  String remarks;

  MedicineEntry({
    this.medicineName = '',
    this.type = 'Tablet',
    this.dosage = '',
    List<String>? times,
    this.frequency = 'Once daily',
    this.duration = 30,
    this.remarks = '',
  }) : times = times ?? [''];

  /// Get number of times per day based on frequency
  int getTimesPerDay() {
    switch (frequency) {
      case 'Once daily':
        return 1;
      case 'Twice daily':
        return 2;
      case 'Three times daily':
        return 3;
      case 'Four times daily':
        return 4;
      case 'Every 4 hours':
        return 6; // 24 / 4 = 6 times
      case 'Every 6 hours':
        return 4; // 24 / 6 = 4 times
      case 'Every 8 hours':
        return 3; // 24 / 8 = 3 times
      case 'Every 12 hours':
        return 2; // 24 / 12 = 2 times
      default:
        return 1;
    }
  }

  /// Get interval in hours for time-based frequencies
  int? getIntervalHours() {
    switch (frequency) {
      case 'Every 4 hours':
        return 4;
      case 'Every 6 hours':
        return 6;
      case 'Every 8 hours':
        return 8;
      case 'Every 12 hours':
        return 12;
      default:
        return null;
    }
  }

  /// Calculate time based on first time and interval
  String calculateTime(int index) {
    if (index == 0 || times.isEmpty || times[0].isEmpty) {
      return '';
    }

    final intervalHours = getIntervalHours();
    if (intervalHours == null) {
      return '';
    }

    try {
      // Parse first time
      final firstTimeStr = times[0];
      final parts = firstTimeStr.split(':');
      if (parts.length < 2) return '';

      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1].split(' ')[0]);
      final isPM = firstTimeStr.contains('PM');

      // Convert to 24-hour format
      if (isPM && hour != 12) {
        hour += 12;
      } else if (!isPM && hour == 12) {
        hour = 0;
      }

      // Add interval hours
      hour += (intervalHours * index);
      hour = hour % 24; // Wrap around if exceeds 24 hours

      // Convert back to 12-hour format
      final finalPM = hour >= 12;
      final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
      final period = finalPM ? 'PM' : 'AM';

      final timeStr =
          '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
      return timeStr;
    } catch (e) {
      return '';
    }
  }
}

class AddPrescriptionPage extends StatefulWidget {
  final TaskService taskService;
  final String? patientId;
  final String? patientName;
  final String? chatDocumentId; // Add chat document ID

  const AddPrescriptionPage({
    Key? key,
    required this.taskService,
    this.patientId,
    this.patientName,
    this.chatDocumentId,
  }) : super(key: key);

  @override
  _AddPrescriptionPageState createState() => _AddPrescriptionPageState();
}

class _AddPrescriptionPageState extends State<AddPrescriptionPage> {
  late String _patientId;
  late String _patientName;
  List<MedicineEntry> _medicines = [MedicineEntry()];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _patientId = widget.patientId ?? '';
    _patientName = widget.patientName ?? '';
  }

  void _addMedicine() {
    setState(() {
      _medicines.add(MedicineEntry());
    });
  }

  void _removeMedicine(int index) {
    if (_medicines.length > 1) {
      setState(() {
        _medicines.removeAt(index);
      });
    }
  }

  Future<void> _submitForm() async {
    // Validate all medicines
    for (var med in _medicines) {
      if (med.medicineName.isEmpty ||
          med.dosage.isEmpty ||
          med.frequency.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill all medicine details'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // For times validation, check if at least the first time is filled
      // For interval-based frequencies, other times are auto-calculated
      if (med.times.isEmpty || med.times[0].isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in the time'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // For non-interval frequencies, validate all times are filled
      final intervalHours = med.getIntervalHours();
      if (intervalHours == null) {
        // Not interval-based, check all times
        if (med.times.any((t) => t.isEmpty)) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please fill all time fields'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
      }
    }

    if (_patientId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Patient ID is required'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (widget.chatDocumentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chat session not found'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Populate auto-calculated times before sending
      for (var med in _medicines) {
        final timesPerDay = med.getTimesPerDay();
        for (int i = 0; i < timesPerDay; i++) {
          if (med.times.length <= i) {
            med.times.add('');
          }
          if (i > 0 && med.times[i].isEmpty) {
            // For interval-based frequencies, calculate the time
            final calculatedTime = med.calculateTime(i);
            if (calculatedTime.isNotEmpty) {
              med.times[i] = calculatedTime;
            }
          }
        }
      }

      // Send prescription message to chat
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatDocumentId)
          .collection('convo')
          .add({
        'type': 'prescription',
        'patientId': _patientId,
        'patientName': _patientName,
        'medicines': _medicines
            .map((med) => {
                  'medicineName': med.medicineName,
                  'type': med.type,
                  'dosage': med.dosage,
                  'times': med.times,
                  'frequency': med.frequency,
                  'duration': med.duration,
                  'remarks': med.remarks,
                })
            .toList(),
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
        'sender': FirebaseAuth.instance.currentUser?.uid,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Prescription sent to patient!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  TimeOfDay _parseTimeOfDay(String timeString) {
    if (timeString.isEmpty) {
      return TimeOfDay.now();
    }
    try {
      final parts = timeString.split(':');
      if (parts.length == 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1].split(' ')[0]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      // Ignore parsing errors
    }
    return TimeOfDay.now();
  }

  void _showPreview() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prescription Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Patient: $_patientName',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Patient ID: $_patientId'),
              const SizedBox(height: 16),
              const Text('Medications:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              ..._medicines.asMap().entries.map((e) {
                final med = e.value;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${e.key + 1}. ${med.medicineName}'),
                      Text('   Type: ${med.type}'),
                      Text('   Dosage: ${med.dosage}'),
                      Text('   Times: ${med.times.join(", ")}'),
                      Text('   Frequency: ${med.frequency}'),
                      Text('   Duration: ${med.duration} days'),
                      if (med.remarks.isNotEmpty)
                        Text('   Remarks: ${med.remarks}'),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Prescription'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Patient Info (Auto-filled)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Patient Information',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('Name: $_patientName',
                      style: const TextStyle(fontSize: 12)),
                  Text('ID: $_patientId', style: const TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Medications Section
            const Text(
              'Medications',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // Medicine entries
            ..._medicines.asMap().entries.map((e) {
              final index = e.key;
              final med = e.value;
              return _buildMedicineCard(index, med);
            }).toList(),

            const SizedBox(height: 16),

            // Add New Medicine Button
            ElevatedButton.icon(
              onPressed: _addMedicine,
              icon: const Icon(Icons.add),
              label: const Text('Add New Medicine'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),

            const SizedBox(height: 24),

            // Preview Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _medicines.isNotEmpty ? _showPreview : null,
                icon: const Icon(Icons.preview),
                label: const Text('Preview Prescription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text(
                        'Schedule Prescription',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicineCard(int index, MedicineEntry medicine) {
    final timesPerDay = medicine.getTimesPerDay();
    // Ensure times list has the correct number of entries
    while (medicine.times.length < timesPerDay) {
      medicine.times.add('');
    }
    if (medicine.times.length > timesPerDay) {
      medicine.times = medicine.times.sublist(0, timesPerDay);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Medicine ${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                if (_medicines.length > 1)
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _removeMedicine(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            // Medicine Name
            TextFormField(
              initialValue: medicine.medicineName,
              decoration: InputDecoration(
                labelText: 'Medicine Name',
                hintText: 'e.g., Amlodipine 5mg',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              onChanged: (value) => medicine.medicineName = value,
            ),
            const SizedBox(height: 12),
            // Type and Dosage in row
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<String>(
                    value: medicine.type,
                    decoration: InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                    ),
                    items: medicineTypes
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child:
                                  Text(type, overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => medicine.type = value);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    initialValue: medicine.dosage,
                    decoration: InputDecoration(
                      labelText: 'Dosage',
                      hintText: 'e.g., 1 tablet, 5ml',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                    ),
                    onChanged: (value) => medicine.dosage = value,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Frequency Dropdown (NOW COMES BEFORE TIME)
            DropdownButtonFormField<String>(
              value: medicine.frequency,
              decoration: InputDecoration(
                labelText: 'Frequency',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              items: frequencyOptions
                  .map((freq) => DropdownMenuItem(
                        value: freq,
                        child: Text(freq),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    medicine.frequency = value;
                    // Update times list based on new frequency
                    final newCount = medicine.getTimesPerDay();
                    while (medicine.times.length < newCount) {
                      medicine.times.add('');
                    }
                    if (medicine.times.length > newCount) {
                      medicine.times = medicine.times.sublist(0, newCount);
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            // Dynamic Time Fields based on Frequency
            Text(
              'Time${timesPerDay > 1 ? 's' : ''}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(timesPerDay, (timeIndex) {
              final isIntervalBased = medicine.getIntervalHours() != null;
              final displayTime = isIntervalBased && timeIndex > 0
                  ? medicine.calculateTime(timeIndex)
                  : medicine.times[timeIndex];

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () async {
                    // For interval-based frequencies, only allow editing the first time
                    if (isIntervalBased && timeIndex > 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Times auto-calculate based on first time. Edit first time to change all.'),
                          backgroundColor: Colors.blue,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    final TimeOfDay? pickedTime = await showTimePicker(
                      context: context,
                      initialTime: _parseTimeOfDay(displayTime),
                    );
                    if (pickedTime != null) {
                      setState(() {
                        // Format time with AM/PM using 12-hour format
                        final hour = pickedTime.hour;
                        final minute = pickedTime.minute;
                        final displayHour =
                            hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
                        final period = hour >= 12 ? 'PM' : 'AM';
                        final formattedTime =
                            '${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
                        medicine.times[timeIndex] = formattedTime;
                      });
                    }
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: isIntervalBased && timeIndex > 0
                              ? Colors.grey.shade300
                              : Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayTime.isEmpty
                                    ? 'Select Time ${timeIndex + 1}'
                                    : displayTime,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: displayTime.isEmpty
                                      ? Colors.grey[600]
                                      : (isIntervalBased && timeIndex > 0
                                          ? Colors.grey[700]
                                          : Colors.black),
                                  fontWeight: isIntervalBased && timeIndex > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                              ),
                              if (displayTime.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: displayTime.contains('AM')
                                          ? Colors.blue.shade100
                                          : Colors.orange.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      displayTime.contains('AM') ? 'AM' : 'PM',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: displayTime.contains('AM')
                                            ? Colors.blue
                                            : Colors.orange,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Icon(
                          isIntervalBased && timeIndex > 0
                              ? Icons.lock
                              : Icons.access_time,
                          size: 18,
                          color: isIntervalBased && timeIndex > 0
                              ? Colors.grey
                              : Colors.green,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
            const SizedBox(height: 12),
            // Duration Dropdown
            DropdownButtonFormField<int>(
              value: medicine.duration,
              decoration: InputDecoration(
                labelText: 'Duration',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              items: durationOptions
                  .map((dur) => DropdownMenuItem<int>(
                        value: dur['days'] as int,
                        child: Text(dur['label'] as String),
                      ))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => medicine.duration = value);
                }
              },
            ),
            const SizedBox(height: 12),
            // Remarks
            TextFormField(
              initialValue: medicine.remarks,
              decoration: InputDecoration(
                labelText: 'Remarks (Optional)',
                hintText: 'e.g., Take after breakfast',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              maxLines: 2,
              onChanged: (value) => medicine.remarks = value,
            ),
          ],
        ),
      ),
    );
  }
}
