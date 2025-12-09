import 'package:care_connect/pages/client/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class MessagePage extends StatefulWidget {
  @override
  _MessagePageState createState() => _MessagePageState();
}

class _MessagePageState extends State<MessagePage> {
  int _currentIndex = 0;

  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Current user
  User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(150),
        child: AppBar(
          toolbarHeight: 150.0,
          title: Column(
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 0.0),
                child: Text(
                  "Messages",
                  style: TextStyle(fontSize: 20, color: Colors.white),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const TextField(
                  decoration: InputDecoration(
                    hintText: 'Search',
                    border: InputBorder.none,
                    icon: Icon(Icons.search, color: const Color(0xFF4DBFB8)),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFF4DBFB8),
          shape: RoundedAppBarShape(), // Custom AppBar shape
        ),
      ),
      body: _currentUser != null
          ? _buildChatList()
          : Center(child: Text('No user found')),
    );
  }

  // Build the chat list from Firestore
  Widget _buildChatList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('client', isEqualTo: _currentUser?.uid)
          .snapshots(),
      builder: (context, clientSnapshot) {
        if (clientSnapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (clientSnapshot.hasError || !clientSnapshot.hasData) {
          return Center(child: Text("No messages found"));
        }

        // Query for doctor as well
        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('chats')
              .where('doctor', isEqualTo: _currentUser?.uid)
              .snapshots(),
          builder: (context, doctorSnapshot) {
            if (doctorSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }

            // Combine both client and doctor chats
            var allChats = [
              ...clientSnapshot.data!.docs,
              ...doctorSnapshot.data!.docs,
            ];
            if (allChats.length == 0) {
              return Center(child: Text("No messages found"));
            }

            return ListView.builder(
              itemCount: allChats.length,
              itemBuilder: (context, index) {
                var chat = allChats[index];
                return _buildChatTile(chat);
              },
            );
          },
        );
      },
    );
  }

  // Build each chat tile
  Widget _buildChatTile(QueryDocumentSnapshot chat) {
    User? user = FirebaseAuth.instance.currentUser;
    var chatData = chat.data() as Map<String, dynamic>;
    var isDoc = user?.uid == chatData['doctor'];
    var chatTitle = (isDoc ? chatData['clientName'] : chatData['doctorName']) ??
        'Unknown User';
    var otherUserId = isDoc ? chatData['client'] : chatData['doctor'];

    // Get unread count for current user
    var unreadCountKey = isDoc ? 'unreadCountDoctor' : 'unreadCountClient';
    var unreadCount = chatData[unreadCountKey] ?? 0;
    var hasUnread = unreadCount > 0;

    return FutureBuilder<DocumentSnapshot>(
      future: _firestore.collection('accounts').doc(otherUserId).get(),
      builder: (context, snapshot) {
        String? photoURL;
        if (snapshot.hasData && snapshot.data!.exists) {
          try {
            var data = snapshot.data!.data() as Map<String, dynamic>;
            photoURL = data['photo'];
          } catch (e) {
            print('Error loading photo: $e');
          }
        }

        // Fetch last message from convo subcollection
        return FutureBuilder<QuerySnapshot>(
          future: _firestore
              .collection('chats')
              .doc(chat.id)
              .collection('convo')
              .orderBy('timestamp', descending: true)
              .limit(1)
              .get(),
          builder: (context, convoSnapshot) {
            String lastMessage = 'No messages yet';
            String lastTime = '';

            if (convoSnapshot.hasData && convoSnapshot.data!.docs.isNotEmpty) {
              var lastMsg =
                  convoSnapshot.data!.docs.first.data() as Map<String, dynamic>;

              // Handle different message types
              if (lastMsg['type'] == 'text') {
                lastMessage = lastMsg['message'] ?? 'No messages yet';
              } else if (lastMsg['type'] == 'prescription') {
                lastMessage =
                    'Prescription: ${lastMsg['medicineName'] ?? 'Medicine'}';
              } else {
                lastMessage =
                    '${lastMsg['type']?.toString().toUpperCase() ?? 'MESSAGE'}';
              }

              // Format time
              if (lastMsg['timestamp'] != null) {
                var messageTime = (lastMsg['timestamp'] as Timestamp).toDate();
                var now = DateTime.now();
                var yesterday = DateTime(now.year, now.month, now.day - 1);
                var msgDate = DateTime(
                    messageTime.year, messageTime.month, messageTime.day);

                if (msgDate == DateTime(now.year, now.month, now.day)) {
                  // Today - show time
                  lastTime =
                      '${messageTime.hour.toString().padLeft(2, '0')}:${messageTime.minute.toString().padLeft(2, '0')}';
                } else if (msgDate == yesterday) {
                  // Yesterday
                  lastTime = 'Yesterday';
                } else {
                  // Older - show date
                  lastTime = '${messageTime.month}/${messageTime.day}';
                }
              }
            }

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                decoration: BoxDecoration(
                  color:
                      hasUnread ? const Color(0xFF4DBFB8) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: _buildProfileAvatar(photoURL),
                  title: Text(
                    chatTitle,
                    style: TextStyle(
                      fontWeight: hasUnread ? FontWeight.bold : FontWeight.w500,
                      fontSize: 14,
                      color: hasUnread ? Colors.black87 : Colors.grey.shade700,
                    ),
                  ),
                  subtitle: Text(
                    lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: hasUnread
                          ? Colors.grey.shade700
                          : Colors.grey.shade500,
                      fontWeight:
                          hasUnread ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        lastTime,
                        style: TextStyle(
                          color: hasUnread
                              ? const Color(0xFF4DBFB8)
                              : Colors.grey.shade400,
                          fontSize: 11,
                          fontWeight:
                              hasUnread ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasUnread)
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFF4DBFB8),
                          ),
                        ),
                    ],
                  ),
                  onTap: () {
                    // Mark as read when opening chat
                    if (hasUnread) {
                      _firestore.collection('chats').doc(chat.id).update({
                        unreadCountKey: 0,
                      });
                    }

                    // Navigate to the ChatPage with the chatDocumentId
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatPage(
                            chatDocumentId: chat.id, chatData: chatData),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Build profile avatar with image or icon
  Widget _buildProfileAvatar(String? photoURL) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF4DBFB8),
      ),
      child: photoURL != null && photoURL.isNotEmpty
          ? _buildProfileImage(photoURL)
          : const Center(
              child: Icon(Icons.person, color: Colors.white, size: 28),
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
                  child: Icon(Icons.person, color: Colors.white, size: 28),
                );
              },
            ),
          );
        }
      } catch (e) {
        print('Error decoding Base64 image: $e');
        return const Center(
          child: Icon(Icons.person, color: Colors.white, size: 28),
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
            child: Icon(Icons.person, color: Colors.white, size: 28),
          );
        },
      ),
    );
  }
}

class RoundedAppBarShape extends RoundedRectangleBorder {
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final double radius = 40.0; // Adjust the radius to your preference
    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, rect.height - radius)
      ..quadraticBezierTo(
          0, rect.height, radius, rect.height) // Bottom-left curve
      ..lineTo(rect.width - radius, rect.height)
      ..quadraticBezierTo(rect.width, rect.height, rect.width,
          rect.height - radius) // Bottom-right curve
      ..lineTo(rect.width, 0) // Line to the top-right corner
      ..close(); // Close the path
  }
}
