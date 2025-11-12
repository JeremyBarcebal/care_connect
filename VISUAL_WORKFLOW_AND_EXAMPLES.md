# Prescription System - Visual Workflow & Code Examples

## Visual User Journey

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESCRIPTION FLOW                        │
└─────────────────────────────────────────────────────────────┘

STEP 1: DOCTOR SENDS
────────────────────

Screen: Chat with Patient
┌────────────────────────────┐
│  Dr. Smith (Doctor)    [📞]│
│  ┌──────────────────────┐ │
│  │                      │ │  [💊] ← New button!
│  │  Hello John!         │ │
│  │  How are you today?  │ │
│  │                      │ │
│  └──────────────────────┘ │
│                            │
│  ┌──────────────────────┐ │
│  │ Type message...   [📎]│ │
│  │                 [💊][📤]│ ← Medication button
│  └──────────────────────┘ │
└────────────────────────────┘
            │
            │ Click 💊
            ▼

STEP 2: SEND PRESCRIPTION DIALOG OPENS
──────────────────────────────────────

┌──────────────────────────────────────┐
│      Send Prescription               │
├──────────────────────────────────────┤
│                                      │
│ Patient Information (Auto-filled)   │
│ ┌────────────────────────────────┐  │
│ │ Name: John Doe                 │  │
│ │ ID: patient_uid_123            │  │
│ └────────────────────────────────┘  │
│                                      │
│ Medicine Name *                      │
│ ┌────────────────────────────────┐  │
│ │ Aspirin                        │  │
│ └────────────────────────────────┘  │
│                                      │
│ Dosage *                             │
│ ┌────────────────────────────────┐  │
│ │ 500mg                          │  │
│ └────────────────────────────────┘  │
│                                      │
│ Frequency *                          │
│ ┌────────────────────────────────┐  │
│ │ Twice daily                    │  │
│ └────────────────────────────────┘  │
│                                      │
│ Preferred Time *                     │
│ ┌────────────────────────────────┐  │
│ │ 09:00 AM                       │  │
│ └────────────────────────────────┘  │
│                                      │
│ Instructions (Optional)              │
│ ┌────────────────────────────────┐  │
│ │ Take with food                 │  │
│ └────────────────────────────────┘  │
│                                      │
│    [Cancel]  [Send Prescription]    │
└──────────────────────────────────────┘


STEP 3: PRESCRIPTION APPEARS IN CHAT
───────────────────────────────────

Screen: Chat with Prescription
┌────────────────────────────┐
│  Dr. Smith (Doctor)    [📞]│
├────────────────────────────┤
│                            │
│  ┌──────────────────────┐ │
│  │  Hello John!         │ │
│  │  How are you today?  │ │
│  └──────────────────────┘ │
│                            │
│               ┌──────────────────────────┐
│               │ 💊 Dr. Smith  │ PENDING │
│               ├──────────────────────────┤
│               │ Medicine: Aspirin        │
│               │ Dosage: 500mg            │
│               │ Frequency: Twice daily   │
│               │ Time: 09:00 AM           │
│               │ Instructions: Take with  │
│               │                  food    │
│               │                          │
│               │ Patient Info:            │
│               │   Name: John Doe         │
│               │   ID: patient_uid_123    │
│               │                          │
│               │  [Decline]  [Accept]    │
│               └──────────────────────────┘
│                            │
│  ┌──────────────────────┐ │
│  │ Type message...   [📎]│ │
│  │                 [💊][📤]│
│  └──────────────────────┘ │
└────────────────────────────┘


STEP 4A: PATIENT ACCEPTS
────────────────────────

Patient clicks [Accept]
        │
        ▼
┌──────────────────────────┐
│ ✓ Prescription accepted! │
│   Added to your tasks.   │
└──────────────────────────┘
        │
        ▼
Firestore Updated:
accounts/patient_uid_123/task/11-11-2025
{
  tasks: [{
    title: "Aspirin",
    time: "09:00 AM",
    status: "pending"
  }]
}
        │
        ▼
Chat Message Updated:
chats/{chatId}/convo/{msgId}
status: "accepted" ← Changed from "pending"


STEP 4B: PATIENT DECLINES
─────────────────────────

