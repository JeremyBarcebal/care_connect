import 'package:flutter/material.dart';
import 'package:intl/intl.dart';  // For date formatting
import 'package:cloud_firestore/cloud_firestore.dart';  // Firestore package
import 'package:firebase_auth/firebase_auth.dart';  // Firebase Auth package

class TaskPage extends StatefulWidget {
  @override
  _TaskPageState createState() => _TaskPageState();
}
class _TaskPageState extends State<TaskPage> {
  DateTime _currentWeekStart = DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  DateTime? _selectedDate = DateTime.now();  // Default selected date to today

  // Get current user's UID
  final String userId = FirebaseAuth.instance.currentUser!.uid;

  // Method to get the name of the month dynamically
  String get currentMonth => DateFormat.MMMM().format(_currentWeekStart);

  // Get the days of the current week
  List<DateTime> get weekDays {
    return List.generate(7, (index) {
      return _currentWeekStart.add(Duration(days: index));
    });
  }

  // Go to the previous week
  void _previousWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.subtract(Duration(days: 7));
    });
  }

  // Go to the next week
  void _nextWeek() {
    setState(() {
      _currentWeekStart = _currentWeekStart.add(Duration(days: 7));
    });
  }

  // Select date
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
  }

  // Add a task to Firestore for the selected date
  Future<void> _addTask(String title, String time) async {
    if (_selectedDate != null) {
      String formattedDate = DateFormat('MM-dd-yyyy').format(_selectedDate!);

      await FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .collection('task')
          .doc(formattedDate)
          .set({
        'tasks': FieldValue.arrayUnion([{'title': title, 'time': time}])
      }, SetOptions(merge: true));  // Merge tasks for the selected date
    }
  }

  // Stream to get tasks for the selected date
  Stream<DocumentSnapshot> _getTasksForSelectedDate() {
    if (_selectedDate != null) {
      String formattedDate = DateFormat('MM-dd-yyyy').format(_selectedDate!);
      return FirebaseFirestore.instance
          .collection('accounts')
          .doc(userId)
          .collection('task')
          .doc(formattedDate)
          .snapshots();
    } else {
      // Return an empty stream if no date is selected
      return Stream.empty();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _previousWeek,
        ),
        title: Text(currentMonth),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.arrow_forward),
            onPressed: _nextWeek,
          ),
        ],
      ),
      body: Column(
        children: [
          // Calendar Row
          Container(
            color: Colors.green,
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(7, (index) {
                return GestureDetector(
                  onTap: () => _selectDate(weekDays[index]),
                  child: Column(
                    children: [
                      Text(
                        DateFormat.E().format(weekDays[index]).toUpperCase(),
                        style: TextStyle(color: Colors.white),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "${weekDays[index].day}",
                        style: TextStyle(
                          color: _selectedDate == weekDays[index]
                              ? Colors.yellow
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
          // Today's Task Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "TODAY'S TASK",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          // Task List
          Expanded(
            child: StreamBuilder<DocumentSnapshot>(
              stream: _getTasksForSelectedDate(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.data() == null) {
                  return Center(child: Text('No tasks available.'));
                }

                var tasks = snapshot.data!['tasks'] as List<dynamic>?;
                if (tasks == null || tasks.isEmpty) {
                  return Center(child: Text('No tasks available.'));
                }

                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    var task = tasks[index];
                    return TaskItem(title: task['title'], time: task['time']);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        child: Icon(Icons.add),
        onPressed: () {
          if (_selectedDate != null) {
            _showAddTaskDialog(context);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Please select a date first!'))
            );
          }
        },
      ),
    );
  }

  // Show a dialog to add a task
  void _showAddTaskDialog(BuildContext context) {
    String taskTitle = '';
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Add Task'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Task Title'),
                onChanged: (value) {
                  taskTitle = value;
                },
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    selectedTime != null
                        ? 'Time: ${selectedTime!.format(context)}'
                        : 'Select Time',
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.access_time),
                    onPressed: () async {
                      TimeOfDay? pickedTime = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (pickedTime != null) {
                        setState(() {
                          selectedTime = pickedTime;
                        });
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (taskTitle.isNotEmpty && selectedTime != null) {
                  String formattedTime = selectedTime!.format(context);
                  _addTask(taskTitle, formattedTime);
                  Navigator.of(context).pop();
                }
              },
              child: Text('Add Task'),
            ),
          ],
        );
      },
    );
  }
}

class TaskItem extends StatelessWidget {
  final String title;
  final String time;

  TaskItem({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Icon(Icons.radio_button_unchecked, color: Colors.white),
          title: Text(
            title,
            style: TextStyle(color: Colors.white),
          ),
          trailing: Text(
            time,
            style: TextStyle(color: Colors.white),
          ),
        ),
      ),
    );
  }
}
