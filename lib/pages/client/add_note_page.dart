import 'package:care_connect/pages/client/note_list_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddNotePage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AddNotePage(this.userData, {super.key});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  final TextEditingController _noteController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  final Map<String, TextEditingController> _controllers = {
    'bodyTemperature': TextEditingController(),
    'painLocation': TextEditingController(),
    'painIntensity': TextEditingController(),
    'patientFeels': TextEditingController(),
    'onsetSymptoms': TextEditingController(),
    'currentMedication': TextEditingController(),
    'medicationPrescribe': TextEditingController(),
  };

  String? dropdownValue;
  List<Doctor> doctors = [];
  Map<String, dynamic>? selectedDoctorSchedules;
  String? selectedTimeSlot;
  String? selectedDateKey;

  @override
  void initState() {
    super.initState();
    // Fetch doctors here
    _fetchDoctors();
  }

  Future<void> _fetchDoctors() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('accounts')
          .where('type', isEqualTo: 'doctor')
          .get();
      setState(() {
        doctors =
            querySnapshot.docs.map((doc) => Doctor.fromFirestore(doc)).toList();
        // Set default dropdown value if there are doctors available
        if (doctors.isNotEmpty) {
          dropdownValue = doctors.first.id;
          _fetchDoctorSchedules(doctors.first.id);
        }
      });
    } catch (e) {
      print("Failed to fetch doctors: $e");
    }
  }

  Future<void> _fetchDoctorSchedules(String doctorId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('schedules')
          .where('doctorId', isEqualTo: doctorId)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          selectedDoctorSchedules =
              querySnapshot.docs.first.data() as Map<String, dynamic>;
          selectedTimeSlot = null;
          selectedDateKey = selectedDoctorSchedules?['dateKey'];
        });
      } else {
        setState(() {
          selectedDoctorSchedules = null;
          selectedTimeSlot = null;
          selectedDateKey = null;
        });
      }
    } catch (e) {
      print("Failed to fetch doctor schedules: $e");
    }
  }

  Future<void> _updateScheduleStatus(String doctorId, String dateKey,
      String timeSlot, String patientName) async {
    try {
      // Find the schedule document
      QuerySnapshot querySnapshot = await _firestore
          .collection('schedules')
          .where('doctorId', isEqualTo: doctorId)
          .where('dateKey', isEqualTo: dateKey)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        DocumentReference scheduleRef = querySnapshot.docs.first.reference;
        final scheduleData =
            querySnapshot.docs.first.data() as Map<String, dynamic>;
        final slots =
            List<Map<String, dynamic>>.from(scheduleData['slots'] ?? []);

        // Find and update the slot status
        for (int i = 0; i < slots.length; i++) {
          if (slots[i]['time'] == timeSlot) {
            slots[i]['status'] = 'booked';
            slots[i]['bookedBy'] = patientName;
            break;
          }
        }

        // Update the schedule in Firestore
        await scheduleRef.update({'slots': slots});
        print('Schedule updated: $timeSlot marked as booked by $patientName');
      }
    } catch (e) {
      print("Failed to update schedule status: $e");
    }
  }

  void saveNote() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _isLoading = true;

        // Find the selected doctor to get their name
        Doctor? selectedDoctor = doctors.firstWhere(
          (doctor) => doctor.id == dropdownValue,
          orElse: () => Doctor(id: '', name: 'Unknown Doctor', specialty: ''),
        );

        // Prepare the note data by gathering all controller values
        final Map<String, dynamic> noteData = {
          'bodyTemperature': _controllers['bodyTemperature']?.text,
          'painLocation': _controllers['painLocation']?.text,
          'painIntensity': _controllers['painIntensity']?.text,
          'patientFeels': _controllers['patientFeels']?.text,
          'onsetSymptoms': _controllers['onsetSymptoms']?.text,
          'currentMedication': _controllers['currentMedication']?.text,
          'medicationPrescribe': _controllers['medicationPrescribe']?.text,
          'assignedTo': dropdownValue,
          'doctorId': dropdownValue, // Add doctorId field for filtering
          'doctorName': selectedDoctor.name, // Add doctor name
          'clientName': widget.userData?['name'],
          'clientEmail': widget.userData?['email'],
          'clientMobileNo': widget.userData?['mobileNo'],
          'clientId': user.uid,
          'timestamp': Timestamp.now(),
          'selectedTimeSlot': selectedTimeSlot,
          'selectedDateKey': selectedDateKey,
        };

        // Save the note data to Firestore
        DocumentReference noteRef = await _firestore
            .collection('accounts')
            .doc(user.uid)
            .collection('notes')
            .add(noteData);

        // Get the note ID
        String noteId = noteRef.id;

        // Add a notification with the note ID
        await _firestore
            .collection('accounts')
            .doc(dropdownValue)
            .collection('notifications')
            .add({
          'name': widget.userData?['name'],
          'email': widget.userData?['email'],
          'mobileNo': widget.userData?['mobileNo'],
          'noteId': noteId, // Add the note ID here
          'message': widget.userData?['name'] + ' sent a consultation request',
          'type': 'consultation_request',
          'timestamp': Timestamp.now(),
          'isNew': true,
          'selectedTimeSlot': selectedTimeSlot,
          'selectedDateKey': selectedDateKey,
        });

        // Update the schedule status if a time slot was selected
        if (selectedTimeSlot != null &&
            selectedDateKey != null &&
            dropdownValue != null) {
          await _updateScheduleStatus(dropdownValue!, selectedDateKey!,
              selectedTimeSlot!, widget.userData?['name'] ?? 'Unknown Patient');
        }

        Navigator.pop(context); // Close the dialog after saving
      }
    } catch (e) {
      print("Failed to Health Assesment: $e");
    }
  }

  Widget _buildTextField(String key, String label,
      {bool obscureText = false, bool readOnly = false, VoidCallback? onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFF9ACBD0).withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: const Color(0xFF006A71).withOpacity(0.2), width: 0.5!),
      ),
      child: TextField(
        controller: _controllers[key],
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: Color.fromARGB(255, 12, 55, 52),
              fontWeight: FontWeight.w400,
              fontSize: 16),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildAvailableSlots() {
    if (selectedDoctorSchedules == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: const Text(
          'No available schedules for this doctor',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      );
    }

    final slots = (selectedDoctorSchedules?['slots'] as List<dynamic>?) ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Schedule: ${selectedDateKey ?? 'N/A'}',
            style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF006A71),
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: slots.map<Widget>((slot) {
              final time = slot['time'] as String? ?? 'N/A';
              final status = slot['status'] as String? ?? 'booked';
              final isAvailable = status == 'available';
              final isSelected = selectedTimeSlot == time;

              return GestureDetector(
                onTap: isAvailable
                    ? () {
                        setState(() {
                          selectedTimeSlot = isSelected ? null : time;
                        });
                      }
                    : null,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isAvailable
                        ? (isSelected
                            ? Colors.blue
                            : Colors.blue.withOpacity(0.1))
                        : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isAvailable ? Colors.blue : Colors.red,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      color: isAvailable
                          ? (isSelected ? Colors.white : Colors.blue)
                          : Colors.red,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF48A6A7),
        title: const Text(
          'Add Health Assessment Note',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Symptoms:',
                style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF006A71),
                    fontWeight: FontWeight.w500),
              ),
              _buildTextField('bodyTemperature', 'Body Temperature:'),
              const SizedBox(height: 5.0),
              _buildTextField('painLocation', 'Pain Location:'),
              const SizedBox(height: 5.0),
              _buildTextField('painIntensity', 'Pain Intensity:'),
              const SizedBox(height: 5.0),
              const Text("Patient's Description:",
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF006A71),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 5.0),
              _buildTextField('patientFeels', 'How the Patient Feels:'),
              const SizedBox(height: 5.0),
              _buildTextField('onsetSymptoms', 'Onset of Symptoms:'),
              const SizedBox(height: 5.0),
              const Text("Medications:",
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF006A71),
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 5.0),
              _buildTextField('currentMedication', 'Current Medications:'),
              const SizedBox(height: 5.0),
              _buildTextField('medicationPrescribe', 'Medication Prescribed:'),
              const SizedBox(height: 5.0),
              const Text("Assigned Doctor:",
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF006A71),
                      fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFF9ACBD0).withOpacity(0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: dropdownValue,
                    isExpanded: true,
                    icon: const Icon(Icons.arrow_drop_down),
                    items:
                        doctors.map<DropdownMenuItem<String>>((Doctor doctor) {
                      return DropdownMenuItem<String>(
                        value: doctor.id,
                        child: Text(doctor.name + ' - ' + doctor.specialty),
                      );
                    }).toList(),
                    onChanged: (String? newValue) {
                      setState(() {
                        dropdownValue = newValue;
                      });
                      if (newValue != null) {
                        _fetchDoctorSchedules(newValue);
                      }
                    },
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    style:
                        const TextStyle(color: Color.fromARGB(255, 2, 45, 49)),
                  ),
                ),
              ),
              const SizedBox(height: 12.0),
              _buildAvailableSlots(),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'Close',
                      style: TextStyle(
                        color: Color(0xFF006A71),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  _isLoading
                      ? const Center(
                          child: CircularProgressIndicator(),
                          widthFactor: 2.0,
                        )
                      : ElevatedButton(
                          onPressed: saveNote,
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              color: Color(0xFF006A71),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