Patient clicks [Decline]
        │
        ▼
┌──────────────────────────┐
│ Prescription declined.   │
└──────────────────────────┘
        │
        ▼
Chat Message Updated:
chats/{chatId}/convo/{msgId}
status: "declined"

(No task created)


STEP 5: PRESCRIPTION VISIBLE IN CLIENT PAGE
─────────────────────────────────────────

Screen: Patient Home (To be implemented)
┌────────────────────────────┐
│     Patient Dashboard      │
├────────────────────────────┤
│                            │
│  TODAY'S PRESCRIPTIONS     │
│                            │
│  ┌──────────────────────┐  │
│  │ 09:00 AM             │  │
│  │ Aspirin - 500mg      │  │
│  │ Twice daily          │  │
│  │ Status: Pending      │  │
│  │  [Mark as Taken]     │  │
│  └──────────────────────┘  │
│                            │
│  ┌──────────────────────┐  │
│  │ 06:00 PM             │  │
│  │ Paracetamol - 1000mg │  │
│  │ Once at night        │  │
│  │ Status: Pending      │  │
│  │  [Mark as Taken]     │  │
│  └──────────────────────┘  │
│                            │
└────────────────────────────┘
```

## Code Examples

### Example 1: Doctor Sends Prescription
```dart
// In ChatPage, when doctor clicks medication button:
void _showSendPrescriptionDialog() {
  showDialog(
    context: context,
    builder: (context) => SendPrescriptionDialog(
      patientId: widget.chatData['client'],           // Auto-filled
      patientName: widget.chatData['clientName'],     // Auto-filled
      onSend: (prescription) {
        _sendPrescriptionMessage(prescription);
      },
    ),
  );
}
```

### Example 2: Prescription Sent to Chat
```dart
// SendPrescriptionDialog creates this in Firestore:
await FirebaseFirestore.instance
    .collection('chats')
    .doc(widget.chatDocumentId)
    .collection('convo')
    .add({
  'type': 'prescription',              // Type identifier
  'medicineName': 'Aspirin',
  'dosage': '500mg',
  'frequency': 'Twice daily',
  'instructions': 'Take with food',
  'time': '09:00 AM',
  'status': 'pending',                 // Initial status
  'patientId': 'patient_uid_123',      // Auto-filled
  'patientName': 'John Doe',           // Auto-filled
  'sender': 'doctor_uid_456',
  'timestamp': FieldValue.serverTimestamp(),
});
```

### Example 3: Patient Accepts Prescription
```dart
// When patient clicks [Accept]:
Future<void> _acceptPrescription(
  Map<String, dynamic> prescription,
  String messageDocId,
) async {
  try {
    // Step 1: Add to patient's task collection
    await _taskService.addPrescriptionTask(
      prescription['patientId'],        // patient_uid_123
      prescription['medicineName'],     // Aspirin
      prescription['time'],             // 09:00 AM
    );

    // Step 2: Update chat message status
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(widget.chatDocumentId)
        .collection('convo')
        .doc(messageDocId)
        .update({'status': 'accepted'});

    // Step 3: Show success
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prescription accepted! Added to your tasks.'),
        backgroundColor: Colors.green,
      ),
    );
  } catch (e) {
    // Handle error
  }
}
```

### Example 4: Display in Firestore
```dart
// Result in Firestore after acceptance:

// In chat (persistent record):
chats/chat_123/convo/msg_456
{
  type: "prescription",
  medicineName: "Aspirin",
  status: "accepted"  ← Updated
  // ... other fields ...
}

