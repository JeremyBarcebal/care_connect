import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isEditingDisplayName = false; // Flag to toggle display name edit mode
  final TextEditingController _displayNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    User? user = _auth.currentUser;
    if (user != null && user.displayName != null) {
      _displayNameController.text = user.displayName!;
    }
  }

  void _logout(BuildContext context) async {
    // Show confirmation dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                await _auth.signOut(); // Firebase sign out
                Navigator.pushReplacementNamed(
                    context, '/login'); // Redirect to login page
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _saveDisplayName() async {
    if (_displayNameController.text.isNotEmpty) {
      User? user = _auth.currentUser;
      if (user != null) {
        await user.updateDisplayName(_displayNameController.text);
        await user.reload();
        setState(() {
          _isEditingDisplayName = false; // Exit edit mode
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Display name updated successfully!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            if (user != null) ...[
              ListTile(
                leading: Icon(Icons.email),
                title: Text('Email'),
                subtitle: Text(user.email ?? 'No email available'),
              ),
              Divider(),
              // Toggle between display name view and edit form
              _isEditingDisplayName
                  ? Column(
                      children: [
                        TextFormField(
                          controller: _displayNameController,
                          decoration: InputDecoration(
                            labelText: 'Edit Display Name',
                          ),
                        ),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _isEditingDisplayName = false; // Cancel edit
                                });
                              },
                              child: Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: _saveDisplayName, // Save display name
                              child: Text('Save'),
                            ),
                          ],
                        ),
                      ],
                    )
                  : ListTile(
                      leading: Icon(Icons.person),
                      title: Text('Display Name'),
                      subtitle:
                          Text(user.displayName ?? 'No display name available'),
                      onTap: () {
                        setState(() {
                          _isEditingDisplayName = true; // Enter edit mode
                        });
                      },
                    ),
              Divider(),
              ListTile(
                leading: Icon(Icons.verified_user),
                title: Text('User ID'),
                subtitle: Text(user.uid),
              ),
              Divider(),
            ] else ...[
              Center(child: Text('No user is signed in')),
            ],
            Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () => _logout(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }
}
