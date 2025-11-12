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
    notificationsCollection = FirebaseFirestore.instance.collection('accounts').doc(_auth.currentUser?.uid).collection('notifications');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications'),
        backgroundColor: Colors.green,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationsCollection.orderBy('timestamp', descending: true).snapshots(),
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
              String content = notification['message']; // Assuming the notification document has a 'content' field
              String timestamp = notification['timestamp'].toDate().toString(); // Assuming there is a 'timestamp' field

              // Format the timestamp if needed
              String formattedTime = _formatTimestamp(timestamp);

              return Container(
                margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 40, color: Colors.green),
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
