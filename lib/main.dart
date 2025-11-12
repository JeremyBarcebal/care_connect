import 'dart:async'; // Import this for using Timer
import 'package:care_connect/pages/not_verified_page.dart';
import 'package:care_connect/pages/signup_doctor_page.dart';
import 'package:care_connect/pages/signup_patient_page.dart';
import 'package:care_connect/pages/user_selection_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'pages/client_page.dart';
import 'pages/doctor_page.dart';
import 'pages/login_page.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: AuthWrapper(),
      routes: {
        '/client': (context) => AuthGuard(child: ClientPage()),
        '/doctor': (context) => AuthGuard(child: DoctorPage()),
        '/signup-patient': (context) => const SignupPatientPage(),
        '/signup-doctor': (context) => const SignupDoctorPage(),
        '/user-select': (context) => UserSelectionPage(),
        '/login': (context) => LoginPage(),
        '/not-verified': (context) => NotVerifiedPage(),
      },
    );
  }
}

class UserDataProvider extends InheritedWidget {
  final Map<String, dynamic>? userData;

  UserDataProvider({Key? key, required Widget child, this.userData})
      : super(key: key, child: child);

  static UserDataProvider? of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<UserDataProvider>();
  }

  @override
  bool updateShouldNotify(UserDataProvider oldWidget) {
    return userData != oldWidget.userData;
  }
}

class AuthWrapper extends StatefulWidget {
  @override
  _AuthWrapperState createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  Timer? _verificationTimer;

  @override
  void dispose() {
    _verificationTimer?.cancel();
    super.dispose();
  }

  void _startVerificationTimer(User user, userData) {
    _verificationTimer?.cancel(); // Cancel any existing timer
    _verificationTimer = Timer.periodic(Duration(seconds: 5), (timer) async {
      await user.reload(); // Reload user to check if email is verified
      user = FirebaseAuth.instance.currentUser!; // Get the updated user
      if (user.emailVerified) {
        // Normalize stored user type to lowercase for consistent comparisons
        String userType =
            (userData['type'] as String?)?.toLowerCase() ?? 'unknown';

        if (userType == 'patient') {
          Navigator.pushReplacementNamed(context, '/client');
        } else if (userType == 'doctor') {
          Navigator.pushReplacementNamed(context, '/doctor');
        } else {
          Navigator.pushReplacementNamed(context, '/login');
        }
        _verificationTimer?.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          User user = snapshot.data!;
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('accounts')
                .doc(user.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (userSnapshot.hasData) {
                var userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;

                if (userData == null) {
                  return LoginPage();
                }

                // Normalize stored user type to lowercase for consistent comparisons
                String userType =
                    (userData['type'] as String?)?.toLowerCase() ?? 'unknown';
                if (user.emailVerified) {
                  return UserDataProvider(
                    userData: userData,
                    child: userType == 'patient'
                        ? ClientPage()
                        : userType == 'doctor'
                            ? DoctorPage()
                            : Center(child: Text('Unknown user type')),
                  );
                } else {
                  // Start the verification timer
                  _startVerificationTimer(user, userData);
                  return NotVerifiedPage();
                }
              } else {
                return LoginPage();
              }
            },
          );
        } else {
          return LoginPage();
        }
      },
    );
  }
}

extension on User {
  get type => String;
}

class AuthGuard extends StatelessWidget {
  final Widget child;
  final bool? isChild;

  const AuthGuard({required this.child, this.isChild});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          User user = snapshot.data!;
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('accounts')
                .doc(user.uid)
                .get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator());
              } else if (userSnapshot.hasData) {
                var userData =
                    userSnapshot.data!.data() as Map<String, dynamic>?;

                if (userData == null) {
                  return LoginPage();
                }

                // Normalize stored user type to lowercase for consistent comparisons
                String userType =
                    (userData['type'] as String?)?.toLowerCase() ?? 'unknown';
                if (user.emailVerified) {
                  return UserDataProvider(
                    userData: userData,
                    child: isChild == true
                        ? this.child
                        : (userType == 'patient'
                            ? ClientPage()
                            : userType == 'doctor'
                                ? DoctorPage()
                                : Center(child: Text('Unknown user type'))),
                  );
                } else {
                  return NotVerifiedPage();
                }
              } else {
                return LoginPage();
              }
            },
          );
        } else {
          Future.microtask(
              () => Navigator.pushReplacementNamed(context, '/login'));
          return SizedBox.shrink();
        }
      },
    );
  }
}
