import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:care_connect/models/prescription_message.dart';
import 'package:care_connect/pages/client/send_prescription_dialog.dart';
import 'package:care_connect/pages/doctor/task_service.dart';

class ChatPage extends StatefulWidget {
  final String chatDocumentId; // Pass the chatDocumentId to specify the chat
  final dynamic chatData; // Pass the chatDocumentId to specify the chat

  ChatPage({required this.chatDocumentId, this.chatData});

  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  bool _isSending = false;
  final ScrollController _scrollController = ScrollController();
  late TaskService _taskService;

  @override
  void initState() {
    super.initState();
    _taskService = TaskService();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose(); // Dispose the scroll controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    var isDocVal = user?.uid == widget.chatData['doctor'];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.white,
              radius: 20,
              child: Icon(Icons.person, color: Colors.green),
            ),
            const SizedBox(width: 10),
            Text(
              isDocVal
                  ? widget.chatData['doctorName'] + " (Doctor)"
                  : widget.chatData['clientName'] + ' (Client)',
              style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.green,
        actions: [
          // Show prescription button only for doctors
          if (isDocVal)
            IconButton(
              icon: const Icon(Icons.medication, color: Colors.white),
              tooltip: 'Send Prescription',
              onPressed: () {
                _showSendPrescriptionDialog();
              },
            ),
        ],
      ),
      body: Column(
        children: [
          // Message List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(widget.chatDocumentId)
                  .collection('convo')
                  .orderBy('timestamp', descending: false) // Sort by timestamp
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No messages yet."));
                }

                var messages = snapshot.data!.docs;
                // Scroll to the bottom after messages are built
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollController.hasClients) {
                    _scrollController
                        .jumpTo(_scrollController.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollController, // Attach the scroll controller
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var messageData = messages[index];
                    User? user = FirebaseAuth.instance.currentUser;
                    var isDoc =
                        messageData['sender'] == widget.chatData['doctor'];
                    var isCurrUser = messageData['sender'] == user?.uid;
                    var isPatient = user?.uid != widget.chatData['doctor'];

                    // Check if this is a prescription message
                    if (messageData['type'] == 'prescription') {
                      return _buildPrescriptionMessage(
                        messageData.data() as Map<String, dynamic>,
                        isDoc
                            ? widget.chatData['doctorName'] + " (Doctor)"
                            : widget.chatData['clientName'] + ' (Client)',
                        isCurrUser,
                        isPatient &&
                            !isCurrUser, // Show accept button only for patient receiving
                        messageData.id, // Pass message document ID
                      );
                    } else {
                      // Regular text message
                      return _buildMessageRow(
                        isDoc
                            ? widget.chatData['doctorName'] + " (Doctor)"
                            : widget.chatData['clientName'] + ' (Client)',
                        messageData['message'],
                        isCurrUser,
                      );
                    }
                  },
                );
              },
            ),
          ),
          // Input Field
          _buildMessageInput(),
        ],
      ),
    );
  }

  // Message Row
  Widget _buildMessageRow(String sender, String message, bool isCurrUser) {
    return Align(
      alignment: isCurrUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrUser ? Colors.green.shade100 : Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.green,
              child: Icon(Icons.person, color: Colors.white),
            ),
            SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sender,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green),
                ),
                SizedBox(height: 5),
                Text(message),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Message Input Field
  Widget _buildMessageInput() {
    User? user = FirebaseAuth.instance.currentUser;
    var isDocVal = user?.uid == widget.chatData['doctor'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                hintText: 'Type your message...',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 10),
              ),
            ),
          ),
          // Prescription button for doctors
          if (isDocVal)
            IconButton(
              icon: const Icon(Icons.local_pharmacy, color: Colors.green),
              tooltip: 'Send Prescription',
              onPressed: _showSendPrescriptionDialog,
            ),
          _isSending
              ? const CircularProgressIndicator()
              : IconButton(
                  icon: const Icon(Icons.send, color: Colors.green),
                  onPressed: _sendMessage,
                ),
        ],
      ),
    );
  }

  // Send Message Function
  Future<void> _sendMessage() async {
    String message = _messageController.text.trim();

    if (message.isNotEmpty) {
      setState(() => _isSending = true);
      try {
        // Get current user information
        User? user = FirebaseAuth.instance.currentUser;
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatDocumentId)
            .collection('convo')
            .add({
          'message': message,
          'sender': user?.uid, // Doctor or Patient
          'timestamp': FieldValue.serverTimestamp(), // Timestamp
          'type': 'text', // Message type
        });

        // Clear the message input field
        _messageController.clear();
      } catch (e) {
        // Handle error (e.g., show a snackbar or dialog)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to send message: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSending = false);
        }
      }
    }
  }

  /// Show dialog for doctor to send prescription
  void _showSendPrescriptionDialog() {
    showDialog(
      context: context,
      builder: (context) => SendPrescriptionDialog(
        patientId: widget.chatData['client'],
        patientName: widget.chatData['clientName'],
        onSend: (prescription) {
          _sendPrescriptionMessage(prescription);
        },
      ),
    );
  }

  /// Send prescription message to chat
  Future<void> _sendPrescriptionMessage(
      PrescriptionMessage prescription) async {
    try {
      User? user = FirebaseAuth.instance.currentUser;

      // Add prescription message to chat
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatDocumentId)
          .collection('convo')
          .add({
        'type': 'prescription',
        'medicineName': prescription.medicineName,
        'dosage': prescription.dosage,
        'frequency': prescription.frequency,
        'instructions': prescription.instructions,
        'time': prescription.time,
        'status': 'pending',
        'patientId': prescription.patientId,
        'patientName': prescription.patientName,
        'sender': user?.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription sent successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send prescription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Accept prescription and add to patient tasks
  Future<void> _acceptPrescription(
    Map<String, dynamic> prescription,
    String messageDocId,
  ) async {
    try {
      setState(() {});

      // Add prescription to patient's task collection
      await _taskService.addPrescriptionTask(
        prescription['patientId'],
        prescription['medicineName'],
        prescription['time'],
      );

      // Update prescription status in chat
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatDocumentId)
          .collection('convo')
          .doc(messageDocId)
          .update({'status': 'accepted'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription accepted! Added to your tasks.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept prescription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Decline prescription
  Future<void> _declinePrescription(String messageDocId) async {
    try {
      // Update prescription status in chat
      await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatDocumentId)
          .collection('convo')
          .doc(messageDocId)
          .update({'status': 'declined'});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription declined.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline prescription: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Build prescription message widget
  Widget _buildPrescriptionMessage(
    Map<String, dynamic> messageData,
    String sender,
    bool isCurrUser,
    bool showAcceptButton,
    String messageDocId,
  ) {
    final status = messageData['status'] ?? 'pending';
    final statusColor = status == 'accepted'
        ? Colors.green
        : status == 'declined'
            ? Colors.red
            : Colors.orange;

    return Align(
      alignment: isCurrUser ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isCurrUser ? Colors.blue.shade50 : Colors.green.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: statusColor, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.local_pharmacy,
                        size: 18, color: Colors.green),
                    const SizedBox(width: 8),
                    Text(
                      sender,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Prescription details
            _buildPrescriptionDetail('Medicine', messageData['medicineName']),
            _buildPrescriptionDetail('Dosage', messageData['dosage']),
            _buildPrescriptionDetail('Frequency', messageData['frequency']),
            _buildPrescriptionDetail('Time', messageData['time']),
            if ((messageData['instructions'] as String?)?.isNotEmpty ?? false)
              _buildPrescriptionDetail(
                  'Instructions', messageData['instructions']),

            // Patient info
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Patient Info:',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Name: ${messageData['patientName']}',
                    style: const TextStyle(fontSize: 10),
                  ),
                  Text(
                    'ID: ${messageData['patientId']}',
                    style: const TextStyle(fontSize: 10),
                  ),
                ],
              ),
            ),

            // Action buttons for patients
            if (showAcceptButton && status == 'pending')
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        _declinePrescription(messageDocId);
                      },
                      icon: const Icon(Icons.close, size: 16),
                      label: const Text('Decline'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        _acceptPrescription(messageData, messageDocId);
                      },
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('Accept'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Helper to build prescription detail row
  Widget _buildPrescriptionDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
