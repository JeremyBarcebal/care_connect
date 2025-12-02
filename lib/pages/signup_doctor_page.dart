import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupDoctorPage extends StatefulWidget {
  const SignupDoctorPage({super.key});

  @override
  _SignupDoctorPageState createState() => _SignupDoctorPageState();
}

class _SignupDoctorPageState extends State<SignupDoctorPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String dropdownValue = 'Doctor';

  final Map<String, TextEditingController> _controllers = {
    'email': TextEditingController(),
    'password': TextEditingController(),
    'firstName': TextEditingController(),
    'lastName': TextEditingController(),
    'dob': TextEditingController(),
    'mobileNo': TextEditingController(),
    'medicalLicenseNumber': TextEditingController(),
    'stateProvince': TextEditingController(),
    'specialty': TextEditingController(),
    'yearsOfExperience': TextEditingController(),
    'medicalSchool': TextEditingController(),
    'yearOfGraduation': TextEditingController(),
    'governmentId': TextEditingController(),
    'confirmPassword': TextEditingController(),
  };

  String? _selectedGender = 'Male';

  void _signup() async {
    try {
      if (_controllers['password']!.text !=
          _controllers['confirmPassword']!.text) {
        _showErrorDialog(context, 'Passwords do not match');
        return;
      }

      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: _controllers['email']!.text,
        password: _controllers['password']!.text,
      );

      await userCredential.user!.sendEmailVerification();

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
        'medicalLicenseNumber': _controllers['medicalLicenseNumber']!.text,
        'stateProvince': _controllers['stateProvince']!.text,
        'specialty': _controllers['specialty']!.text,
        'yearsOfExperience': _controllers['yearsOfExperience']!.text,
        'medicalSchool': _controllers['medicalSchool']!.text,
        'yearOfGraduation': _controllers['yearOfGraduation']!.text,
        'governmentId': _controllers['governmentId']!.text,
        'type': 'doctor',
        'createdAt': DateTime.now(),
      });

      // Initialize task subcollection for the doctor
      await _firestore
          .collection('accounts')
          .doc(userCredential.user!.uid)
          .collection('task')
          .doc('_metadata')
          .set({'initialized': true});

      Navigator.pushReplacementNamed(context, '/doctor');
    } catch (e) {
      _showErrorDialog(context, e.toString());
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
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _controllers[key],
        obscureText: obscureText,
        readOnly: readOnly,
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
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
                    fontSize: 26,
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
                  height: 650,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                  ),
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 30, vertical: 40),
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
                          _buildTextField('medicalLicenseNumber',
                              'Medical License Number:'),
                          _buildTextField(
                              'stateProvince', 'State/Province of Licensure:'),
                          _buildTextField('specialty', 'Specialty:'),
                          _buildTextField(
                              'yearsOfExperience', 'Years of Experience:'),
                          _buildTextField(
                              'medicalSchool', 'Medical School Attended:'),
                          _buildTextField(
                              'yearOfGraduation', 'Year of Graduation:'),
                          _buildTextField(
                              'governmentId', 'Government-issued ID:'),
                          _buildTextField('password', 'Password:',
                              obscureText: true),
                          _buildTextField(
                              'confirmPassword', 'Confirm Password:',
                              obscureText: true),
                          const SizedBox(height: 20),
                          _buildSignUpButton(),
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
      margin: const EdgeInsets.only(bottom: 25),
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: _selectedGender,
        decoration: InputDecoration(
          labelText: label,
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
          backgroundColor: const Color(0xFF4DBFB8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: const Text(
          'SIGN UP',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
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
            style: TextStyle(color: Colors.black87, fontSize: 14),
          ),
          GestureDetector(
            onTap: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text(
              'Login',
              style: TextStyle(
                color: Color(0xFF4DBFB8),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
