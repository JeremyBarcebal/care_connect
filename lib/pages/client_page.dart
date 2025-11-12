import 'package:care_connect/pages/client/message_page.dart';
import 'package:care_connect/pages/client/task_page.dart';
import 'package:care_connect/pages/doctor/notification_page.dart';
import 'package:flutter/material.dart';
import 'client/note_list_page.dart';
import 'client/settings_page.dart';

class ClientPage extends StatefulWidget {
  @override
  _ClientPageState createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  int _selectedIndex = 0;
  static final List<Widget> _widgetOptions = <Widget>[
    TaskPage(),
    const NoteListPage(),
    MessagePage(),
    NotificationPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(
            bottom: 25.0, right: 30.0, left: 30.0), // Add bottom margin here
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFF43AF43), // Background color of the bar
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(30), bottom: Radius.circular(30)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10.0,
                spreadRadius: 2.0,
                offset: const Offset(0, -2), // Shadow below the bar
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.vertical(
                top: Radius.circular(30), bottom: Radius.circular(30)),
            child: BottomNavigationBar(
              type: BottomNavigationBarType.fixed, // Fixed
              backgroundColor: Color(0xFF43AF43), // <-- This works for fixed
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.filter_alt),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.message),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: '',
                ),
              ],
              currentIndex: _selectedIndex,
              selectedItemColor: Colors.white, // Icon color when selected
              unselectedItemColor: Colors.black, // Icon color when unselected
              elevation: 0, // Remove shadow from the BottomNavigationBar
              onTap: _onItemTapped,
              showUnselectedLabels: false,
              showSelectedLabels: false,
            ),
          ),
        ),
      ),
    );
  }
}
