import 'package:care_connect/pages/client/chat_page.dart';
import 'package:care_connect/pages/client/note_list_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NoteDetail extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final dynamic noteData;

  const NoteDetail(this.userData, {super.key, this.noteData});

  @override
  State<NoteDetail> createState() => _NoteDetailState();
}

class _NoteDetailState extends State<NoteDetail> {
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

    // Populate controllers with existing noteData if it's provided
    if (widget.noteData != null) {
      _controllers['bodyTemperature']?.text =
          widget.noteData['bodyTemperature'] ?? '';
      _controllers['painLocation']?.text =
          widget.noteData['painLocation'] ?? '';
      _controllers['painIntensity']?.text =
          widget.noteData['painIntensity'] ?? '';
      _controllers['patientFeels']?.text =
          widget.noteData['patientFeels'] ?? '';
      _controllers['onsetSymptoms']?.text =
          widget.noteData['onsetSymptoms'] ?? '';
      _controllers['currentMedication']?.text =
          widget.noteData['currentMedication'] ?? '';
      _controllers['medicationPrescribe']?.text =
          widget.noteData['medicationPrescribe'] ?? '';
      dropdownValue = widget.noteData['assignedTo'] ?? '';
    }

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

  void _onDeclined() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Decline'),
          content: const Text('Are you sure you want to decline this note?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // User clicked Cancel
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // User clicked Confirm
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _isLoading = true;
        // Save the note data to Firestore
        await _firestore
            .collection('accounts')
            .doc(widget.noteData['clientId'])
            .collection('notes')
            .doc(widget.noteData.id)
            .update({'approved': false});

        // Get the note ID

        // Add a notification with the note ID
        await _firestore
            .collection('accounts')
            .doc(widget.noteData['clientId'])
            .collection('notifications')
            .add({
          'name': widget.userData?['name'],
          'email': widget.userData?['email'],
          'noteId': widget.noteData.id, // Add the note ID here
          'message':
              widget.userData?['name'] + ' declined your consultation request',
          'type': 'consultation',
          'timestamp': Timestamp.now(),
          'isNew': true,
        });

        Navigator.pop(context);
      }
    }
  }

  void _onAccept() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Accept'),
          content: const Text('Are you sure you want to accept this note?'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false); // User clicked Cancel
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // User clicked Confirm
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _isLoading = true;
        // Save the note data to Firestore
        await _firestore
            .collection('accounts')
            .doc(widget.noteData['clientId'])
            .collection('notes')
            .doc(widget.noteData.id)
            .update({'approved': true});

        // Get the note ID

        // Add a notification with the note ID
        await _firestore
            .collection('accounts')
            .doc(widget.noteData['clientId'])
            .collection('notifications')
            .add({
          'name': widget.userData?['name'],
          'email': widget.userData?['email'],
          'noteId': widget.noteData.id, // Add the note ID here
          'message':
              widget.userData?['name'] + ' accepted your consultation request',
          'type': 'consultation',
          'timestamp': Timestamp.now(),
          'isNew': true,
        });

        Navigator.pop(context);
      }
    }
  }

  void _onSendMessage() async {
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Handle the case where the user is not logged in
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User is not logged in')),
      );
      return;
    }

    try {
      // Check if a chat already exists for the given noteId
      QuerySnapshot existingChats = await _firestore
          .collection('chats')
          .where('noteId', isEqualTo: widget.noteData.id)
          .get();

      if (existingChats.docs.isNotEmpty) {
        // If a chat already exists, navigate to that chat
        DocumentSnapshot existingChat = existingChats.docs.first;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              chatDocumentId: existingChat.id,
              chatData: existingChat.data() as Map<String, dynamic>,
            ),
          ),
        );
      } else {
        // If no chat exists, create a new chat
        DocumentReference chatRef = await _firestore.collection('chats').add({
          'client': widget.noteData['clientId'],
          'doctor': user.uid,
          'lastMessage': '',
          'doctorName': widget.userData?['name'],
          'clientName': widget.noteData?['clientName'],
          'title': widget.noteData?['patientFeels'],
          'noteId': widget.noteData.id
        });

        DocumentSnapshot chatSnapshot = await chatRef.get();
        var chatData = chatSnapshot.data() as Map<String, dynamic>;

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              chatDocumentId: chatRef.id,
              chatData: chatData,
            ),
          ),
        );
      }
    } catch (e) {
      // Handle any errors that occur during the process
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating chat: $e')),
      );
    }
  }

  Widget _buildActionButtons() {
    // Check if noteData is valid and contains the 'approved' field
    final bool hasApp = widget.noteData != null &&
        widget.noteData.data() != null &&
        widget.noteData.data().containsKey('approved');
    final bool isApproved = widget.noteData != null &&
        widget.noteData.data() != null &&
        widget.noteData.data().containsKey('approved') &&
        widget.noteData['approved'] == true;
    if (hasApp && !isApproved) {
      return const SizedBox(width: 8.0);
    }

    // Loading indicator if _isLoading is true
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check if current user is a patient (hide action buttons for patients)
    final userType = (widget.userData?['type'] as String?)?.toLowerCase();
    if (userType == 'patient') {
      return const Row(
        children: [
          SizedBox(width: 8.0),
        ],
      );
    } else {
      // Render buttons based on approval status (only for doctors)
      return Row(
        children: [
          const SizedBox(width: 8.0),
          ElevatedButton(
            onPressed: isApproved ? _onSendMessage : _onAccept,
            child: Text(isApproved ? 'Send Message' : 'Accept'),
          ),
          const SizedBox(width: 8.0),
          if (!isApproved) // Only show the Decline button if not approved
            ElevatedButton(
              onPressed: _onDeclined,
              child: const Text('Decline'),
            ),
        ],
      );
    }
  }

  Widget _buildTextField(String key, String label,
      {bool obscureText = false, bool readOnly = false, VoidCallback? onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: TextField(
        controller: _controllers[key],
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w400,
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
        title: const Text('Note Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
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
              Text("Client's Name: " + widget.noteData['clientName']),
              Text('Email: ' + widget.noteData['clientEmail']),
              const SizedBox(height: 20.0),
              const Text('Symptoms:'),
              _buildTextField('bodyTemperature', 'Body Temperature:',
                  readOnly: true),
              const SizedBox(height: 5.0),
              _buildTextField('painLocation', 'Pain Location:', readOnly: true),
              const SizedBox(height: 5.0),
              _buildTextField('painIntensity', 'Pain Intensity:',
                  readOnly: true),
              const SizedBox(height: 5.0),
              const Text("Patient's Description:"),
              const SizedBox(height: 5.0),
              _buildTextField('patientFeels', 'How the Patient Feels:',
                  readOnly: true),
              const SizedBox(height: 5.0),
              _buildTextField('onsetSymptoms', 'Onset of Symptoms:',
                  readOnly: true),
              const SizedBox(height: 5.0),
              const Text("Medications:"),
              const SizedBox(height: 5.0),
              _buildTextField('currentMedication', 'Current Medications:',
                  readOnly: true),
              const SizedBox(height: 5.0),
              _buildTextField('medicationPrescribe', 'Medication Prescribed:',
                  readOnly: true),
              const SizedBox(height: 5.0),
              const Text("Assigned Doctor:"),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                margin:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(20),
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
                    onChanged: (String? newValue) {},
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    style: const TextStyle(color: Colors.black),
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
                    child: const Text('Close'),
                  ),
                  _buildActionButtons()
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
