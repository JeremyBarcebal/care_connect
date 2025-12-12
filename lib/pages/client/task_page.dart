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
      // Normalize the date to remove time component
      _selectedDate = DateTime(date.year, date.month, date.day);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Teal header with calendar
          Container(
            color: Color(0xFF48A6A7),
            height: 221,
            padding: EdgeInsets.symmetric(vertical: 50, horizontal: 16),
            child: Column(
              children: [
                // Month navigation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: _previousWeek,
                    ),
                    Text(
                      currentMonth,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_forward, color: Colors.white),
                      onPressed: _nextWeek,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                // Calendar Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final dayDate = weekDays[index];
                    final normalizedDay =
                        DateTime(dayDate.year, dayDate.month, dayDate.day);
                    final isSelected = _selectedDate != null &&
                        DateTime(_selectedDate!.year, _selectedDate!.month,
                                _selectedDate!.day) ==
                            normalizedDay;

                    return GestureDetector(
                      onTap: () => _selectDate(dayDate),
                      child: Column(
                        children: [
                          Text(
                            DateFormat.E().format(dayDate).toUpperCase(),
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                          SizedBox(height: 8),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.transparent,
                            ),
                            child: Center(
                              child: Text(
                                "${dayDate.day}",
                                style: TextStyle(
                                  color: isSelected
                                      ? Color(0xFF4DBFB8)
                                      : Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
          // White card with tasks
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40),
                  topRight: Radius.circular(40),
                ),
              ),
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

                  final data = snapshot.data!.data() as Map<String, dynamic>?;
                  var tasks = (data?['tasks'] as List<dynamic>?) ?? [];
                  if (tasks.isEmpty) {
                    return Center(child: Text('No tasks available.'));
                  }

                  String formattedDate =
                      DateFormat('MM-dd-yyyy').format(_selectedDate!);

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // TODAY'S TASK Header
                        Center(
                          child: Text(
                            "TODAY'S TASK",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF006A71),
                              ),
                            ),  
                       ),
                        SizedBox(height: 12),
                        // Task List
                        ListView.separated(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: tasks.length,
                          separatorBuilder: (context, index) =>
                              SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            var task = tasks[index];
                            final String taskId = task['taskId'] ?? '';
                            final String status = task['status'] ?? 'pending';
                            final String doctorName =
                                task['doctorName'] ?? 'Doctor';
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
                              doctorName: doctorName,
                              onMarkComplete: taskId.isNotEmpty
                                  ? () async {
                                      await _taskService.markTaskComplete(
                                          userId, formattedDate, taskId);
                                    }
                                  : null,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
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
  final String? doctorName;
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
    this.doctorName,
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
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
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
                ? Color(0xFF9ACBD0).withOpacity(0.5)
                : Color.fromARGB(255, 230, 248, 250).withOpacity(0.5) ,
            borderRadius: BorderRadius.circular(15),
            border: widget.status == 'completed'
                ? Border.all(color: Color(0xFF006A71), width: 1)
                : Border.all(color: Color(0xFF9ACBD0), width: 1),
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
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header row with title and button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: TextStyle(
                                  color: widget.status == 'completed'
                                      ? Color(0xFF4DBFB8)
                                      : Color(0xFF006A71),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  decoration: widget.status == 'completed'
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (widget.status != 'completed')
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFF48A6A7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Accepted',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Color(0xFF006A71),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'Completed',
                              style: TextStyle(
                                color: Color.fromARGB(255, 255, 255, 255),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Doctor/Patient info row
                    Row(
                      children: [
                        Icon(Icons.person, color: Color(0xFF006A71), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '${widget.doctorName ?? 'Doctor'} (Doctor)',
                          style: TextStyle(
                            color: Color(0xFF006A71),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Medicine details in compact format
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color:
                            Color.fromARGB(255, 10, 141, 156).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.medicineType.isNotEmpty)
                            Text(
                              'Medicine: ${widget.medicineType}',
                              style: const TextStyle(
                                color: Color.fromARGB(255, 11, 74, 74),
                                fontSize: 10,
                              ),
                            ),
                          if (widget.dosage.isNotEmpty)
                            Text(
                              'Dosage: ${_formatDosage(widget.dosage, widget.medicineType)}',
                              style: const TextStyle(
                                color: Color.fromARGB(255, 11, 74, 74),
                                fontSize: 10,
                              ),
                            ),
                          if (widget.frequency.isNotEmpty)
                            Text(
                              'Frequency: ${widget.frequency}',
                              style: const TextStyle(
                                color: Color.fromARGB(255, 11, 74, 74),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Time row
                    Row(
                      children: [
                        const Icon(Icons.access_time,
                            color: Color.fromARGB(255, 7, 48, 51), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          'Time: ${widget.time}',
                          style: const TextStyle(
                            color: Color.fromARGB(255, 7, 48, 51),
                            fontSize: 11,
                          ),
                        ),
                      ],
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
                        ? Color(0xFF4DBFB8).withOpacity(0.5)
                        : Color(0xFF2D9B9B),
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
                              foregroundColor: Color.fromARGB(255, 4, 43, 40),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
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
