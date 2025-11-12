import 'package:care_connect/pages/client/chat_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
                    icon: Icon(Icons.search, color: Color(0xFF43AF43)),
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF43AF43),
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
    var lastMessage = chatData['lastMessage'] ?? 'No messages yet';
    var isDoc = user?.uid == chatData['doctor'];
    var chatTitle = isDoc ? chatData['clientName'] : chatData['doctorName'];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Color(0xFF43AF43),
        child: Icon(Icons.person, color: Colors.white),
      ),
      title: Text(
        chatTitle,
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(chatData['title']),
      trailing: Text(
        chatData['lastUpdated'] != null
            ? (chatData['lastUpdated'] as Timestamp)
                .toDate()
                .toString()
                .substring(11, 16)
            : '',
        style: TextStyle(color: Colors.grey),
      ),
      onTap: () {
        // Navigate to the ChatPage with the chatDocumentId
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                ChatPage(chatDocumentId: chat.id, chatData: chatData),
          ),
        );
      },
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