// In patient's tasks (action item):
accounts/patient_uid_123/task/11-11-2025
{
  tasks: [
    {
      title: "Aspirin",
      time: "09:00 AM",
      status: "pending"
    }
  ]
}
```

### Example 5: Render Prescription Card
```dart
// The _buildPrescriptionMessage widget renders the card:
Widget _buildPrescriptionMessage(
  Map<String, dynamic> messageData,
  String sender,
  bool isCurrUser,
  bool showAcceptButton,
  String messageDocId,
) {
  final status = messageData['status'] ?? 'pending';
  
  return Container(
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.green, width: 1.5),
    ),
    child: Column(
      children: [
        // Header with doctor name and status badge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('💊 ${sender}'),
            Container(
              decoration: BoxDecoration(
                color: status == 'accepted' ? Colors.green : Colors.orange,
              ),
              child: Text(status.toUpperCase()),
            ),
          ],
        ),
        
        // Prescription details
        _buildPrescriptionDetail('Medicine', messageData['medicineName']),
        _buildPrescriptionDetail('Dosage', messageData['dosage']),
        _buildPrescriptionDetail('Frequency', messageData['frequency']),
        _buildPrescriptionDetail('Time', messageData['time']),
        
        // Patient info
        Container(
          child: Column(
            children: [
              Text('Name: ${messageData['patientName']}'),
              Text('ID: ${messageData['patientId']}'),
            ],
          ),
        ),
        
        // Accept/Decline buttons (only for patient)
        if (showAcceptButton && status == 'pending')
          Row(
            children: [
              ElevatedButton(
                onPressed: () => _declinePrescription(messageDocId),
                child: Text('Decline'),
              ),
              ElevatedButton(
                onPressed: () => _acceptPrescription(messageData, messageDocId),
                child: Text('Accept'),
              ),
            ],
          ),
      ],
    ),
  );
}
```

## Firebase Collections Visualization

```
Firestore Database Structure
────────────────────────────

accounts/
├─ doctor_uid_456/
│  └─ type: "doctor"
│
└─ patient_uid_123/
   ├─ type: "patient"
   ├─ name: "John Doe"
   ├─ email: "john@example.com"
   └─ task/
      ├─ 11-10-2025/
      │  └─ tasks: [...]
      └─ 11-11-2025/
         └─ tasks: [
              {
                title: "Aspirin",
                time: "09:00 AM",
                status: "pending"
              },
              {
                title: "Paracetamol",
                time: "06:00 PM",
                status: "pending"
              }
            ]

chats/
├─ chat_123/
│  ├─ client: "patient_uid_123"
│  ├─ doctor: "doctor_uid_456"
│  ├─ doctorName: "Dr. Smith"
│  ├─ clientName: "John Doe"
│  └─ convo/
│     ├─ msg_001/
│     │  ├─ type: "text"
│     │  ├─ message: "Hello John!"
│     │  ├─ sender: "doctor_uid_456"
│     │  └─ timestamp: 2025-11-11T10:00:00
│     │
│     └─ msg_002/
│        ├─ type: "prescription"
│        ├─ medicineName: "Aspirin"
│        ├─ dosage: "500mg"
│        ├─ frequency: "Twice daily"
│        ├─ time: "09:00 AM"
│        ├─ instructions: "Take with food"
│        ├─ status: "accepted"
│        ├─ patientId: "patient_uid_123"
│        ├─ patientName: "John Doe"
│        ├─ sender: "doctor_uid_456"
│        └─ timestamp: 2025-11-11T10:05:00
```

## Integration Points for Next Phase

### Phase 1: Display on Client Page
Location: `lib/pages/client_page.dart`

```dart
// Query pattern:
StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
    .collection('accounts')
    .doc(userId)
    .collection('task')
    .snapshots(),
  builder: (context, snapshot) {
    // Parse tasks and display them
  },
)
```

### Phase 2: Add Notifications
Location: `lib/services/prescription_notification_service.dart`

```dart
// Watch for time and schedule notification
if (currentTime >= prescriptionTime) {
  flutterLocalNotificationsPlugin.show(
    id,
    'Time to take your medicine',
    'Take ${medicineName} now',
    notificationDetails,
  );
}
```

## Testing Commands

```bash
# Build and run
flutter pub get
flutter run

# Run analyze
flutter analyze

# Run with verbose
flutter run -v
```

## Troubleshooting

**Q: Prescription doesn't appear in chat?**
A: Check that `type: 'prescription'` is being saved to Firestore

**Q: Accept button not showing?**
A: Verify patient is viewing (isPatient && !isCurrUser) and status == 'pending'

**Q: Task not created after accept?**
A: Check TaskService.addPrescriptionTask() and Firestore permissions

**Q: Date format wrong in tasks?**
A: Verify DateFormat('MM-dd-yyyy') in TaskService
