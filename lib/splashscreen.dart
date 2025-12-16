import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

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
            // Fade out and navigate to login after video ends
            _fadeController.forward().then((_) {
              if (mounted) {
                Navigator.pushReplacementNamed(context, '/login');
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
      // If video fails to load, navigate to login
      if (mounted) {
        _fadeController.forward().then((_) {
          Navigator.pushReplacementNamed(context, '/login');
        });
      }
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
                    Navigator.pushReplacementNamed(context, '/login');
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
