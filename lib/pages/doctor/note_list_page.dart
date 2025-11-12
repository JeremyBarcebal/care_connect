import 'package:care_connect/main.dart';
import 'package:care_connect/pages/client/add_note_page.dart';
import 'package:care_connect/pages/doctor/note_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl; // Alias the intl import

class DoctorNoteListPage extends StatefulWidget {
  const DoctorNoteListPage({super.key});
  @override
  State<DoctorNoteListPage> createState() => _DoctorNoteListPageState();
}

class _DoctorNoteListPageState extends State<DoctorNoteListPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  String? dropdownValue;

  @override
  void initState() {
    super.initState();
  }

  Future<dynamic> _showNoteDetails(DocumentSnapshot note) async {
    User? user = FirebaseAuth.instance.currentUser;
    var timestamp = note['timestamp'];
    var formattedTime = timestamp != null
        ? (timestamp as Timestamp).toDate().toString()
        : 'No timestamp';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Dialog.fullscreen(
              child: Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Note Details:',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 16.0),
                          Text('Content: ${note['content'] ?? 'No content'}'),
                          const SizedBox(height: 10),
                          Text('Timestamp: $formattedTime'),
                          const SizedBox(height: 10),
                          Text(
                              'Client Name: ${note['clientName'] ?? 'Unknown Client'}'),
                          const SizedBox(height: 10),
                          Text(
                              'Client Email: ${note['clientEmail'] ?? 'Unknown Email'}'),
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: const Text('Close'),
                          ),
                          const SizedBox(height: 20),
                          Expanded(
                            child: StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('accounts')
                                  .doc(user?.uid)
                                  .collection('notes')
                                  .doc(note.id)
                                  .collection('comments')
                                  .orderBy('timestamp')
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                      child: CircularProgressIndicator());
                                }
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty) {
                                  return const Center(
                                      child: Text('No comments yet.'));
                                }
                                var comments = snapshot.data!.docs;

                                return ListView.builder(
                                  itemCount: comments.length,
                                  itemBuilder: (context, index) {
                                    var comment = comments[index];
                                    var commentTimestamp = comment['timestamp'];
                                    var commentFormattedTime =
                                        commentTimestamp != null
                                            ? (commentTimestamp as Timestamp)
                                                .toDate()
                                                .toString()
                                            : 'No timestamp';

                                    return ListTile(
                                      title: Text(
                                          comment['content'] ?? 'No content'),
                                      subtitle: Text(commentFormattedTime),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: TextField(
                            controller: _noteController,
                            decoration: const InputDecoration(
                              hintText: 'Add a comment...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8.0),
                        ElevatedButton(
                          onPressed: () async {
                            if (_noteController.text.isNotEmpty) {
                              try {
                                User? user = FirebaseAuth.instance.currentUser;
                                if (user != null) {
                                  await FirebaseFirestore.instance
                                      .collection('accounts')
                                      .doc(user.uid)
                                      .collection('notes')
                                      .doc(note.id)
                                      .collection('comments')
                                      .add({
                                    'content': _noteController.text,
                                    'clientName':
                                        user.displayName ?? 'Anonymous',
                                    'clientId': user.uid,
                                    'timestamp': Timestamp.now()
                                  });

                                  _noteController.clear();
                                }
                              } catch (e) {
                                print("Failed to add comment: $e");
                              }
                            }
                          },
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: AppBar(
          toolbarHeight: 200.0,
          title: const Column(
            children: [
              const SizedBox(height: 20),
              Text(
                "Assigned Notes",
                style: TextStyle(fontSize: 20, color: Colors.white),
              ),
            ],
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFF43AF43),
          shape: RoundedAppBarShape(), // Custom AppBar shape
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: user != null
                ? StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collectionGroup('notes')
                        .where('assignedTo', isEqualTo: user.uid)
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No notes available.'));
                      }

                      var notes = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: notes.length,
                        itemBuilder: (context, index) {
                          var note = notes[index];
                          Timestamp timestamp = note['timestamp'] as Timestamp;
                          DateTime dateTime = timestamp.toDate();
                          print(dateTime);
                          String formattedDate1 =
                              intl.DateFormat('MM/dd/yyyy hh:mm a')
                                  .format(dateTime);
                          return NoteItem(
                              note: note, formattedTime: formattedDate1);
                        },
                      );
                    },
                  )
                : const Center(
                    child: Text('Please log in to view your notes.')),
          ),
        ],
      ),
    );
  }
}

class NoteItem extends StatelessWidget {
  final dynamic note; // Pass the whole note object
  final String formattedTime;

  NoteItem({required this.note, required this.formattedTime});

  @override
  Widget build(BuildContext context) {
    // Extracting values from the note object
    String title = note['patientFeels'];
    String name = note['clientName'];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF43AF43),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          onTap: () {
            final userData = UserDataProvider.of(context)?.userData;
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => NoteDetail(
                        userData,
                        noteData: note,
                      )),
            );
          },
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(
              note != null &&
                      note.data() != null &&
                      note.data().containsKey('approved')
                  ? (note['approved'] == true
                      ? Icons.check_box_rounded
                      : Icons.disabled_by_default_rounded)
                  : Icons.check_box_outline_blank,
              color: Colors.white),
          title: Text(
            title,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            name,
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: Text(
            formattedTime,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class RoundedAppBarShape extends RoundedRectangleBorder {
  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final double radius = 40.0; // Adjust the radius to your preference
    return Path()
      ..moveTo(0, 0)
      ..lineTo(0, rect.height - radius)
      ..quadraticBezierTo(
          0, rect.height, radius, rect.height) // Bottom-left curve
      ..lineTo(rect.width - radius, rect.height)
      ..quadraticBezierTo(rect.width, rect.height, rect.width,
          rect.height - radius) // Bottom-right curve
      ..lineTo(rect.width, 0) // Line to the top-right corner
      ..close(); // Close the path
  }
}
