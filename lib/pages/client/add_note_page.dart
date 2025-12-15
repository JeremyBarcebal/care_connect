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
  Map<String, dynamic>? selectedDoctorSchedules;
  String? selectedTimeSlot;
  String? selectedDateKey;

  @override
  void initState() {
    super.initState();
    _fetchAvailableDoctorsWithSchedules();
  }

  Future<void> _fetchAvailableDoctorsWithSchedules() async {
    try {
      // Query all schedules from root-level schedules collection
      QuerySnapshot scheduleSnapshot =
          await _firestore.collection('schedules').get();

      print("📋 Schedules found: ${scheduleSnapshot.docs.length}");

      if (scheduleSnapshot.docs.isEmpty) {
        setState(() {
          doctors = [];
          dropdownValue = null;
          selectedDoctorSchedules = null;
          selectedTimeSlot = null;
          selectedDateKey = null;
        });
        return;
      }

      // Get doctors from schedules that have dates
      List<Doctor> availableDoctors = [];
      for (var scheduleDoc in scheduleSnapshot.docs) {
        String doctorId = scheduleDoc.id;
        Map<String, dynamic> scheduleData =
            scheduleDoc.data() as Map<String, dynamic>;

        // Check if this schedule has at least one date
        QuerySnapshot datesSnapshot =
            await scheduleDoc.reference.collection('dates').get();

        if (datesSnapshot.docs.isNotEmpty) {
          // Create a minimal Doctor object from schedule data
          Doctor doctor = Doctor(
            id: doctorId,
            name: scheduleData['name'] ?? 'Unknown Doctor',
            specialty: scheduleData['specialty'] ?? 'General',
          );
          availableDoctors.add(doctor);
        }
      }

      setState(() {
        doctors = availableDoctors;
        if (doctors.isNotEmpty) {
          dropdownValue = doctors.first.id;
          _fetchDoctorSchedules(doctors.first.id);
        } else {
          dropdownValue = null;
          selectedDoctorSchedules = null;
          selectedTimeSlot = null;
          selectedDateKey = null;
        }
      });
    } catch (e) {
      print("❌ Error fetching available doctors: $e");
    }
  }

  Future<void> _fetchDoctorSchedules(String doctorId) async {
    try {
      // Get schedule document directly using doctorId as the document ID
      DocumentSnapshot scheduleSnapshot =
          await _firestore.collection('schedules').doc(doctorId).get();

      if (!scheduleSnapshot.exists) {
        // No schedule found for this doctor
        print("⚠️ Doctor ($doctorId) has not created any schedules yet");
        setState(() {
          selectedDoctorSchedules = null;
          selectedTimeSlot = null;
          selectedDateKey = null;
        });
        return;
      }

      // Schedule document exists, now get the first available date
      QuerySnapshot datesSnapshot =
          await scheduleSnapshot.reference.collection('dates').get();

      if (datesSnapshot.docs.isEmpty) {
        // Schedule exists but no dates have been added
        print("⚠️ Schedule exists but no dates available");
        setState(() {
          selectedDoctorSchedules = null;
          selectedTimeSlot = null;
          selectedDateKey = null;
        });
        return;
      }

      // Get the first date document
      DocumentSnapshot dateDoc = datesSnapshot.docs.first;
      String dateKey = dateDoc.id;

      Map<String, dynamic> dateData = dateDoc.data() as Map<String, dynamic>;

      setState(() {
        selectedDoctorSchedules = dateData;
        selectedTimeSlot = null;
        selectedDateKey = dateKey;
      });
    } catch (e) {
      print("❌ Error fetching doctor schedules: $e");
      setState(() {
        selectedDoctorSchedules = null;
        selectedTimeSlot = null;
        selectedDateKey = null;
      });
    }
  }

  Future<void> _updateScheduleStatus(String doctorId, String dateKey,
      String timeSlot, String patientName) async {
    try {
      // Get the schedule document directly using doctorId
      DocumentReference scheduleRef =
          _firestore.collection('schedules').doc(doctorId);

      DocumentReference dateRef = scheduleRef.collection('dates').doc(dateKey);

      // Get the date document
      DocumentSnapshot dateDoc = await dateRef.get();

      if (dateDoc.exists) {
        Map<String, dynamic> dateData = dateDoc.data() as Map<String, dynamic>;
        List<Map<String, dynamic>> slots =
            List<Map<String, dynamic>>.from(dateData['slots'] ?? []);

        // Find and update the slot status
        for (int i = 0; i < slots.length; i++) {
          if (slots[i]['time'] == timeSlot) {
            slots[i]['status'] = 'booked';
            slots[i]['bookedBy'] = patientName;
            slots[i]['updatedAt'] = Timestamp.now();
            break;
          }
        }

        // Update the date document with new slots
        await dateRef.update({'slots': slots});
        print('✅ Schedule updated: $timeSlot marked as booked by $patientName');
      }
    } catch (e) {
      print("❌ Failed to update schedule status: $e");
    }
  }

  // Future<void> _updateScheduleStatus(String doctorId, String dateKey,
  //     String timeSlot, String patientName) async {
  //   try {
  //     // Get the schedule document for the doctor
  //     QuerySnapshot scheduleSnapshot = await _firestore
  //         .collection('schedules')
  //         .where('doctorId', isEqualTo: doctorId)
  //         .get();

  //     if (scheduleSnapshot.docs.isNotEmpty) {
  //       DocumentReference scheduleRef = scheduleSnapshot.docs.first.reference;
  //       DocumentReference dateRef =
  //           scheduleRef.collection('dates').doc(dateKey);

  //       // Get the date document
  //       DocumentSnapshot dateDoc = await dateRef.get();

  //       if (dateDoc.exists) {
  //         Map<String, dynamic> dateData =
  //             dateDoc.data() as Map<String, dynamic>;
  //         List<Map<String, dynamic>> slots =
  //             List<Map<String, dynamic>>.from(dateData['slots'] ?? []);

  //         // Find and update the slot status
  //         for (int i = 0; i < slots.length; i++) {
  //           if (slots[i]['time'] == timeSlot) {
  //             slots[i]['status'] = 'booked';
  //             slots[i]['bookedBy'] = patientName;
  //             slots[i]['updatedAt'] = Timestamp.now();
  //             break;
  //           }
  //         }

  //         // Update the date document with new slots
  //         await dateRef.update({'slots': slots});
  //         print('Schedule updated: $timeSlot marked as booked by $patientName');
  //       }
  //     }
  //   } catch (e) {
  //     print("Failed to update schedule status: $e");
  //   }
  // }

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
          'clientMobileNo': widget.userData?['mobileNo'],
          'clientId': user.uid,
          'timestamp': Timestamp.now(),
          'selectedTimeSlot': selectedTimeSlot,
          'selectedDateKey': selectedDateKey,
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
            color: const Color(0xFF006A71).withOpacity(0.2), width: 0.5!),
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

  Widget _buildAvailableSlots() {
    if (selectedDoctorSchedules == null) {
      return Container(
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ No Schedules Available',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'This doctor has not created any appointment schedules yet. Please try selecting another doctor or contact them to set up their schedule.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    final slots = (selectedDoctorSchedules?['slots'] as List<dynamic>?) ?? [];

    if (slots.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(15),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '⚠️ No Available Slots',
              style: TextStyle(
                color: Colors.orange,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 5),
            Text(
              'No time slots are available for this date. Please select another date or try again later.',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF9ACBD0).withOpacity(0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF006A71).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Selected Appointment',
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF006A71),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 20, color: Color(0xFF006A71)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Date',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      selectedDateKey ?? 'Not Selected',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF006A71),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time, size: 20, color: Color(0xFF006A71)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Time Slot',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    Text(
                      selectedTimeSlot ?? 'Not Selected',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF006A71),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
            doctors.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(15),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '❌ No Doctors Available',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'No doctors with active schedules are available at this time. Please try again later.',
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    margin: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      color: Color(0xFF9ACBD0).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: dropdownValue,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        items: doctors
                            .map<DropdownMenuItem<String>>((Doctor doctor) {
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
                        style: const TextStyle(
                            color: Color.fromARGB(255, 2, 45, 49)),
                      ),
                    ),
                  ),
            const SizedBox(height: 12.0),
            if (dropdownValue != null)
              Center(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Navigate to SelectAppointmentPage with the selected doctor ID
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SelectAppointmentPage(
                          doctorId: dropdownValue!,
                        ),
                      ),
                    );

                    // Handle the returned appointment data
                    if (result != null && result is Map<String, dynamic>) {
                      setState(() {
                        selectedTimeSlot = result['timeSlot'];
                        selectedDateKey = result['dateKey'];
                        _appointmentController.text =
                            '${result['dateKey']} at ${result['timeSlot']}';
                        selectedAppointment = result['dateTime'];
                      });

                      // Show confirmation
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Appointment scheduled for ${result['dateKey']} at ${result['timeSlot']}'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Pick Schedule'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF006A71),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 16.0),
            _buildAvailableSlots(),
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
          ]),
        ),
      ),
    );
  }
}
