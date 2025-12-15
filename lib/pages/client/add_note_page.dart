

import 'package:care_connect/pages/client/note_list_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'SelectAppointmentPage.dart';
import 'package:intl/intl.dart';

class AddNotePage extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const AddNotePage(this.userData, {super.key});

  @override
  State<AddNotePage> createState() => _AddNotePageState();
}

class _AddNotePageState extends State<AddNotePage> {
  TextEditingController _appointmentController = TextEditingController();
  DateTime? selectedAppointment;

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

  @override
  void initState() {
    super.initState();
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
        if (doctors.isNotEmpty) {
          dropdownValue = doctors.first.id;
        }
      });
    } catch (e) {
      print("Failed to fetch doctors: $e");
    }
  }

  void saveNote() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        setState(() => _isLoading = true);

        Doctor? selectedDoctor = doctors.firstWhere(
          (doctor) => doctor.id == dropdownValue,
          orElse: () => Doctor(id: '', name: 'Unknown Doctor', specialty: ''),
        );

        final Map<String, dynamic> noteData = {
          'bodyTemperature': _controllers['bodyTemperature']?.text,
          'painLocation': _controllers['painLocation']?.text,
          'painIntensity': _controllers['painIntensity']?.text,
          'patientFeels': _controllers['patientFeels']?.text,
          'onsetSymptoms': _controllers['onsetSymptoms']?.text,
          'currentMedication': _controllers['currentMedication']?.text,
          'medicationPrescribe': _controllers['medicationPrescribe']?.text,
          'assignedTo': dropdownValue,
          'doctorId': dropdownValue,
          'doctorName': selectedDoctor.name,
          'clientName': widget.userData?['name'],
          'clientEmail': widget.userData?['email'],
          'clientId': user.uid,
          'timestamp': Timestamp.now(),
          'appointmentDateTime': selectedAppointment != null //<-- Added appointmentDateTime field
              ? Timestamp.fromDate(selectedAppointment!)
              : null,
        };

        DocumentReference noteRef = await _firestore
            .collection('accounts')
            .doc(user.uid)
            .collection('notes')
            .add(noteData);

        String noteId = noteRef.id;

        await _firestore
            .collection('accounts')
            .doc(dropdownValue)
            .collection('notifications')
            .add({
          'name': widget.userData?['name'],
          'email': widget.userData?['email'],
          'noteId': noteId,
          'message': widget.userData?['name'] + ' sent a consultation request',
          'type': 'consultation_request',
          'timestamp': Timestamp.now(),
          'isNew': true,
        });

        Navigator.pop(context);
      }
    } catch (e) {
      print("Failed to save Health Assessment: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }
// Appointment Date & Time 
  Widget _buildTextField(String key, String label,
      {bool obscureText = false,
      bool readOnly = false,
      VoidCallback? onTap,
      TextEditingController? controller,
      IconData? suffixIcon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFF9ACBD0).withOpacity(0.3),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
            color: const Color(0xFF006A71).withOpacity(0.2), width: 0.5),
      ),
      child: TextField(
        controller: controller ?? _controllers[key],
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
              color: Color.fromARGB(255, 52, 51, 51),
              fontWeight: FontWeight.w400,
              fontSize: 12),
          border: InputBorder.none,
          suffixIcon: suffixIcon != null
              ? Icon(suffixIcon, color: const Color(0xFF006A71))
              : null,
        ),
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
            fontWeight: FontWeight.w400,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Symptoms:',
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF006A71),
                      fontWeight: FontWeight.w500)),
              _buildTextField('bodyTemperature', 'Body Temperature:'),
              _buildTextField('painLocation', 'Pain Location:'),
              _buildTextField('painIntensity', 'Pain Intensity:'),
              const Text("Patient's Description:",
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF006A71),
                      fontWeight: FontWeight.w500)),
              _buildTextField('patientFeels', 'How the Patient Feels:'),
              _buildTextField('onsetSymptoms', 'Onset of Symptoms:'),
              const Text("Medications:",
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF006A71),
                      fontWeight: FontWeight.w500)),
              _buildTextField('currentMedication', 'Current Medications:'),
              _buildTextField('medicationPrescribe', 'Medication Prescribed:'),
              const SizedBox(height: 10),
              const Text("Assigned Doctor:",
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF006A71),
                      fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: Color(0xFF9ACBD0).withOpacity(0.1),
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
                    },
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    style:
                        const TextStyle(color: Color.fromARGB(255, 2, 45, 49)),
                  ),
                ),
              ),
              const Text("Appointment:",
                  style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF006A71),
                      fontWeight: FontWeight.w500)),
              _buildTextField(
                'appointment',
                'Select Appointment Date & Time',
                readOnly: true,
                controller: _appointmentController,
                suffixIcon: Icons.calendar_today,
                onTap: () async {
                  if (dropdownValue != null) {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            SelectAppointmentPage(doctorId: dropdownValue!),
                      ),
                    );

                    if (result != null) {
                      setState(() {
                        selectedAppointment = result;
                        _appointmentController.text =
                            DateFormat('E, MMM d, yyyy - h:mm a')
                                .format(selectedAppointment!);
                      });
                    }
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text("Please select a doctor first.")),
                    );
                  }
                },
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
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
                      ? const Center(child: CircularProgressIndicator())
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
