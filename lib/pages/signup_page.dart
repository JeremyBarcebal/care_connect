import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});
  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final List<String> list = <String>['doctor', 'patient'];
  String dropdownValue = 'patient';

  void _signup() async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await _firestore
          .collection('accounts')
          .doc(userCredential.user!.uid)
          .set({
        'name': _nameController.text,
        'email': _emailController.text,
        'type': dropdownValue,
        'createdAt': DateTime.now(),
      });

      // Initialize task subcollection
      await _firestore
          .collection('accounts')
          .doc(userCredential.user!.uid)
          .collection('task')
          .doc('_metadata')
          .set({'initialized': true});

      if (dropdownValue == 'doctor') {
        Navigator.pushReplacementNamed(context, '/doctor');
      } else {
        Navigator.pushReplacementNamed(context, '/client');
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
      _showErrorDialog(context, errorMessage);
    } catch (e) {
      _showErrorDialog(context, 'An unexpected error occurred: $e');
    }
  }

  void _showErrorDialog(BuildContext context, String errorMessage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Signup Error'),
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

  void _login() {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Container(
            height: double.infinity,
            child: Stack(children: [
              Container(
                height: 200,
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFF43AF43),
                ),
                child: const Center(
                    child: Image(
                  image: AssetImage('assets/logo.png'),
                  height: 100,
                  width: 200,
                )),
              ),
              Positioned(
                  top: 150,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 50),
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
                          TextField(
                            controller: _nameController,
                            decoration:
                                const InputDecoration(labelText: 'Name'),
                          ),
                          SizedBox(height: 20),
                          InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Select Option',
                              border: UnderlineInputBorder(),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: dropdownValue,
                                isExpanded: true,
                                icon: Icon(Icons.arrow_drop_down),
                                items: list.map<DropdownMenuItem<String>>(
                                    (String value) {
                                  return DropdownMenuItem<String>(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  setState(() {
                                    dropdownValue = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _emailController,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                          SizedBox(height: 20),
                          TextField(
                            controller: _passwordController,
                            decoration:
                                const InputDecoration(labelText: 'Password'),
                            obscureText: true,
                          ),
                          SizedBox(height: 20),
                          ElevatedButton(
                            onPressed: _signup,
                            child: Text('Sign Up'),
                          ),
                          ElevatedButton(
                            onPressed: _login,
                            child: const Text('Already have a account'),
                          ),
                        ],
                      ),
                    ),
                  ))
            ])));
  }
}
