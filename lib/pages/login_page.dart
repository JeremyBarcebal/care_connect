import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  bool _isLoading = false; // Track loading state

  void _login() async {
  setState(() {
    _isLoading = true; // Show loader
  });

  try {
    UserCredential userCredential = await _auth.signInWithEmailAndPassword(
      email: _emailController.text,
      password: _passwordController.text,
    );

    String userId = userCredential.user?.uid ?? '';

    if (userId.isNotEmpty) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        String userType = userDoc['type'] ?? '';

        if (userType == 'Doctor') {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/doctor');
          }
        } else {
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/client');
          }
        }
      } else {
        if (mounted) {
          _showErrorDialog(context, 'User data not found in Firestore.');
        }
      }
    } else {
      if (mounted) {
        _showErrorDialog(context, 'User ID is invalid.');
      }
    }
  } on FirebaseAuthException catch (e) {
    String errorMessage = '';
    if (e.code == 'user-not-found') {
      errorMessage = 'No user found for that email.';
    } else if (e.code == 'wrong-password') {
      errorMessage = 'Incorrect password.';
    } else if (e.code == 'invalid-email') {
      errorMessage = 'The email address is not valid.';
    } else {
      errorMessage = 'An unknown error occurred: ${e.message}';
    }
    if (mounted) {
      _showErrorDialog(context, errorMessage);
    }
  } catch (e) {
    if (mounted) {
      _showErrorDialog(context, 'An unexpected error occurred: $e');
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false; // Hide loader
      });
    }
  }
}


  void _createAccount() {
    Navigator.pushReplacementNamed(context, '/user-select');
  }

  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Login Error'),
          content: Text(errorMessage),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        child: Stack(
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF43AF43),
              ),
              child: const Center(
                  child: Image(
                image: AssetImage('assets/logo.png'),
                height: 200,
                width: 300,
              )),
            ),
            Positioned(
              top: 250,
              left: 0,
              right: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 50),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(50),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 40),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        margin: EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            labelText: 'Email:',
                            labelStyle: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        margin: EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password:',
                            labelStyle: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w400,
                            ),
                            border: InputBorder.none,
                          ),
                          obscureText: true,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Show loader or button based on loading state
                      _isLoading
                          ? Center(child: CircularProgressIndicator())
                          : Container(
                              margin: EdgeInsets.symmetric(horizontal: 20),
                              child: ElevatedButton(
                                onPressed: _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF43AF43),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40, vertical: 15),
                                ),
                                child: const Text(
                                  'LOGIN',
                                  style: TextStyle(
                                    color: Colors.black, // Text color
                                    fontSize: 16, // Text size
                                    fontWeight: FontWeight.w400, // Optional: Bold text
                                  ),
                                ),
                              ),
                            ),
                      const SizedBox(height: 40),
                      Container(
                          margin: EdgeInsets.symmetric(horizontal: 15),
                          child: const Row(
                            children: <Widget>[
                              Expanded(
                                child: Divider(
                                  color: Colors.grey,
                                  thickness: 1,
                                ),
                              ),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Divider(
                                  color: Colors.grey,
                                  thickness: 1,
                                ),
                              ),
                            ],
                          )),
                      const SizedBox(height: 40),
                      Container(
                        margin: EdgeInsets.symmetric(horizontal: 15),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text(
                              'Don’t have an account yet?',
                            ),
                            GestureDetector(
                              onTap: _createAccount,
                              child: const Text(
                                ' Create one.',
                                style: TextStyle(
                                  color: Color(0xFF43AF43),
                                ),
                              ),
                            )
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
