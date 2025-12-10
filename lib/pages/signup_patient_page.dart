import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPatientPage extends StatefulWidget {
  const SignupPatientPage({super.key});

  @override
  _SignupPatientPageState createState() => _SignupPatientPageState();
}

class _SignupPatientPageState extends State<SignupPatientPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Combine TextEditingControllers into a Map
  final Map<String, TextEditingController> _controllers = {
    'email': TextEditingController(),
    'password': TextEditingController(),
    'name': TextEditingController(),
    'firstName': TextEditingController(),
    'lastName': TextEditingController(),
    'dob': TextEditingController(),
    'mobileNo': TextEditingController(),
    'street': TextEditingController(),
    'city': TextEditingController(),
    'state': TextEditingController(),
    'zipCode': TextEditingController(),
    'insuranceProvider': TextEditingController(),
    'policyNumber': TextEditingController(),
    'emergencyContact': TextEditingController(),
    'governmentId': TextEditingController(),
    'confirmPassword': TextEditingController(),
  };

  String? _selectedGender = 'Male';
  String dropdownValue = 'Client';
  bool _isLoading = false; // Track loading state

  void _signup() async {
    try {
      if (_controllers['password']!.text !=
          _controllers['confirmPassword']!.text) {
        _showErrorDialog(context, 'Passwords do not match');
        return;
      }
      setState(() {
        _isLoading = true; // Show loader
      });
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _controllers['email']!.text,
        password: _controllers['password']!.text,
      );

      await _firestore
          .collection('accounts')
          .doc(userCredential.user!.uid)
          .set({
        'name':
            '${_controllers['firstName']!.text} ${_controllers['lastName']!.text}',
        'email': _controllers['email']!.text,
        'dob': _controllers['dob']!.text,
        'gender': _selectedGender,
        'mobileNo': _controllers['mobileNo']!.text,
        'street': _controllers['street']!.text,
        'city': _controllers['city']!.text,
        'state': _controllers['state']!.text,
        'zipCode': _controllers['zipCode']!.text,
        'insuranceProvider': _controllers['insuranceProvider']!.text,
        'policyNumber': _controllers['policyNumber']!.text,
        'emergencyContact': _controllers['emergencyContact']!.text,
        'governmentId': _controllers['governmentId']!.text,
        'type': 'patient',
        'createdAt': DateTime.now(),
      });

      // Initialize task subcollection for the patient
      await _firestore
          .collection('accounts')
          .doc(userCredential.user!.uid)
          .collection('task')
          .doc('_metadata')
          .set({'initialized': true});

      Navigator.pushReplacementNamed(
        context,
        dropdownValue == 'Doctor' ? '/doctor' : '/client',
      );
    } catch (e) {
      _showErrorDialog(context, e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false; // Hide loader
        });
      }
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Signup Error'),
        content: Text(message),
        actions: [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String key, String label,
      {bool obscureText = false, bool readOnly = false, VoidCallback? onTap}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color:  Colors.grey[300],
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: _controllers[key],
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/user-select');
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Teal header with title
            Container(
              height: 300,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF4DBFB8),
              ),
              child: const Center(
                child: Text(
                  'Sign Up',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            // White card with form
            Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(80),
                  topRight: Radius.circular(80),
                ),
                child: Container(
                  height: 640,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 40, vertical: 50),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTextField('firstName', 'First Name:'),
                          _buildTextField('lastName', 'Last Name:'),
                          _buildTextField('dob', 'Date of Birth:',
                              readOnly: true, onTap: _pickDate),
                          _buildDropdownField('Gender:', ['Male', 'Female']),
                          _buildTextField('mobileNo', 'Mobile No:'),
                          _buildTextField('email', 'Email:'),
                          _buildTextField('street', 'Street:'),
                          _buildTextField('city', 'City:'),
                          _buildTextField('state', 'State:'),
                          _buildTextField('zipCode', 'Zip Code:'),
                          _buildTextField('insuranceProvider',
                              'Insurance Provider (if applicable):'),
                          _buildTextField(
                              'policyNumber', 'Policy Number (if applicable):'),
                          _buildTextField(
                              'emergencyContact', 'Emergency Contact:'),
                          _buildTextField(
                              'governmentId', 'Government-issued ID:'),
                          _buildTextField('password', 'Password:',
                              obscureText: true),
                          _buildTextField(
                              'confirmPassword', 'Confirm Password:',
                              obscureText: true),
                          const SizedBox(height: 20),
                          _isLoading
                              ? Center(child: CircularProgressIndicator())
                              : _buildSignUpButton(),
                          const SizedBox(height: 20),
                          _buildLoginRedirect(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDropdownField(String label, List<String> items) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color:  Color(0xFF9ACBD0).withOpacity(0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            fontSize: 14,
            color: Colors.black,
            fontWeight: FontWeight.w400,
          ),
          border: InputBorder.none,
        ),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: (newValue) => setState(() => _selectedGender = newValue),
      ),
    );
  }

  void _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (pickedDate != null) {
      setState(() {
        _controllers['dob']!.text = "${pickedDate.toLocal()}".split(' ')[0];
      });
    }
  }

  Widget _buildSignUpButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: _signup,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF006A71),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: const Text(
          'SIGN UP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildLoginRedirect() {
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Have an account? ',
            style: TextStyle(color: Colors.black87, fontSize: 12),
          ),
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text(
              'Login',
              style: TextStyle(
                color: Color(0xFF4DBFB8),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
