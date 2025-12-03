import 'package:flutter/material.dart';

class UserSelectionPage extends StatefulWidget {
  @override
  _UserSelectionPageState createState() => _UserSelectionPageState();
}

class _UserSelectionPageState extends State<UserSelectionPage> {
  String userType = ''; // List to hold doctor names

  void _createAccount() {
    Navigator.pushReplacementNamed(context, '/signup');
  }

  void _onProceed() {
    if (userType == '') {
      return;
    }
    if (userType == 'patient') {
      Navigator.pushReplacementNamed(context, '/signup-patient');
    } else {
      Navigator.pushReplacementNamed(context, '/signup-doctor');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Teal header with logo
            Container(
              height: 400,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF4DBFB8), // Teal color from login page
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
            // White card with selection options
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
                          horizontal: 30, vertical: 50),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Patient button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  userType = "patient";
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: userType == "patient"
                                    ? const Color(0xFF4DBFB8)
                                    : Colors.white,
                                side: BorderSide(
                                  color: userType == "patient"
                                      ? const Color(0xFF4DBFB8)
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Patient',
                                style: TextStyle(
                                  color: userType == "patient"
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          // Doctor button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  userType = "doctor";
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: userType == "doctor"
                                    ? const Color(0xFF4DBFB8)
                                    : Colors.white,
                                side: BorderSide(
                                  color: userType == "doctor"
                                      ? const Color(0xFF4DBFB8)
                                      : Colors.grey[300]!,
                                  width: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: Text(
                                'Doctor',
                                style: TextStyle(
                                  color: userType == "doctor"
                                      ? Colors.white
                                      : Colors.black87,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),
                          // Proceed button
                          SizedBox(
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _onProceed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF4DBFB8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'PROCEED',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
      ),
    );
  }
}
