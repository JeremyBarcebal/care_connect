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

  String? dropdownValue; // Initialize this with your default value if needed
  List<Doctor> doctors =
      []; // Replace this with your method of fetching doctors

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
        _isLoading = true;
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
          'clientName': widget.userData?['name'],
          'clientEmail': widget.userData?['email'],
          'clientId': user.uid,
          'timestamp': Timestamp.now(),
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
          'noteId': noteId, // Add the note ID here
          'message': widget.userData?['name'] + ' sent a consultation request',
          'timestamp': Timestamp.now(),
        });

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
            fontSize: 16
          ),
          border: InputBorder.none,
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
          fontWeight: FontWeight.w500,   
        ),
      ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close,color: Colors.white,),
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
              const Text('Symptoms:',style: TextStyle(
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
              const Text("Patient's Description:", style: TextStyle(
              fontSize: 13,
              color: Color(0xFF006A71),
              fontWeight: FontWeight.w500)),
              const SizedBox(height: 5.0),
              _buildTextField('patientFeels', 'How the Patient Feels:'),
              const SizedBox(height: 5.0),
              _buildTextField('onsetSymptoms', 'Onset of Symptoms:'),
              const SizedBox(height: 5.0),
              const Text("Medications:", style: TextStyle(
              fontSize: 13,
              color: Color(0xFF006A71),
              fontWeight: FontWeight.w500)),
              const SizedBox(height: 5.0),
              _buildTextField('currentMedication', 'Current Medications:'),
              const SizedBox(height: 5.0),
              _buildTextField('medicationPrescribe', 'Medication Prescribed:'),
              const SizedBox(height: 5.0),
              const Text("Assigned Doctor:", style: TextStyle(
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
                    },
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    style: const TextStyle(color: Color.fromARGB(255, 2, 45, 49)),
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Close',style: TextStyle(
                    color: Color(0xFF006A71), 
                    fontWeight: FontWeight.bold,),
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
                          child: const Text('Save',style: TextStyle(
                    color: Color(0xFF006A71),
                    fontWeight: FontWeight.bold,),
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
