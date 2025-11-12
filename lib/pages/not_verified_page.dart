import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class NotVerifiedPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Email Not Verified'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Your email address is not verified.',
              style: TextStyle(fontSize: 20),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            TextButton(
              onPressed: () {
                // Optionally allow the user to send a verification email again
                FirebaseAuth.instance.currentUser?.sendEmailVerification();
              },
              child: Text('Send Verification Email'),
            ),
          ],
        ),
      ),
    );
  }
}
