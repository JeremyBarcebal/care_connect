import 'dart:async';
import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

// Global error handler to catch uncaught exceptions
void _setupGlobalErrorHandling() {
  FlutterError.onError = (FlutterErrorDetails details) {
    print('🔴 FLUTTER ERROR: ${details.exception}');
    print('📋 Stack trace: ${details.stack}');
    FlutterError.dumpErrorToConsole(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    print('🔴 PLATFORM ERROR: $error');
    print('📋 Stack trace: $stack');
    return true;
  };
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false; // Track loading state

  // Focus nodes to detect focus and show highlight
  late FocusNode _emailFocusNode;
  late FocusNode _passwordFocusNode;

  // Password visibility
  bool _obscurePassword = true;

  void _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      _showErrorDialog(context, 'Please enter both email and password.');
      return;
    }

    final email = _emailController.text.trim();

    if (!email.contains('@')) {
      _showErrorDialog(context, 'Please enter a valid email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 🔐 Firebase login
      final userCredential = await _auth
          .signInWithEmailAndPassword(
            email: email,
            password: _passwordController.text,
          )
          .timeout(const Duration(seconds: 30));

      final userId = userCredential.user?.uid;

      if (userId == null || userId.isEmpty) {
        throw Exception('Invalid user ID.');
      }

      // 📄 Fetch user document
      final userDoc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .get()
          .timeout(const Duration(seconds: 15));

      if (!userDoc.exists) {
        _showErrorDialog(context, 'User data not found.');
        return;
      }

      final userType = userDoc['type'] ?? '';

      if (!mounted) return;

      // 🚀 Navigate
      if (userType == 'Doctor') {
        Navigator.pushReplacementNamed(context, '/doctor');
      } else {
        Navigator.pushReplacementNamed(context, '/client');
      }
    }

    // ✅ ONLY catch FirebaseAuthException
    on FirebaseAuthException catch (e) {
      final errorMessage = _getFirebaseAuthErrorMessage(e);
      _showErrorDialog(context, errorMessage);
    }

    // ⏱ Timeout
    on TimeoutException {
      _showErrorDialog(
        context,
        'Request timed out. Please check your internet connection and try again.',
      );
    }

    // 🧯 Any other unexpected error
    catch (e) {
      _showErrorDialog(
        context,
        'Login failed. Please try again.',
      );
      debugPrint('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Parse any exception and return user-friendly message
  String _getGeneralErrorMessage(dynamic exception) {
    print('🔍 Parsing exception type: ${exception.runtimeType}');

    // Handle FirebaseAuthException
    if (exception is FirebaseAuthException) {
      return _getFirebaseAuthErrorMessage(exception);
    }

    // Handle PlatformException (for platform-level errors)
    if (exception is PlatformException) {
      return _getPlatformErrorMessage(exception);
    }

    // Handle TimeoutException
    if (exception is TimeoutException) {
      print('🔍 TimeoutException detected');
      return 'Request timed out. Please check your internet connection and try again.';
    }

    // Handle by string matching if it's wrapped somehow
    final exceptionString = exception.toString().toUpperCase();

    if (exceptionString.contains('ERROR_INVALID_CREDENTIAL') ||
        exceptionString.contains('INVALID_CREDENTIAL') ||
        exceptionString.contains('The supplied auth credential')) {
      return 'Email or password is incorrect. Please check and try again.';
    } else if (exceptionString.contains('USER_NOT_FOUND') ||
        exceptionString.contains('No user record')) {
      return 'No account found with this email. Please check your email or create a new account.';
    } else if (exceptionString.contains('WRONG_PASSWORD')) {
      return 'Incorrect password. Please try again.';
    } else if (exceptionString.contains('TOO_MANY_REQUESTS')) {
      return 'Too many failed login attempts. Please wait a moment and try again.';
    } else if (exceptionString.contains('NETWORK') ||
        exceptionString.contains('CONNECTION') ||
        exceptionString.contains('TIMEOUT')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (exceptionString.contains('USER_DISABLED')) {
      return 'This account has been disabled. Please contact support.';
    }

    return 'Login failed. Please try again. Error: ${exception.toString()}';
  }

  /// Get user-friendly error message for Firebase Auth errors
  String _getFirebaseAuthErrorMessage(FirebaseAuthException e) {
    print(
        '🔍 Firebase error details: code=${e.code}, plugin=${e.plugin}, message=${e.message}');

    switch (e.code) {
      case 'user-not-found':
        return 'No account found with this email. Please check your email or create a new account.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-email':
        return 'The email address is invalid. Please enter a valid email.';
      case 'invalid-credential':
        return 'Email or password is incorrect. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'Login operation is temporarily unavailable. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection and try again.';
      case 'service-disabled':
        return 'The login service is currently unavailable. Please try again later.';
      default:
        return 'Login failed: ${e.message ?? 'Please try again'}';
    }
  }

  /// Get user-friendly error message for Platform errors
  String _getPlatformErrorMessage(PlatformException e) {
    print('🔍 Platform error details: code=${e.code}, message=${e.message}');

    // Map various platform error codes to user-friendly messages
    final errorCode = e.code.toUpperCase();

    if (errorCode.contains('INVALID_CREDENTIAL') ||
        errorCode.contains('WRONG_PASSWORD') ||
        errorCode.contains('USER_NOT_FOUND')) {
      return 'Email or password is incorrect. Please try again.';
    } else if (errorCode.contains('TOO_MANY_REQUESTS')) {
      return 'Too many failed login attempts. Please wait a moment and try again.';
    } else if (errorCode.contains('USER_DISABLED')) {
      return 'This account has been disabled. Please contact support.';
    } else if (errorCode.contains('NETWORK') ||
        errorCode.contains('CONNECTION')) {
      return 'Network error. Please check your internet connection and try again.';
    } else if (errorCode.contains('OPERATION_NOT_ALLOWED') ||
        errorCode.contains('NOT_ALLOWED')) {
      return 'Login operation is temporarily unavailable. Please try again later.';
    } else {
      return 'Login failed: ${e.message ?? e.code}';
    }
  }

  @override
  void initState() {
    super.initState();
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();

    // When focus changes, rebuild to show highlight
    _emailFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _passwordFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _createAccount() {
    Navigator.pushReplacementNamed(context, '/user-select');
  }

  void _showErrorDialog(BuildContext context, String errorMessage) {
    // Use try-catch to prevent crashes from dialog display
    try {
      // First, try to hide keyboard
      FocusScope.of(context).unfocus();

      // Try to show SnackBar with better visibility
      if (mounted && context.mounted) {
        // Clear any existing snackbars first
        ScaffoldMessenger.of(context).clearSnackBars();

        // Show the error snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    errorMessage,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE74C3C), // Red error color
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 6,
          ),
        );
        print('✓ Error snackbar displayed: $errorMessage');
      }
    } catch (e) {
      print('❌ SnackBar failed: $e');
      // If SnackBar fails, just log it - don't crash
      // Don't fall back to dialog as it blocks the UI
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Teal header with logo
          Container(
            height: 400,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF48A6A7), // Teal color from mockup
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Image(
                  image: AssetImage('assets/logo.png'),
                  height: 300,
                  width: 300,
                ),
              ],
            ),
          ),
          // White card with form nibalot sa tibuok nga screen nga naay email ug password
          Align(
            alignment: Alignment.bottomCenter,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(80),
                topRight: Radius.circular(80),
              ),
              child: Container(
                height: 560,
                width: double.infinity,
                color: Colors.white,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 30, vertical: 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Email field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _emailFocusNode.hasFocus
                                  ? const Color(0xFF006A71)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: TextField(
                            focusNode: _emailFocusNode,
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: 'Email:',
                              hintStyle: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Password field
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _passwordFocusNode.hasFocus
                                  ? const Color(0xFF006A71)
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: TextField(
                            focusNode: _passwordFocusNode,
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              hintText: 'Password:',
                              hintStyle: const TextStyle(
                                fontSize: 14,
                                color: Colors.black54,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 16),
                              suffixIcon: IconButton(
                                icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    color: const Color(0xFF006A71)),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Login button
                        _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : SizedBox(
                                height: 50,
                                child: ElevatedButton(
                                  onPressed: _login,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF006A71),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                  ),
                                  child: const Text(
                                    'LOGIN',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                        const SizedBox(height: 32),
                        // Divider with "or"
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                color: Colors.grey[400],
                                thickness: 1,
                              ),
                            ),
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                color: Colors.grey[400],
                                thickness: 1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Google login (icon only)
                        Center(
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(
                                  color: Colors.grey[300]!, width: 1),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            padding: const EdgeInsets.all(12),
                            child: const Icon(
                              Icons.account_circle,
                              size: 32,
                              color: Color(0xFF006A71),
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Signup link
                        Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Don\'t have an account yet? ',
                                style: TextStyle(
                                  color: Colors.black87,
                                  fontSize: 14,
                                ),
                              ),
                              GestureDetector(
                                onTap: _createAccount,
                                child: const Text(
                                  'Create one.',
                                  style: TextStyle(
                                    color: Color(0xFF4DBFB8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}
