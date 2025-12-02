import 'package:care_connect/pages/client/add_note_page.dart';
import 'package:care_connect/pages/client/message_page.dart';
import 'package:care_connect/pages/client/task_page.dart';
import 'package:care_connect/pages/doctor/notification_page.dart';
import 'package:flutter/material.dart';
import 'client/note_list_page.dart';
import 'client/settings_page.dart';
import 'package:care_connect/main.dart';

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
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Function to convert navbar index to widget list index and vice versa
  int _getNavbarIndex(int widgetIndex) {
    // Map widget index to navbar index
    // Widget: 0 -> Navbar: 0 (Home)
    // Widget: 1 -> Navbar: 1 (Notes)
    // Widget: 2 -> Navbar: 3 (Messages)
    // Widget: 3 -> Navbar: 4 (Settings)
    if (widgetIndex == 0) return 0;
    if (widgetIndex == 1) return 1;
    if (widgetIndex == 2) return 3;
    if (widgetIndex == 3) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _widgetOptions.elementAt(_selectedIndex),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NotificationPage()),
          );
        },
        child: const Icon(Icons.notifications, color: Colors.white),
        tooltip: 'Notifications',
        backgroundColor: const Color(0xFF4DBFB8),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.only(
            bottom: 25.0, right: 30.0, left: 30.0), // Add bottom margin here
        child: Container(
          decoration: BoxDecoration(
            color: Color(0xFF4DBFB8), // Background color of the bar
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
                  icon: Icon(Icons.add),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.message),
                  label: '',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings),
                  label: '',
                ),
              ],
              currentIndex: _getNavbarIndex(_selectedIndex),
              selectedItemColor: Colors.white, // Icon color when selected
              unselectedItemColor: Colors.black, // Icon color when unselected
              elevation: 0, // Remove shadow from the BottomNavigationBar
              onTap: (index) {
                if (index == 2) {
                  // Add Note button - don't change selection, open dialog
                  final userData = UserDataProvider.of(context)?.userData;
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => AddNotePage(userData)),
                  );
                } else if (index < 2) {
                  // Home (index 0) or Notes (index 1) - map directly
                  _onItemTapped(index);
                } else if (index == 3) {
                  // Messages (index 3) - map to widget list index 2
                  _onItemTapped(2);
                } else if (index == 4) {
                  // Settings (index 4) - map to widget list index 3
                  _onItemTapped(3);
                }
              },
              showUnselectedLabels: false,
              showSelectedLabels: false,
            ),
          ),
        ),
      ),
    );
  }
}
