# Prescription Chat Integration - Complete Workflow

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         CARE CONNECT                            │
│              Prescription Chat Integration System                │
└─────────────────────────────────────────────────────────────────┘

STEP 1: DOCTOR SENDS PRESCRIPTION
─────────────────────────────────────
Doctor in Chat              SendPrescriptionDialog
   │                              │
   │  Clicks 💊 button           │
   ├─────────────────────────────►│
   │                              │
   │                    Auto-filled:
   │                    ✓ Patient Name: John Doe
   │                    ✓ Patient ID: patient_123
   │                              │
   │  Fills form:                 │
   │  - Medicine Name: Aspirin    │
   │  - Dosage: 500mg             │
   │  - Frequency: Twice daily    │
   │  - Time: 09:00 AM            │
   │  - Instructions: Take w/ food│
   │                              │
   │  Clicks "Send Prescription"  │
   │◄─────────────────────────────┤
   │                              │


STEP 2: PRESCRIPTION STORED IN FIRESTORE
────────────────────────────────────────
chats/{chatId}/convo/{messageId}
{
  type: "prescription",
  medicineName: "Aspirin",
  dosage: "500mg",
  frequency: "Twice daily",
  time: "09:00 AM",
  instructions: "Take w/ food",
  status: "pending",
  patientId: "patient_123",
  patientName: "John Doe",
  sender: "{doctorUid}",
  timestamp: serverTimestamp
}


STEP 3: PATIENT RECEIVES PRESCRIPTION IN CHAT
──────────────────────────────────────────────
Chat Screen shows Prescription Card:

┌─────────────────────────────────────┐
│ 💊 Dr. Smith (Doctor)      PENDING  │
├─────────────────────────────────────┤
│ Medicine: Aspirin                   │
│ Dosage: 500mg                       │
│ Frequency: Twice daily              │
│ Time: 09:00 AM                      │
│ Instructions: Take w/ food          │
│                                     │
│ Patient Info:                       │
│   Name: John Doe                    │
│   ID: patient_123                   │
│                                     │
│              [Decline]  [Accept]    │
└─────────────────────────────────────┘


STEP 4A: PATIENT ACCEPTS PRESCRIPTION
──────────────────────────────────────
Patient clicks [Accept]
        │
        ▼
   TaskService.addPrescriptionTask()
        │
        ▼
Firestore: accounts/patient_123/task/11-11-2025
{
  tasks: [
    {
      title: "Aspirin",
      time: "09:00 AM",
      status: "pending"
    }
  ]
}
        │
        ▼
Update Chat Message: status = "accepted"
        │
        ▼
Show Toast: "Prescription accepted! Added to your tasks."


STEP 4B: PATIENT DECLINES PRESCRIPTION
───────────────────────────────────────
Patient clicks [Decline]
        │
        ▼
Update Chat Message: status = "declined"
        │
        ▼
Show Toast: "Prescription declined."
        │
        ▼
No task created


STEP 5: PRESCRIPTION APPEARS ON CLIENT PAGE
────────────────────────────────────────────
Patient Home Screen shows:

┌─────────────────────────────┐
│    TODAY'S PRESCRIPTIONS    │
├─────────────────────────────┤
│ 09:00 AM - Aspirin 500mg   │
│           Status: Pending   │
│           [Mark as Taken]   │
├─────────────────────────────┤
│ 06:00 PM - Paracetamol...  │
│           Status: Pending   │
│           [Mark as Taken]   │
└─────────────────────────────┘

(Fetched from accounts/{uid}/task collection)


FIRESTORE COLLECTIONS MAP
─────────────────────────

accounts/
  └─ {doctorUid}/
       └─ type: "doctor"
  └─ {patientUid}/
       ├─ type: "patient"
       └─ task/
            ├─ 11-10-2025/
            │  └─ tasks: [{title, time, status}, ...]
            └─ 11-11-2025/
               └─ tasks: [{title, time, status}, ...]

chats/
  └─ {chatId}/
       ├─ client: {patientUid}
       ├─ doctor: {doctorUid}
       └─ convo/
            ├─ {messageId1}
            │  ├─ type: "text"
            │  ├─ message: "Hello..."
            │  └─ sender: {uid}
            └─ {messageId2}
               ├─ type: "prescription"
               ├─ medicineName: "Aspirin"
               ├─ status: "accepted"
               └─ ...prescription fields...


KEY FEATURES
────────────

✅ IMPLEMENTED:
  • Doctors can send structured prescriptions in chat
  • Auto-filled patient information (no manual entry needed)
  • Prescription appears as rich card in chat
  • Patients see only when they receive (sender-specific)
  • Accept button creates task in patient's account
  • Decline button marks as declined
  • Status tracking (pending → accepted/declined)
  • Doctor can see response status

⏳ NEXT TASKS:
  1. Display prescriptions on client_page.dart
  2. Add notification reminders when it's time to take medicine
  3. Track prescription adherence (patient completion)
  4. History/archive of prescriptions


FILES CREATED/MODIFIED
──────────────────────

Created:
  • lib/models/prescription_message.dart - Data model
  • lib/pages/client/send_prescription_dialog.dart - Prescription form
  • lib/PRESCRIPTION_CHAT_WORKFLOW.dart - This documentation

Modified:
  • lib/pages/client/chat_page.dart
    - Added prescription message support
    - Added _buildPrescriptionMessage() widget
    - Added _acceptPrescription() handler
    - Added _declinePrescription() handler
    - Added medication button in UI


USAGE FLOW
──────────

For Developers:
1. User data is auto-populated from chat context
2. Prescription is sent as special message type
3. On acceptance, TaskService adds to patient's task collection
4. Client page needs to query task collection to display

For Users:
1. Doctor: Open chat → Click 💊 → Fill form → Send
2. Patient: Receive prescription card → Click Accept/Decline
3. Patient: See prescription in home page (once integrated)

```

## Integration Next Steps

### 1. Update ClientPage to Display Prescriptions
**File:** `lib/pages/client_page.dart`

```dart
// Add to client_page.dart
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('accounts')
    .doc(userId)
    .collection('task')
    .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return Center(child: CircularProgressIndicator());
    }
    
    var tasks = snapshot.data!.docs;
    return ListView.builder(
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        var taskList = (tasks[index]['tasks'] as List?) ?? [];
        return PrescriptionTaskCard(
          tasks: taskList,
          date: tasks[index].id,
        );
      },
    );
  },
)
```

### 2. Create PrescriptionTaskCard Widget
**File:** `lib/widgets/prescription_task_card.dart` (NEW)

```dart
// This widget displays a single prescription task
// Features:
// - Show medicine name, dosage, time
// - Mark as taken
// - Show status
```

### 3. Add Notification Reminders
**File:** `lib/services/prescription_notification_service.dart` (NEW)

```dart
// Watch task collection
// Schedule notifications at medicine time
// Show "Time to take {medicine}!" reminder
```

## Testing Checklist

- [ ] Doctor opens chat with patient
- [ ] Click medication button opens dialog
- [ ] Patient info is auto-filled
- [ ] Can fill all prescription fields
- [ ] Click "Send Prescription"
- [ ] Prescription appears in chat as card
- [ ] Patient sees all details correctly
- [ ] Patient clicks "Accept"
- [ ] Task appears in Firestore: accounts/{uid}/task/{date}
- [ ] Toast shows success message
- [ ] Prescription status in chat changes to "accepted"
- [ ] Patient can click "Decline" instead
- [ ] Declined status updates in chat
- [ ] Open client_page - see prescription list (after UI integration)
