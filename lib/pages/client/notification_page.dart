import 'package:flutter/material.dart';

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Notifications',
        style: TextStyle( color: Colors.white)),
        backgroundColor: Color.fromARGB(255, 252, 255, 255),
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: 2, // Example item count
        itemBuilder: (context, index) {
          return Container(
            margin: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Color(0xFF9ACBD0).withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.person, size: 40, color: Color(0xFF006A71)),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        index == 0
                            ? 'Dr. Telma sent you prescriptions'
                            : 'Dr. Telma accepted your consultation request',
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 5),
                      Text(
                        '3:26',
                        style: TextStyle(fontSize: 12, color:Color(0xFF006A71)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
