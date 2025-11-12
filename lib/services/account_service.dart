import 'package:cloud_firestore/cloud_firestore.dart';

/// Service class for managing user accounts in Firestore.
/// Ensures consistent structure and initialization across all account types.
class AccountService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a doctor account with all required fields and initializes task subcollection.
  ///
  /// Parameters:
  /// - [uid]: User's unique ID from Firebase Auth
  /// - [name]: Full name (firstName + lastName)
  /// - [email]: Email address
  /// - [dob]: Date of birth (YYYY-MM-DD format)
  /// - [gender]: Gender ("Male" or "Female")
  /// - [mobileNo]: Mobile number
  /// - [medicalLicenseNumber]: Medical license number
  /// - [stateProvince]: State/Province of licensure
  /// - [specialty]: Medical specialty
  /// - [yearsOfExperience]: Years of experience
  /// - [medicalSchool]: Medical school attended
  /// - [yearOfGraduation]: Year of graduation
  /// - [governmentId]: Government-issued ID
  Future<void> createDoctorAccount({
    required String uid,
    required String name,
    required String email,
    required String dob,
    required String gender,
    required String mobileNo,
    required String medicalLicenseNumber,
    required String stateProvince,
    required String specialty,
    required String yearsOfExperience,
    required String medicalSchool,
    required String yearOfGraduation,
    required String governmentId,
  }) async {
    try {
      await _firestore.collection('accounts').doc(uid).set({
        'name': name,
        'email': email,
        'dob': dob,
        'gender': gender,
        'mobileNo': mobileNo,
        'medicalLicenseNumber': medicalLicenseNumber,
        'stateProvince': stateProvince,
        'specialty': specialty,
        'yearsOfExperience': yearsOfExperience,
        'medicalSchool': medicalSchool,
        'yearOfGraduation': yearOfGraduation,
        'governmentId': governmentId,
        'type': 'doctor',
        'createdAt': DateTime.now(),
      });

      // Initialize task subcollection
      await _initializeTaskSubcollection(uid);
    } catch (e) {
      throw Exception('Failed to create doctor account: $e');
    }
  }

  /// Creates a patient account with all required fields and initializes task subcollection.
  ///
  /// Parameters:
  /// - [uid]: User's unique ID from Firebase Auth
  /// - [name]: Full name (firstName + lastName)
  /// - [email]: Email address
  /// - [dob]: Date of birth (YYYY-MM-DD format)
  /// - [gender]: Gender ("Male" or "Female")
  /// - [mobileNo]: Mobile number
  /// - [street]: Street address
  /// - [city]: City
  /// - [state]: State
  /// - [zipCode]: Zip code
  /// - [insuranceProvider]: Insurance provider (optional)
  /// - [policyNumber]: Policy number (optional)
  /// - [emergencyContact]: Emergency contact
  /// - [governmentId]: Government-issued ID
  Future<void> createPatientAccount({
    required String uid,
    required String name,
    required String email,
    required String dob,
    required String gender,
    required String mobileNo,
    required String street,
    required String city,
    required String state,
    required String zipCode,
    required String insuranceProvider,
    required String policyNumber,
    required String emergencyContact,
    required String governmentId,
  }) async {
    try {
      await _firestore.collection('accounts').doc(uid).set({
        'name': name,
        'email': email,
        'dob': dob,
        'gender': gender,
        'mobileNo': mobileNo,
        'street': street,
        'city': city,
        'state': state,
        'zipCode': zipCode,
        'insuranceProvider': insuranceProvider,
        'policyNumber': policyNumber,
        'emergencyContact': emergencyContact,
        'governmentId': governmentId,
        'type': 'patient',
        'createdAt': DateTime.now(),
      });

      // Initialize task subcollection
      await _initializeTaskSubcollection(uid);
    } catch (e) {
      throw Exception('Failed to create patient account: $e');
    }
  }

  /// Creates a generic account (used by generic signup page).
  ///
  /// Parameters:
  /// - [uid]: User's unique ID from Firebase Auth
  /// - [name]: User's name
  /// - [email]: Email address
  /// - [type]: User type ("doctor" or "patient")
  Future<void> createGenericAccount({
    required String uid,
    required String name,
    required String email,
    required String type,
  }) async {
    try {
      // Normalize type to lowercase
      final normalizedType = type.toLowerCase();
      if (normalizedType != 'doctor' && normalizedType != 'patient') {
        throw Exception(
            'Invalid user type: $type. Must be "doctor" or "patient".');
      }

      await _firestore.collection('accounts').doc(uid).set({
        'name': name,
        'email': email,
        'type': normalizedType,
        'createdAt': DateTime.now(),
      });

      // Initialize task subcollection
      await _initializeTaskSubcollection(uid);
    } catch (e) {
      throw Exception('Failed to create generic account: $e');
    }
  }

  /// Initializes the task subcollection for a user.
  /// This ensures the subcollection exists and can be accessed immediately after account creation.
  Future<void> _initializeTaskSubcollection(String uid) async {
    await _firestore
        .collection('accounts')
        .doc(uid)
        .collection('task')
        .doc('_metadata')
        .set({'initialized': true});
  }
}
