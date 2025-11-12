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
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                userType = "patient";
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              // backgroundColor: Color(0xFF43AF43),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: userType == "patient"
                                      ? Color(0xFF43AF43)
                                      : Colors
                                          .transparent, // Conditional border color
                                  width: 2, // Border width
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15),
                            ),
                            child: const Text(
                              'Patient',
                              style: TextStyle(
                                color: Colors.black, // Text color
                                fontSize: 16, // Text size
                                fontWeight:
                                    FontWeight.w400, // Optional: Bold text
                              ),
                            ),
                          )),
                      const SizedBox(height: 40),
                      Container(
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                userType = "doctor";
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              // backgroundColor: Color(0xFF43AF43),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: userType == "doctor"
                                      ? Color(0xFF43AF43)
                                      : Colors
                                          .transparent, // Conditional border color
                                  width: 2, // Border width
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15),
                            ),
                            child: const Text(
                              'Doctor',
                              style: TextStyle(
                                color: Colors.black, // Text color
                                fontSize: 16, // Text size
                                fontWeight:
                                    FontWeight.w400, // Optional: Bold text
                              ),
                            ),
                          )),
                      const SizedBox(height: 40),
                      Container(
                          margin: EdgeInsets.symmetric(horizontal: 20),
                          child: ElevatedButton(
                            onPressed: _onProceed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF43AF43),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 40, vertical: 15),
                            ),
                            child: const Text(
                              'Proceed',
                              style: TextStyle(
                                color: Colors.black, // Text color
                                fontSize: 16, // Text size
                                fontWeight:
                                    FontWeight.w400, // Optional: Bold text
                              ),
                            ),
                          )),
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
