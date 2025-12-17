import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late VideoPlayerController _videoController;
  bool _videoEnded = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initializeFadeAnimation();
    _initializeVideo();
  }

  void _initializeFadeAnimation() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
  }

  Future<void> _initializeVideo() async {
    try {
      _videoController = VideoPlayerController.asset('assets/splashscreen.mp4');

      await _videoController.initialize();

      // Listen for video completion
      _videoController.addListener(() {
        if (_videoController.value.position >=
            _videoController.value.duration) {
          if (!_videoEnded) {
            setState(() {
              _videoEnded = true;
            });
            // Fade out and navigate after video ends
            _fadeController.forward().then((_) {
              if (mounted) {
                _navigateToAppropriateScreen();
              }
            });
          }
        }
      });

      if (mounted) {
        setState(() {});
        _videoController.play();
      }
    } catch (e) {
      print('❌ Error loading video: $e');
      // If video fails to load, navigate appropriately
      if (mounted) {
        _fadeController.forward().then((_) {
          _navigateToAppropriateScreen();
        });
      }
    }
  }

  Future<void> _navigateToAppropriateScreen() async {
    try {
      // Check if user is logged in
      User? currentUser = FirebaseAuth.instance.currentUser;

      if (currentUser != null) {
        // Check if user was manually logged out
        SharedPreferences prefs = await SharedPreferences.getInstance();
        bool isLoggedOut = prefs.getBool('isLoggedOut') ?? false;

        if (!isLoggedOut) {
          // User is still logged in and didn't logout, get user type
          DocumentSnapshot userDoc = await FirebaseFirestore.instance
              .collection('accounts')
              .doc(currentUser.uid)
              .get();

          if (userDoc.exists) {
            Map<String, dynamic> userData =
                userDoc.data() as Map<String, dynamic>;
            String userType =
                (userData['type'] as String?)?.toLowerCase() ?? 'unknown';

            if (currentUser.emailVerified) {
              // Navigate to appropriate page based on user type
              if (userType == 'patient') {
                Navigator.pushReplacementNamed(context, '/client');
                return;
              } else if (userType == 'doctor') {
                Navigator.pushReplacementNamed(context, '/doctor');
                return;
              }
            }
          }
        } else {
          // User was logged out, clear the flag
          await prefs.setBool('isLoggedOut', false);
        }
      }

      // Default navigation to login
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('❌ Error navigating: $e');
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF48A6A7),
      body: _videoController.value.isInitialized
          ? GestureDetector(
              onTap: () {
                // Skip video on tap
                _fadeController.forward().then((_) {
                  if (mounted) {
                    _navigateToAppropriateScreen();
                  }
                });
              },
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _videoController.value.size.width,
                      height: _videoController.value.size.height,
                      child: VideoPlayer(_videoController),
                    ),
                  ),
                ),
              ),
            )
          : const SizedBox.expand(
              child: ColoredBox(
                color: Color(0xFF48A6A7),
              ),
            ),
    );
  }
}
