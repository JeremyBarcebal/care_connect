import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:care_connect/pages/client/chat_page.dart';

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late CollectionReference notificationsCollection;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late CollectionReference prescriptionsCollection;

  @override
  void initState() {
    super.initState();
    // Initialize the notifications collection reference
    notificationsCollection = FirebaseFirestore.instance
        .collection('accounts')
        .doc(_auth.currentUser?.uid)
        .collection('notifications');

    prescriptionsCollection = FirebaseFirestore.instance
        .collection('accounts')
        .doc(_auth.currentUser?.uid)
        .collection('prescriptions');
  }

  Future<void> _markNotificationAsRead(String notificationId) async {
    try {
      await notificationsCollection
          .doc(notificationId)
          .update({'isNew': false});
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  Future<Map<String, dynamic>?> _getPrescriptionDetails(
      String? prescriptionId) async {
    if (prescriptionId == null) return null;

    try {
      final doc = await prescriptionsCollection.doc(prescriptionId).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
    } catch (e) {
      print('Error fetching prescription: $e');
    }
    return null;
  }

  Future<String?> _getChatDocumentId(String doctorId) async {
    try {
      final currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) return null;

      // Query chats collection to find chat with this specific doctor and patient
      final querySnapshot = await FirebaseFirestore.instance
          .collection('chats')
          .where('doctor', isEqualTo: doctorId)
          .where('client', isEqualTo: currentUserId)
          .get();

      // If chat exists, return its ID
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.id;
      }

      // If no chat exists, create one
      final newChatDoc = FirebaseFirestore.instance.collection('chats').doc();
      final chatData = {
        'doctor': doctorId,
        'client': currentUserId,
        'lastMessage': '',
        'lastMessageTime': DateTime.now(),
        'createdAt': DateTime.now(),
      };

      await newChatDoc.set(chatData);
      return newChatDoc.id;
    } catch (e) {
      print('Error getting or creating chat: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications', style: TextStyle(color: Colors.white)),
        backgroundColor: Color(0xFF4DBFB8),
        centerTitle: true,
      ),
      body: Container(
        color: Colors.white,
        child: StreamBuilder<QuerySnapshot>(
            stream: notificationsCollection
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(
                  child: CircularProgressIndicator(color: Color(0xFF4DBFB8)),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 64,
                        color: Colors.grey.shade600,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'No notifications',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }

              final notifications = snapshot.data!.docs;

              return ListView.builder(
                itemCount: notifications.length,
                itemBuilder: (context, index) {
                  final notificationDoc = notifications[index];
                  final data = notificationDoc.data() as Map<String, dynamic>;

                  final content = data['message'] ?? 'Notification';
                  final timestamp = data['timestamp'] as Timestamp?;
                  final isNew = data['isNew'] ?? true;
                  final type = data['type'] ??
                      'general'; // 'prescription', 'consultation', 'general'
                  final prescriptionId = data['prescriptionId'] as String?;

                  String formattedTime = '';
                  if (timestamp != null) {
                    final dateTime = timestamp.toDate();
                    final now = DateTime.now();
                    final difference = now.difference(dateTime);

                    if (difference.inMinutes < 1) {
                      formattedTime = 'Just now';
                    } else if (difference.inMinutes < 60) {
                      formattedTime = '${difference.inMinutes}m ago';
                    } else if (difference.inHours < 24) {
                      formattedTime = '${difference.inHours}h ago';
                    } else {
                      formattedTime =
                          '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
                    }
                  }

                  // Check if this is a prescription notification
                  if (type == 'prescription' && prescriptionId != null) {
                    return FutureBuilder<Map<String, dynamic>?>(
                      future: _getPrescriptionDetails(prescriptionId),
                      builder: (context, prescSnapshot) {
                        final prescription = prescSnapshot.data;
                        final medicines =
                            prescription?['medicines'] as List? ?? [];
                        final chatMessageId = data['chatMessageId'] as String?;

                        String medicineDetails = '';
                        if (medicines.isNotEmpty) {
                          final firstMed = medicines[0] as Map<String, dynamic>;
                          medicineDetails =
                              '${firstMed['medicineName'] ?? 'Medicine'} - ${firstMed['dosage'] ?? ''}';
                          if (medicines.length > 1) {
                            medicineDetails += ' +${medicines.length - 1} more';
                          }
                        }

                        return GestureDetector(
                          onTap: () async {
                            // Mark notification as read
                            _markNotificationAsRead(notificationDoc.id);

                            // Get doctor ID from notification first, then from prescription as fallback
                            final doctorId = data['doctorId'] as String? ??
                                prescription?['doctorId'] as String?;
                            final currentUserId = _auth.currentUser?.uid;

                            if (doctorId != null && currentUserId != null) {
                              // Get or create chat with the doctor
                              final chatId = await _getChatDocumentId(doctorId);
                              if (chatId != null && mounted) {
                                // Fetch the actual chat data from Firestore
                                final chatDoc = await FirebaseFirestore.instance
                                    .collection('chats')
                                    .doc(chatId)
                                    .get();

                                if (chatDoc.exists) {
                                  final chatData =
                                      chatDoc.data() as Map<String, dynamic>;
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ChatPage(
                                        chatDocumentId: chatId,
                                        chatData: chatData,
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                          },
                          child: Container(
                            margin: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 16),
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isNew
                                  ? Color(0xFF4DBFB8).withOpacity(0.08)
                                  : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isNew
                                    ? Color(0xFF4DBFB8).withOpacity(0.3)
                                    : Colors.grey.shade200,
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF4DBFB8).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.local_pharmacy,
                                    size: 28,
                                    color: Color(0xFF4DBFB8),
                                  ),
                                ),
                                SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        content,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: isNew
                                              ? FontWeight.bold
                                              : FontWeight.w600,
                                          color: Colors.grey.shade800,
                                          letterSpacing: 0.3,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (medicineDetails.isNotEmpty) ...[
                                        SizedBox(height: 6),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(0xFF4DBFB8)
                                                .withOpacity(0.1),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            medicineDetails,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF4DBFB8),
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                      SizedBox(height: 8),
                                      Text(
                                        formattedTime,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade500,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isNew)
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.red.withOpacity(0.4),
                                          blurRadius: 4,
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }

                  // Regular notification
                  return GestureDetector(
                    onTap: () {
                      // Mark notification as read
                      _markNotificationAsRead(notificationDoc.id);
                    },
                    child: Container(
                      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isNew
                            ? Color(0xFF4DBFB8).withOpacity(0.08)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isNew
                              ? Color(0xFF4DBFB8).withOpacity(0.3)
                              : Colors.grey.shade200,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: type == 'consultation'
                                  ? Colors.blue.withOpacity(0.2)
                                  : Color(0xFF4DBFB8).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              type == 'consultation'
                                  ? Icons.person
                                  : Icons.notifications,
                              size: 28,
                              color: type == 'consultation'
                                  ? Colors.blue.shade300
                                  : Color(0xFF4DBFB8),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  content,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isNew
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: Colors.grey.shade800,
                                    letterSpacing: 0.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  formattedTime,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isNew)
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.red.shade400,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.4),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }),
      ),
    );
  }
}
