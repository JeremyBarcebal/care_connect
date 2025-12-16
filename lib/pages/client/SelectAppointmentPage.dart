import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- COLOR PALETTE DEFINITION ---
const Color kPrimaryColor = Color(0xFF48A6A7);
const Color kBookedSlotColor = Color(0xFFFDD8D8);
const Color kBookedBorderColor = Color(0xFFD93025);

class SelectAppointmentPage extends StatefulWidget {
  final String doctorId;
  const SelectAppointmentPage({required this.doctorId, super.key});

  @override
  State<SelectAppointmentPage> createState() => _SelectAppointmentPageState();
}

class _SelectAppointmentPageState extends State<SelectAppointmentPage> {
  /// The date currently selected by the user in the calendar view.
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());

  // --- MOCK DATA FOR FRONT-END DEVELOPMENT ---
  List<String> availableTimes = [];
  List<String> bookedTimes = [];
  String? selectedTime;
  // -------------------------------------------

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  void _loadInitialData() {
    // Load slots for today's date
    fetchAvailableTimes(DateTime.now());
  }

  Future<void> fetchAvailableTimes(DateTime date) async {
    // =========================================================================
    // 🔥 FIREBASE CONNECTION: Fetch Slots for Selected Date
    //    Query the database to get available and booked slots for the given
    //    date and widget.doctorId from schedules/{doctorId}/dates/{dateKey}
    // =========================================================================

    try {
      // Format the date key as "Day Mon DD YYYY" (e.g., "Mon Dec 15 2025")
      String dateKey = DateFormat('EEE MMM dd yyyy').format(date);

      print("📅 Fetching slots for doctor: ${widget.doctorId}, date: $dateKey");

      // Query Firebase: schedules/{doctorId}/dates/{dateKey}
      DocumentSnapshot dateDoc = await FirebaseFirestore.instance
          .collection('schedules')
          .doc(widget.doctorId)
          .collection('dates')
          .doc(dateKey)
          .get();

      List<String> fetchedAllTimes = [];
      List<String> fetchedBookedTimes = [];

      if (dateDoc.exists) {
        Map<String, dynamic> dateData = dateDoc.data() as Map<String, dynamic>;
        List<dynamic> slots = dateData['slots'] as List<dynamic>? ?? [];

        print("📋 Found ${slots.length} slots for this date");

        for (var slot in slots) {
          String time = slot['time'] as String? ?? '';
          String status = slot['status'] as String? ?? 'booked';

          if (time.isNotEmpty) {
            fetchedAllTimes.add(time);
            if (status == 'booked') {
              fetchedBookedTimes.add(time);
            }
          }
        }
      } else {
        print("⚠️ No schedule found for this date");
      }

      setState(() {
        selectedDate = date;
        availableTimes = fetchedAllTimes;
        bookedTimes = fetchedBookedTimes;
        selectedTime = null;
      });
    } catch (e) {
      print("❌ Error fetching available times: $e");
      setState(() {
        selectedDate = date;
        availableTimes = [];
        bookedTimes = [];
        selectedTime = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kPrimaryColor,
        title: const Text(
          "Select Appointment",
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w400,
          ),
        ),
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: Column(
        children: [
          // 1. Custom Calendar View (Date Selection)
          _CalendarView(
            initialDate: selectedDate,
            onDateSelected: (newDate) async {
              // Trigger fetching of time slots when a new date is selected
              await fetchAvailableTimes(newDate);
            },
          ),

          const SizedBox(height: 30),

          // 2. Time Section Header
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.access_time, size: 20),
                SizedBox(width: 8),
                Text("TIME",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
          ),

          // 3. Time Slots Grid (Scrollable)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: availableTimes.isEmpty &&
                      DateUtils.isSameDay(
                          selectedDate, DateUtils.dateOnly(selectedDate))
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 50.0),
                        child: Text("No slots available for this date."),
                      ),
                    )
                  : _TimeSlotGrid(
                      availableTimes: availableTimes,
                      bookedTimes: bookedTimes,
                      selectedTime: selectedTime,
                      onTimeSelected: (time) {
                        // Only allow selection if the slot is not already booked
                        if (!bookedTimes.contains(time)) {
                          setState(() {
                            selectedTime = time;
                          });
                        }
                      },
                    ),
            ),
          ),

          // 4. Appointment Request Disclaimer
          const Padding(
            padding: EdgeInsets.only(
                top: 24.0, left: 16.0, right: 16.0, bottom: 8.0),
            child: Text(
              "This sends a request to the doctor; the appointment is not yet automatically booked. Please wait for the doctor to confirm your request.",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.orange,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 5. Confirm Button (Always Visible)
          Container(
            padding: const EdgeInsets.all(16.0),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: selectedTime != null &&
                      !bookedTimes.contains(selectedTime)
                  ? () {
                      // --- LOGIC: Convert selected date and time string to a single DateTime object ---
                      final timeParts = selectedTime!.split(RegExp(r'[:\s]'));
                      final hour = int.parse(timeParts[0]);
                      final minute = int.parse(timeParts[1]);
                      final isPM = timeParts.length > 2 && timeParts[2] == 'PM';

                      int finalHour = hour;
                      if (isPM && hour != 12) {
                        finalHour = hour + 12;
                      } else if (!isPM && hour == 12) {
                        finalHour = 0;
                      }

                      final appointmentDateTime = DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                        finalHour,
                        minute,
                      );

                      // =========================================================================
                      // 🔥 FIREBASE CONNECTION POINT 3: Appointment Confirmation/Booking
                      //    Here, the combined `appointmentDateTime` should be sent to the database
                      //    along with the `widget.doctorId` and the current user's ID to submit the request.
                      // =========================================================================

                      // Create date key in the same format as stored in Firebase
                      String dateKey =
                          DateFormat('EEE MMM dd yyyy').format(selectedDate);

                      // Return map with all appointment details
                      Navigator.pop(context, {
                        'dateTime': appointmentDateTime,
                        'dateKey': dateKey,
                        'timeSlot': selectedTime,
                        'doctorId': widget.doctorId,
                      });
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                backgroundColor:
                    selectedTime != null && !bookedTimes.contains(selectedTime)
                        ? kPrimaryColor
                        : Colors.grey,
                foregroundColor: Colors.white,
              ),
              child: const Text("Confirm Appointment Schedule",
                  style: TextStyle(fontSize: 17)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarView extends StatefulWidget {
  final DateTime initialDate;
  final Function(DateTime) onDateSelected;

  const _CalendarView(
      {required this.initialDate, required this.onDateSelected});

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = DateUtils.dateOnly(widget.initialDate);
    _focusedMonth = DateUtils.dateOnly(
        DateTime(_selectedDate.year, _selectedDate.month, 1));
  }

  void _onMonthChanged(int direction) {
    final newMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + direction, 1);

    if (newMonth.isBefore(DateUtils.dateOnly(
        DateTime(DateTime.now().year, DateTime.now().month, 1)))) {
      return;
    }

    setState(() {
      _focusedMonth = newMonth;
    });
  }

  void _selectDate(DateTime date) {
    if (date.isBefore(DateUtils.dateOnly(DateTime.now()))) return;

    setState(() {
      _selectedDate = date;
    });
    widget.onDateSelected(date);
  }

  List<DateTime> _getDatesInMonth(DateTime month) {
    final days = <DateTime>[];
    final firstDayOfMonth = DateTime(month.year, month.month, 1);

    final startOffset = firstDayOfMonth.weekday % 7;
    final startDay = firstDayOfMonth.subtract(Duration(days: startOffset));

    final lastDayOfMonth = DateTime(month.year, month.month + 1, 0);
    final totalDays = lastDayOfMonth.difference(startDay).inDays + 1;
    final numWeeks = (totalDays / 7).ceil();
    final totalCells = numWeeks * 7;

    for (int i = 0; i < totalCells; i++) {
      days.add(startDay.add(Duration(days: i)));
    }
    return days;
  }

  Widget _buildDateCell(DateTime date) {
    final isSelected = DateUtils.isSameDay(date, _selectedDate);
    final isInCurrentMonth = date.month == _focusedMonth.month;
    final isPast = date.isBefore(DateUtils.dateOnly(DateTime.now()));

    final isSelectable = isInCurrentMonth && !isPast;

    return GestureDetector(
      onTap: isSelectable ? () => _selectDate(date) : null,
      child: Container(
        alignment: Alignment.center,
        margin: const EdgeInsets.all(4),
        child: isSelected
            ? Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kPrimaryColor,
                    boxShadow: [
                      BoxShadow(
                        color: kPrimaryColor.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(color: Colors.white, width: 1.5)),
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              )
            : Text(
                '${date.day}',
                style: TextStyle(
                  color: isPast || !isInCurrentMonth
                      ? Colors.grey.shade400
                      : Colors.black,
                  fontWeight: FontWeight.w500,
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dates = _getDatesInMonth(_focusedMonth);
    const dayNames = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Month/Year Header with Navigation
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _onMonthChanged(-1),
                color: _focusedMonth.month == DateTime.now().month &&
                        _focusedMonth.year == DateTime.now().year
                    ? Colors.grey.shade300
                    : Colors.black,
              ),
              Column(
                children: [
                  const Text("DATE",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(
                    DateFormat('MMMM yyyy').format(_focusedMonth),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _onMonthChanged(1),
              ),
            ],
          ),
          const SizedBox(height: 15),

          // Day Names Grid
          Container(
            padding: const EdgeInsets.only(bottom: 10),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 1.0,
              ),
              itemCount: 7,
              itemBuilder: (context, index) {
                return Center(
                  child: Text(
                    dayNames[index],
                    style: TextStyle(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),
          ),

          // Date Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
            ),
            itemCount: dates.length,
            itemBuilder: (context, index) {
              return _buildDateCell(dates[index]);
            },
          ),
        ],
      ),
    );
  }
}

class _TimeSlotGrid extends StatelessWidget {
  final List<String> availableTimes;
  final List<String> bookedTimes;
  final String? selectedTime;
  final Function(String) onTimeSelected;

  const _TimeSlotGrid({
    required this.availableTimes,
    required this.bookedTimes,
    required this.selectedTime,
    required this.onTimeSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (availableTimes.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    const padding = 16.0 * 2;
    const spacing = 10.0 * 2;
    final itemWidth = (screenWidth - padding - spacing) / 3;

    return Wrap(
      spacing: 10.0,
      runSpacing: 10.0,
      alignment: WrapAlignment.start,
      children: availableTimes.map((time) {
        final isSelected = selectedTime == time;
        final isBooked = bookedTimes.contains(time);

        Color backgroundColor;
        Color borderColor;
        Color textColor;

        if (isBooked) {
          // Booked state
          backgroundColor = kBookedSlotColor;
          borderColor = kBookedBorderColor.withOpacity(0.5);
          textColor = kBookedBorderColor;
        } else if (isSelected) {
          // Selected state
          backgroundColor = kPrimaryColor;
          borderColor = kPrimaryColor;
          textColor = Colors.white;
        } else {
          // Available state
          backgroundColor = Colors.white;
          borderColor = Colors.grey.shade300;
          textColor = Colors.black87;
        }

        return GestureDetector(
          // Only allow tapping if the slot is NOT booked
          onTap: isBooked ? null : () => onTimeSelected(time),
          child: Container(
            width: itemWidth,
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(5.0),
              border: Border.all(
                color: borderColor,
                width: 1.0,
              ),
            ),
            child: Text(
              time,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
