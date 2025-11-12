import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore package
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth package
import 'package:care_connect/pages/doctor/task_service.dart';

class TaskPage extends StatefulWidget {
  @override
  _TaskPageState createState() => _TaskPageState();
}

class _TaskPageState extends State<TaskPage> {
  DateTime _currentWeekStart =
      DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1));
  DateTime? _selectedDate = DateTime.now(); // Default selected date to today

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
        'tasks': FieldValue.arrayUnion([
          {'title': title, 'time': time}
        ])
      }, SetOptions(merge: true)); // Merge tasks for the selected date
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

  late TaskService _taskService;

  @override
  void initState() {
    super.initState();
    _taskService = TaskService();
  }

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

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!.data() == null) {
                  return Center(child: Text('No tasks available.'));
                }

                var tasks = snapshot.data!['tasks'] as List<dynamic>?;
                if (tasks == null || tasks.isEmpty) {
                  return Center(child: Text('No tasks available.'));
                }

                String formattedDate =
                    DateFormat('MM-dd-yyyy').format(_selectedDate!);

                return ListView.builder(
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    var task = tasks[index];
                    final String taskId = task['taskId'] ?? '';
                    final String status = task['status'] ?? 'pending';
                    return TaskItem(
                      title: task['title'],
                      time: task['time'],
                      medicineType: task['type'] ?? '',
                      dosage: task['dosage'] ?? '',
                      frequency: task['frequency'] ?? '',
                      duration: task['duration'] ?? '',
                      remarks: task['remarks'] ?? '',
                      taskId: taskId,
                      status: status,
                      onMarkComplete: taskId.isNotEmpty
                          ? () async {
                              await _taskService.markTaskComplete(
                                  userId, formattedDate, taskId);
                            }
                          : null,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class TaskItem extends StatefulWidget {
  final String title;
  final String time;
  final String medicineType;
  final String dosage;
  final String frequency;
  final String duration;
  final String remarks;
  final String? taskId;
  final String status;
  final Future<void> Function()? onMarkComplete;

  TaskItem({
    required this.title,
    required this.time,
    required this.medicineType,
    required this.dosage,
    required this.frequency,
    required this.duration,
    required this.remarks,
    this.taskId,
    this.status = 'pending',
    this.onMarkComplete,
  });

  @override
  _TaskItemState createState() => _TaskItemState();
}

class _TaskItemState extends State<TaskItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isExpanded = !_isExpanded;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: widget.status == 'completed'
                ? Colors.green.shade300
                : Colors.green,
            borderRadius: BorderRadius.circular(12),
            border: widget.status == 'completed'
                ? Border.all(color: Colors.green.shade700, width: 2)
                : null,
            boxShadow: _isExpanded
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Main Task Item (Always visible)
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                leading: widget.status == 'completed'
                    ? Icon(Icons.check_circle, color: Colors.green.shade700)
                    : Icon(Icons.local_pharmacy, color: Colors.white),
                title: Text(
                  widget.title,
                  style: TextStyle(
                    color: widget.status == 'completed'
                        ? Colors.green.shade700
                        : Colors.white,
                    decoration: widget.status == 'completed'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.time,
                      style: TextStyle(
                        color: widget.status == 'completed'
                            ? Colors.green.shade700
                            : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: widget.status == 'completed'
                          ? Colors.green.shade700
                          : Colors.white,
                    ),
                  ],
                ),
              ),

              // Expanded Details Section
              if (_isExpanded)
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: widget.status == 'completed'
                        ? Colors.green.shade500
                        : Colors.green.shade700,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type
                      if (widget.medicineType.isNotEmpty)
                        _buildDetailRow(
                          label: 'Type',
                          value: widget.medicineType,
                        ),
                      if (widget.medicineType.isNotEmpty)
                        const SizedBox(height: 12),

                      // Dosage
                      if (widget.dosage.isNotEmpty)
                        _buildDetailRow(
                          label: 'Dosage',
                          value:
                              _formatDosage(widget.dosage, widget.medicineType),
                        ),
                      if (widget.dosage.isNotEmpty) const SizedBox(height: 12),

                      // Frequency
                      if (widget.frequency.isNotEmpty)
                        _buildDetailRow(
                          label: 'Frequency',
                          value: widget.frequency,
                        ),
                      if (widget.frequency.isNotEmpty)
                        const SizedBox(height: 12),

                      // Duration
                      if (widget.duration.isNotEmpty)
                        _buildDetailRow(
                          label: 'Duration',
                          value: _formatDuration(widget.duration),
                        ),
                      if (widget.duration.isNotEmpty)
                        const SizedBox(height: 12),

                      // Remarks
                      if (widget.remarks.isNotEmpty)
                        _buildDetailRow(
                          label: 'Remarks',
                          value: widget.remarks,
                        ),

                      // Mark as Complete Button (only show if not already completed)
                      if (widget.status != 'completed')
                        const SizedBox(height: 16),
                      if (widget.status != 'completed')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              if (widget.onMarkComplete != null) {
                                try {
                                  await widget.onMarkComplete!();
                                  // Success snackbar handled by parent, but keep a fallback
                                  // in case parent didn't show one.
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Task marked as complete!'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                  setState(() {});
                                } catch (e) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          'Failed to mark task complete: $e'),
                                      duration: Duration(seconds: 3),
                                    ),
                                  );
                                }
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Task marked as complete!'),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Mark as Complete'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      if (widget.status == 'completed')
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle,
                                  color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Text(
                                'Completed',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({required String label, required String value}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(String duration) {
    final s = duration.trim();
    if (s.isEmpty) return '';
    // If it already contains letters (e.g., 'days', 'week', 'month', 'Ongoing'), return as-is
    if (RegExp(r'[A-Za-z]').hasMatch(s)) return s;
    final match = RegExp(r'(\d+)').firstMatch(s);
    if (match != null) {
      final n = match.group(1);
      if (n == '0') return 'As needed';
      if (n == '1') return '1 day';
      return '$n days';
    }
    return s;
  }

  String _formatDosage(String dosage, String type) {
    final d = dosage.trim();
    if (d.isEmpty) return '';
    // If dosage already includes letters or units, return as-is
    if (RegExp(r'[A-Za-z]').hasMatch(d)) return d;
    final t = type.toLowerCase();
    // Numeric-only dosage, infer unit from type when reasonable
    if (t.contains('tablet')) return '$d Tablet${d != '1' ? 's' : ''}';
    if (t.contains('capsule')) return '$d Capsule${d != '1' ? 's' : ''}';
    if (t.contains('syrup')) return '$d ml';
    if (t.contains('injection')) return '$d ml';
    if (t.contains('drops')) return '$d drops';
    if (t.contains('cream') || t.contains('ointment')) return '$d g';
    if (t.contains('inhaler')) return '$d puffs';
    if (t.contains('patch')) return '$d Patch${d != '1' ? 'es' : ''}';
    // Fallback: append the type
    return '$d ${type}';
  }
}
