import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:care_connect/models/prescription_message.dart';
import 'package:care_connect/pages/doctor/task_service.dart';
import 'package:care_connect/pages/doctor/add_prescription_page.dart';
import 'dart:convert';

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

  // Cache for profile photos to avoid repeated fetches
  final Map<String, String?> _photoCache = {};

  @override
  void initState() {
    super.initState();
    _taskService = TaskService();
    // Enable Firestore offline persistence for caching
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    // Pre-load photos for both doctor and patient
    _preloadPhotos();
  } // Pre-load profile photos for both chat participants

  Future<void> _preloadPhotos() async {
    User? user = FirebaseAuth.instance.currentUser;
    var isDocVal = user?.uid == widget.chatData['doctor'];
    var doctorId = widget.chatData['doctor'];
    var clientId = widget.chatData['client'];

    try {
      // Load doctor photo
      var docSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(doctorId)
          .get(const GetOptions(source: Source.cache));
      if (docSnapshot.exists) {
        var docData = docSnapshot.data() as Map<String, dynamic>;
        _photoCache[doctorId] = docData['photoURL'];
      }

      // Load client photo
      var clientSnapshot = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(clientId)
          .get(const GetOptions(source: Source.cache));
      if (clientSnapshot.exists) {
        var clientData = clientSnapshot.data() as Map<String, dynamic>;
        _photoCache[clientId] = clientData['photoURL'];
      }
    } catch (e) {
      print('Error pre-loading photos: $e');
    }
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
    var otherUserId =
        isDocVal ? widget.chatData['client'] : widget.chatData['doctor'];

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('accounts')
          .doc(otherUserId)
          .get(),
      builder: (context, profileSnapshot) {
        String? photoURL;
        if (profileSnapshot.hasData && profileSnapshot.data!.exists) {
          try {
            var data = profileSnapshot.data!.data() as Map<String, dynamic>;
            photoURL = data['photoURL'];
          } catch (e) {
            print('Error loading profile photo: $e');
          }
        }

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
                _buildProfileAvatar(photoURL, 40),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isDocVal
                            ? widget.chatData['clientName']
                            : widget.chatData['doctorName'],
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        isDocVal ? 'Client' : 'Doctor',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            centerTitle: false,
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
                      .orderBy('timestamp',
                          descending: false) // Sort by timestamp
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No messages yet."));
                    }

                    var messages = snapshot.data!.docs;

                    // Scroll to bottom - reset flag on new message count to handle new messages
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients) {
                        Future.delayed(const Duration(milliseconds: 100), () {
                          if (_scrollController.hasClients) {
                            _scrollController.animateTo(
                              _scrollController.position.maxScrollExtent,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOut,
                            );
                          }
                        });
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: messages.length,
                      addAutomaticKeepAlives: false,
                      addRepaintBoundaries: false,
                      itemBuilder: (context, index) {
                        var messageData = messages[index];
                        User? user = FirebaseAuth.instance.currentUser;
                        var isDoc =
                            messageData['sender'] == widget.chatData['doctor'];
                        var isCurrUser = messageData['sender'] == user?.uid;
                        var isPatient = user?.uid != widget.chatData['doctor'];

                        // Determine which user's photo to load based on message sender
                        var senderUserId = messageData['sender'] as String?;
                        var cachedPhotoURL = _photoCache[senderUserId ?? ''];

                        // Check if this is a prescription message or a prescription reference
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
                            cachedPhotoURL,
                          );
                        } else if (messageData['type'] == 'prescription_ref') {
                          // Lazy fetch the full prescription document referenced by this chat message
                          final prescriptionId =
                              messageData['prescriptionId'] as String?;
                          final patientId = messageData['patientId'] as String?;
                          if (prescriptionId == null || patientId == null) {
                            return const Text('Invalid prescription reference');
                          }

                          return FutureBuilder<DocumentSnapshot>(
                            future: FirebaseFirestore.instance
                                .collection('accounts')
                                .doc(patientId)
                                .collection('prescriptions')
                                .doc(prescriptionId)
                                .get(const GetOptions(source: Source.cache)),
                            builder: (context, snap) {
                              if (snap.connectionState ==
                                  ConnectionState.waiting) {
                                return const Padding(
                                  padding: EdgeInsets.all(8.0),
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (!snap.hasData || !snap.data!.exists) {
                                return const Text('Prescription not found');
                              }
                              final presData =
                                  snap.data!.data() as Map<String, dynamic>;

                              // Overlay chat-level status if present
                              presData['status'] = messageData['status'] ??
                                  presData['status'] ??
                                  'pending';

                              return _buildPrescriptionMessage(
                                presData,
                                isDoc
                                    ? widget.chatData['doctorName'] +
                                        " (Doctor)"
                                    : widget.chatData['clientName'] +
                                        ' (Client)',
                                isCurrUser,
                                isPatient && !isCurrUser,
                                messageData.id,
                                cachedPhotoURL,
                              );
                            },
                          );
                        } else {
                          // Regular text message - use cached photo directly
                          return _buildMessageRow(
                            isDoc
                                ? widget.chatData['doctorName']
                                : widget.chatData['clientName'],
                            messageData['message'],
                            isCurrUser,
                            cachedPhotoURL,
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
      },
    );
  }

  // Message Row
  Widget _buildMessageRow(
      String sender, String message, bool isCurrUser, String? photoURL) {
    return Align(
      alignment: isCurrUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            isCurrUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isCurrUser) _buildProfileAvatar(photoURL, 32),
          if (!isCurrUser) const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 5),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrUser ? Colors.green.shade100 : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border:
                    isCurrUser ? null : Border.all(color: Colors.grey.shade300),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sender,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCurrUser ? Colors.green : Colors.grey,
                      fontSize: 11,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrUser) const SizedBox(width: 8),
          if (isCurrUser) _buildProfileAvatar(photoURL, 32),
        ],
      ),
    );
  }

  // Build profile avatar with image or icon
  Widget _buildProfileAvatar(String? photoURL, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4DBFB8),
      ),
      child: photoURL != null && photoURL.isNotEmpty
          ? _buildProfileImage(photoURL)
          : Center(
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: size * 0.5,
              ),
            ),
    );
  }

  // Build profile image from data URL or network
  Widget _buildProfileImage(String photoURL) {
    if (photoURL.startsWith('data:image')) {
      try {
        final parts = photoURL.split(',');
        if (parts.length > 1) {
          final base64String = parts[1];
          final decodedBytes = base64Decode(base64String);
          return ClipOval(
            child: Image.memory(
              decodedBytes,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(Icons.person, color: Colors.white, size: 18),
                );
              },
            ),
          );
        }
      } catch (e) {
        print('Error decoding Base64 image: $e');
        return const Center(
          child: Icon(Icons.person, color: Colors.white, size: 18),
        );
      }
    }

    // Try to load as network image
    return ClipOval(
      child: Image.network(
        photoURL,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Icon(Icons.person, color: Colors.white, size: 18),
          );
        },
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
        var isCurrentUserDoc = user?.uid == widget.chatData['doctor'];

        // Add message to chat
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

        // Increment unread count for the other user
        var unreadCountKey =
            isCurrentUserDoc ? 'unreadCountClient' : 'unreadCountDoctor';
        await FirebaseFirestore.instance
            .collection('chats')
            .doc(widget.chatDocumentId)
            .update({
          unreadCountKey: FieldValue.increment(1),
          'lastMessage': message,
          'lastUpdated': FieldValue.serverTimestamp(),
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

  /// Navigate to AddPrescriptionPage for doctor to send prescription
  void _showSendPrescriptionDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddPrescriptionPage(
          taskService: _taskService,
          patientId: widget.chatData['client'],
          patientName: widget.chatData['clientName'],
          chatDocumentId: widget.chatDocumentId,
        ),
      ),
    ).then((result) {
      // After prescription is scheduled, optionally notify
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prescription sent to patient!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    });
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

      // If this message is a reference, load the full prescription doc
      if (prescription['prescriptionId'] != null &&
          (prescription['medicines'] == null ||
              (prescription['medicines'] as List).isEmpty)) {
        final String presId = prescription['prescriptionId'].toString();
        final String patientId = prescription['patientId'].toString();
        final doc = await FirebaseFirestore.instance
            .collection('accounts')
            .doc(patientId)
            .collection('prescriptions')
            .doc(presId)
            .get();
        if (!doc.exists) {
          throw Exception('Referenced prescription not found');
        }
        final full = doc.data() as Map<String, dynamic>;
        // Use the fetched prescription as the source of truth
        prescription = {
          ...full,
          'patientId': patientId,
          'patientName': full['patientName'] ?? prescription['patientName']
        };
      }

      print('=== ACCEPTING PRESCRIPTION ===');
      print('Patient ID: ${prescription['patientId']}');
      print('Current User ID: ${FirebaseAuth.instance.currentUser?.uid}');

      final medicines = prescription['medicines'] as List<dynamic>? ?? [];
      print('Number of medicines: ${medicines.length}');

      if (medicines.isNotEmpty) {
        // Handle multiple medicines
        for (var med in medicines) {
          final medicineMap = med as Map<String, dynamic>;
          print('Processing medicine: ${medicineMap['medicineName']}');

          // Convert duration to string then to days (handle int or string stored in Firestore)
          final durationStr = (medicineMap['duration'] ?? '30 days').toString();
          final durationDays = _parseDurationToDays(durationStr);
          print('  Duration: $durationStr -> $durationDays days');

          // Get times - could be a list (new format) or a single time (legacy)
          final times = medicineMap['times'] as List<dynamic>?;
          print('  Times: $times');

          // Prepare medicine metadata for task storage - ensure all values are Strings
          final medicineMetadata = {
            'type': (medicineMap['type'] ?? '').toString(),
            'dosage': (medicineMap['dosage'] ?? '').toString(),
            'frequency': (medicineMap['frequency'] ?? '').toString(),
            'duration': (medicineMap['duration'] ?? '').toString(),
            'remarks': (medicineMap['remarks'] ?? '').toString(),
          };

          print('  Medicine Metadata: $medicineMetadata');

          if (times != null && times.isNotEmpty) {
            // Use ALL times for creating tasks
            final timesList = times.map((t) => t.toString()).toList();
            print(
                '  Creating tasks with ${timesList.length} times for $durationDays days');
            print('  Times list: $timesList');

            await _taskService.addPrescriptionTaskWithDuration(
              prescription['patientId'].toString(),
              medicineMap['medicineName'].toString(),
              timesList,
              durationDays,
              medicineData: medicineMetadata,
            );
            print('  ✓ Tasks created successfully');
          } else if (medicineMap['time'] != null) {
            // Fallback to single time (legacy format)
            final timesList = [medicineMap['time'].toString()];
            print('  Creating legacy tasks with single time');

            await _taskService.addPrescriptionTaskWithDuration(
              prescription['patientId'].toString(),
              medicineMap['medicineName'].toString(),
              timesList,
              durationDays,
              medicineData: medicineMetadata,
            );
            print('  ✓ Legacy tasks created successfully');
          } else {
            print('  ⚠️ No times found for this medicine!');
          }
        }
      } else {
        // Fallback for single medicine (legacy format)
        print('No medicines array found, using legacy format');
        await _taskService.addPrescriptionTask(
          prescription['patientId'].toString(),
          prescription['medicineName'].toString(),
          prescription['time'].toString(),
        );
      }

      // Update prescription status in chat
      // If this prescription originated from accounts/.../prescriptions, update that doc too
      if (prescription['prescriptionId'] != null) {
        try {
          final presId = prescription['prescriptionId'].toString();
          final patientId = prescription['patientId'].toString();
          await FirebaseFirestore.instance
              .collection('accounts')
              .doc(patientId)
              .collection('prescriptions')
              .doc(presId)
              .update({
            'status': 'accepted',
            'acceptedBy': FirebaseAuth.instance.currentUser?.uid,
            'acceptedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('Failed to update prescription doc status: $e');
        }
      }

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

  /// Parse duration string to days
  /// Examples: "3 days" -> 3, "1 week" -> 7, "2 weeks" -> 14, "1 month" -> 30, "Ongoing" -> 365
  int _parseDurationToDays(String duration) {
    final lowerDuration = duration.toLowerCase().trim();

    if (lowerDuration.contains('ongoing')) {
      return 365; // 1 year for ongoing
    } else if (lowerDuration.contains('month')) {
      final match = RegExp(r'(\d+)').firstMatch(lowerDuration);
      if (match != null) {
        final months = int.parse(match.group(1)!);
        return months * 30; // Approximate: 1 month = 30 days
      }
      return 30; // Default: 1 month
    } else if (lowerDuration.contains('week')) {
      final match = RegExp(r'(\d+)').firstMatch(lowerDuration);
      if (match != null) {
        final weeks = int.parse(match.group(1)!);
        return weeks * 7;
      }
      return 7; // Default: 1 week
    } else if (lowerDuration.contains('day')) {
      final match = RegExp(r'(\d+)').firstMatch(lowerDuration);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
      return 1; // Default: 1 day
    }

    // Try to parse as number
    try {
      final match = RegExp(r'(\d+)').firstMatch(lowerDuration);
      if (match != null) {
        return int.parse(match.group(1)!);
      }
    } catch (e) {
      // Ignore
    }

    return 30; // Default fallback
  }

  /// Decline prescription
  Future<void> _declinePrescription(String messageDocId) async {
    try {
      // Try to read the chat message to find a prescriptionId (if it's a ref)
      final msgSnap = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatDocumentId)
          .collection('convo')
          .doc(messageDocId)
          .get();
      final msg = msgSnap.data();
      if (msg != null &&
          msg['prescriptionId'] != null &&
          msg['patientId'] != null) {
        try {
          final presId = msg['prescriptionId'].toString();
          final patientId = msg['patientId'].toString();
          await FirebaseFirestore.instance
              .collection('accounts')
              .doc(patientId)
              .collection('prescriptions')
              .doc(presId)
              .update({
            'status': 'declined',
            'declinedBy': FirebaseAuth.instance.currentUser?.uid,
            'declinedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('Failed to update prescription doc status on decline: $e');
        }
      }

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
    String? photoURL,
  ) {
    final status = messageData['status'] ?? 'pending';
    final statusColor = status == 'accepted'
        ? Colors.green
        : status == 'declined'
            ? Colors.red
            : Colors.orange;

    return Align(
      alignment: isCurrUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment:
            isCurrUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrUser) _buildProfileAvatar(photoURL, 40),
          if (!isCurrUser) const SizedBox(width: 8),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.7,
            ),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isCurrUser ? Colors.blue.shade50 : Colors.green.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: statusColor, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_pharmacy,
                              size: 18, color: Colors.green),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              sender,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                  // Check if this is a new format with multiple medicines or legacy single medicine
                  if (messageData['medicines'] != null &&
                      (messageData['medicines'] as List).isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Medicines:',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...(messageData['medicines'] as List<dynamic>)
                            .asMap()
                            .entries
                            .map((e) {
                          final med = e.value as Map<String, dynamic>;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey.shade300),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    med['medicineName'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if ((med['type'] as String?)?.isNotEmpty ??
                                      false)
                                    _buildPrescriptionDetail(
                                        'Type', med['type']),
                                  _buildPrescriptionDetail(
                                      'Dosage', med['dosage']),
                                  // Handle both new format (times list) and legacy format (single time)
                                  if ((med['times'] as List<dynamic>?)
                                          ?.isNotEmpty ??
                                      false)
                                    _buildPrescriptionDetail(
                                        'Times',
                                        (med['times'] as List<dynamic>)
                                            .cast<String>()
                                            .join(', '))
                                  else if ((med['time'] as String?)
                                          ?.isNotEmpty ??
                                      false)
                                    _buildPrescriptionDetail(
                                        'Time', med['time']),
                                  _buildPrescriptionDetail(
                                      'Frequency', med['frequency']),
                                  if (med['duration'] != null)
                                    _buildPrescriptionDetail(
                                        'Duration',
                                        _getDurationLabel(
                                            med['duration'] as int)),
                                  if ((med['remarks'] as String?)?.isNotEmpty ??
                                      false)
                                    _buildPrescriptionDetail(
                                        'Remarks', med['remarks']),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPrescriptionDetail(
                            'Medicine', messageData['medicineName']),
                        _buildPrescriptionDetail(
                            'Dosage', messageData['dosage']),
                        _buildPrescriptionDetail(
                            'Frequency', messageData['frequency']),
                        _buildPrescriptionDetail('Time', messageData['time']),
                        if ((messageData['instructions'] as String?)
                                ?.isNotEmpty ??
                            false)
                          _buildPrescriptionDetail(
                              'Instructions', messageData['instructions']),
                      ],
                    ),

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
          ),
          if (isCurrUser) const SizedBox(width: 8),
          if (isCurrUser) _buildProfileAvatar(photoURL, 40),
        ],
      ),
    );
  }

  /// Helper to build prescription detail row
  String _getDurationLabel(int days) {
    const durationMap = {
      3: '3 days',
      5: '5 days',
      7: '1 week',
      14: '2 weeks',
      21: '3 weeks',
      30: '1 month',
      60: '2 months',
      90: '3 months',
      180: '6 months',
      365: 'Ongoing',
    };
    return durationMap[days] ?? '$days days';
  }

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
