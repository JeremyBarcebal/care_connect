import 'dart:async';
import 'package:care_connect/pages/client/add_note_page.dart';
import 'package:care_connect/pages/client/message_page.dart';
import 'package:care_connect/pages/client/task_page.dart';
import 'package:care_connect/pages/client/notification_page.dart'
    as client_notif;
import 'package:care_connect/services/medicine_notification_service.dart';
import 'package:flutter/material.dart';
import 'client/note_list_page.dart';
import 'client/settings_page.dart';
import 'package:care_connect/main.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ClientPage extends StatefulWidget {
  @override
  _ClientPageState createState() => _ClientPageState();
}

class _ClientPageState extends State<ClientPage> {
  int _selectedIndex = 0;
  int _newNotificationCount = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late MedicineNotificationService _medicineNotificationService;
  StreamSubscription? _notificationSubscription;

  static final List<Widget> _widgetOptions = <Widget>[
    TaskPage(),
    const NoteListPage(),
    MessagePage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _initializeMedicineNotifications();
    _listenToNotifications();
  }

  Future<void> _initializeMedicineNotifications() async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _medicineNotificationService = MedicineNotificationService();

    // Initialize the notification service
    await _medicineNotificationService.initialize();

    // Start watching for medicine reminders
    await _medicineNotificationService.watchMedicineReminders(userId);
  }

  void _listenToNotifications() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    // Cancel any existing subscription before creating a new one
    _notificationSubscription?.cancel();

    _notificationSubscription = FirebaseFirestore.instance
        .collection('accounts')
        .doc(userId)
        .collection('notifications')
        .where('isNew', isEqualTo: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (mounted) {
          setState(() {
            _newNotificationCount = snapshot.docs.length;
          });
        }
      },
      onError: (error) {
        // Log error but don't crash - user might not have notifications collection yet
        print('Error listening to notifications: $error');
      },
    );
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _medicineNotificationService.dispose();
    super.dispose();
  }

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
      floatingActionButton: Stack(
        children: [
          FloatingActionButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => client_notif.NotificationPage()),
              );
            },
            child: const Icon(Icons.notifications, color: Colors.white),
            tooltip: 'Notifications',
            backgroundColor: const Color(0xFF4DBFB8),
          ),
          // Red badge for new notifications
          if (_newNotificationCount > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _newNotificationCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: 15,
            right: 20.0,
            left: 20.0,
          ),
          child: Container(
            height: 63,
            decoration: BoxDecoration(
              color: Color(0xFF48A6A7),
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(30),
                bottom: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 255, 255, 255)
                      .withOpacity(0.1),
                  blurRadius: 10.0,
                  spreadRadius: 2.0,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(25),
                bottom: Radius.circular(25),
              ),
              child: BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: const Color(0xFF4DBFB8),
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
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.black,
                elevation: 0,
                iconSize: 28.0,
                onTap: (index) {
                  if (index == 2) {
                    final userData = UserDataProvider.of(context)?.userData;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddNotePage(userData),
                      ),
                    );
                  } else if (index < 2) {
                    _onItemTapped(index);
                  } else if (index == 3) {
                    _onItemTapped(2);
                  } else if (index == 4) {
                    _onItemTapped(3);
                  }
                },
                showUnselectedLabels: false,
                showSelectedLabels: false,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
