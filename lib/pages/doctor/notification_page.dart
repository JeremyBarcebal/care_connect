import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  late CollectionReference notificationsCollection;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    // Initialize the notifications collection reference
    notificationsCollection = FirebaseFirestore.instance
        .collection('accounts')
        .doc(_auth.currentUser?.uid)
        .collection('notifications');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        backgroundColor: Color(0xFF4DBFB8),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationsCollection
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No notifications available.'));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              var notification = notifications[index];
              String content = notification['message'] ?? 'Notification';

              // Safely extract and format the timestamp
              String formattedTime = 'Unknown time';
              try {
                var timestampValue = notification['timestamp'];
                if (timestampValue != null) {
                  if (timestampValue is Timestamp) {
                    // It's a Firestore Timestamp
                    DateTime dateTime = timestampValue.toDate();
                    formattedTime = _formatTimestamp(dateTime.toString());
                  } else if (timestampValue is DateTime) {
                    // It's already a DateTime
                    formattedTime = _formatTimestamp(timestampValue.toString());
                  }
                }
              } catch (e) {
                print('Error parsing timestamp: $e');
                formattedTime = 'Unable to parse time';
              }

              return Container(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Color.fromRGBO(154, 203, 208, 10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 40, color: Color(0xFF4DBFB8)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content,
                            style: TextStyle(fontSize: 16),
                          ),
                          SizedBox(height: 5),
                          Text(
                            formattedTime,
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Helper method to format the timestamp (can be customized)
  String _formatTimestamp(String timestamp) {
    DateTime dateTime = DateTime.parse(timestamp);
    return '${dateTime.hour}:${dateTime.minute}'; // Customize the format as needed
  }
}
