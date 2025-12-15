import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class NotVerifiedPage extends StatefulWidget {
  @override
  _NotVerifiedPageState createState() => _NotVerifiedPageState();
}

class _NotVerifiedPageState extends State<NotVerifiedPage> {
  late Timer _verificationCheckTimer;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    // Check for email verification every 2 seconds
    _verificationCheckTimer = Timer.periodic(
      const Duration(seconds: 2),
      (timer) => _checkEmailVerification(),
    );
  }

  @override
  void dispose() {
    _verificationCheckTimer.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerification() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Reload user to get the latest email verification status
      await user.reload();
      if (user.emailVerified) {
        // Email is verified - show dialog and navigate to login
        _verificationCheckTimer.cancel();
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Email Verified!'),
                content: const Text(
                  'Your email has been successfully verified. '
                  'You can now login with your account.',
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close dialog
                      // Sign out and go back to login
                      FirebaseAuth.instance.signOut();
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: const Text('Go to Login'),
                  ),
                ],
              );
            },
          );
        }
      }
    }
  }

  Future<void> _sendVerificationEmail() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      try {
        await user.sendEmailVerification();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Verification email sent! Check your inbox.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to send verification email: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Verification Required'),
        backgroundColor: const Color(0xFF4DBFB8),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.mail_outline,
                size: 80,
                color: const Color(0xFF4DBFB8),
              ),
              const SizedBox(height: 24),
              Text(
                'Email Verification Required',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Please verify your email address to continue. '
                'We\'ve sent a verification email to your inbox.',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _sendVerificationEmail,
                icon: const Icon(Icons.mail),
                label: const Text('Send Verification Email'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4DBFB8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Checking for verification...',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
