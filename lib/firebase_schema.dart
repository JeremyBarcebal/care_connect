// Firebase Firestore Schema Documentation
// This file documents the consistent structure used across the Care Connect application

/*
FIREBASE FIRESTORE STRUCTURE:

┌─ Collection: accounts
│  ├─ Doc: {userUID}
│  │  ├─ name: string (e.g., "John Doe")
│  │  ├─ email: string
│  │  ├─ type: string ("doctor" or "patient") [LOWERCASE - IMPORTANT!]
│  │  ├─ createdAt: timestamp
│  │  │
│  │  └─ [DOCTOR SPECIFIC FIELDS]
│  │     ├─ dob: string (YYYY-MM-DD format)
│  │     ├─ gender: string ("Male" or "Female")
│  │     ├─ mobileNo: string
│  │     ├─ medicalLicenseNumber: string
│  │     ├─ stateProvince: string
│  │     ├─ specialty: string
│  │     ├─ yearsOfExperience: string
│  │     ├─ medicalSchool: string
│  │     ├─ yearOfGraduation: string
│  │     └─ governmentId: string
│  │
│  │  [PATIENT SPECIFIC FIELDS]
│  │     ├─ dob: string (YYYY-MM-DD format)
│  │     ├─ gender: string ("Male" or "Female")
│  │     ├─ mobileNo: string
│  │     ├─ street: string
│  │     ├─ city: string
│  │     ├─ state: string
│  │     ├─ zipCode: string
│  │     ├─ insuranceProvider: string (optional)
│  │     ├─ policyNumber: string (optional)
│  │     ├─ emergencyContact: string
│  │     └─ governmentId: string
│  │
│  │  Subcollection: task
│  │  └─ Doc: {MM-dd-yyyy} (e.g., "11-11-2025")
│  │     └─ tasks: array
│  │        ├─ [0]
│  │        │  ├─ title: string (medicine name)
│  │        │  ├─ time: string (HH:MM AM/PM format)
│  │        │  └─ status: string ("pending" or "completed")
│  │        ├─ [1]
│  │        │  └─ ...
│  │
│  │  Doc: _metadata (metadata only)
│  │     └─ initialized: boolean (true)
│  │
│  └─ Doc: {otherUID}
│     └─ ... (same structure)
│
└─ [Other collections as needed]

IMPORTANT NOTES:
================
1. USER TYPE VALUES: Always use lowercase "doctor" or "patient", NEVER "Doctor" or "Client"
2. DATE FORMAT: Use "MM-dd-yyyy" for task dates (e.g., "11-11-2025")
3. TIME FORMAT: Use "HH:MM AM/PM" format (e.g., "09:00 AM", "02:30 PM")
4. TIMESTAMPS: Always include 'createdAt' with DateTime.now() when creating accounts
5. INITIALIZATION: Always create a task subcollection with _metadata doc during account creation
6. STATUS VALUES: Use "pending", "completed", or other lowercase statuses

CONSISTENCY RULES:
==================
- All type values must be lowercase: "doctor", "patient"
- All field names use camelCase: firstName, lastName, dob, mobileNo
- Dates in Firestore are stored as strings in MM-dd-yyyy format (for compatibility with DateFormat)
- Timestamps use Firestore's DateTime.now() for sorting and filtering

*/
