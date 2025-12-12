import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart' as intl;

class PatientNoteDetailPage extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final dynamic noteData;

  const PatientNoteDetailPage(this.userData, {super.key, this.noteData});

  @override
  State<PatientNoteDetailPage> createState() => _PatientNoteDetailPageState();
}

class _PatientNoteDetailPageState extends State<PatientNoteDetailPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
  }

  String _getFormattedDateTime(dynamic timestamp) {
    if (timestamp is Timestamp) {
      DateTime dateTime = timestamp.toDate();
      return intl.DateFormat('MMM dd, yyyy - hh:mm a').format(dateTime);
    }
    return 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    // Safely get approved status
    bool? approvedStatus;
    String statusText = 'Pending';
    IconData statusIcon = Icons.schedule;
    String doctorName = 'Unassigned Doctor';

    try {
      final data = widget.noteData.data() as Map<String, dynamic>?;
      if (data != null) {
        // Safe access to approved field
        if (data.containsKey('approved')) {
          approvedStatus = data['approved'] as bool?;
          if (approvedStatus == true) {
            statusText = 'Approved';
            statusIcon = Icons.check_circle;
          } else if (approvedStatus == false) {
            statusText = 'Declined';
            statusIcon = Icons.cancel;
          }
        }
        // Safe access to doctorName field
        if (data.containsKey('doctorName')) {
          doctorName = data['doctorName'] ?? 'Unassigned Doctor';
        }
      }
    } catch (e) {
      // If there's any error, use default pending status
      statusText = 'Pending';
      statusIcon = Icons.schedule;
      doctorName = 'Unassigned Doctor';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consultation Request Details', style: TextStyle(
        color: Colors.white,
        fontSize: 20, // ← Change font color here
        fontWeight: FontWeight.w400),
        ),
        backgroundColor: const Color(0xFF48A6A7),
      ),
      body: widget.noteData != null
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header section with status and assigned doctor
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:Color(0xFF4DBFB8),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Status: $statusText',
                              style: const TextStyle(
                                color: Color.fromARGB(255, 254, 255, 255),
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              statusIcon,
                              color: Colors.white,
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Assigned to: $doctorName',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Submitted: ${_getFormattedDateTime(widget.noteData['timestamp'])}',
                          style: const TextStyle(
                            color: Color.fromARGB(179, 3, 45, 39),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Patient Information Section
                  const Text(
                    'Your Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006A71),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailCard(
                    'Patient Name',
                    widget.noteData['clientName'] ?? 'N/A',
                  ),
                  _buildDetailCard(
                    'Email',
                    widget.noteData['clientEmail'] ?? 'N/A',
                  ),
                  const SizedBox(height: 24),

                  // Consultation Details Section
                  const Text(
                    'Consultation Details',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006A71),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailCard(
                    'What do you feel?',
                    widget.noteData['patientFeels'] ?? 'N/A',
                  ),
                  _buildDetailCard(
                    'Pain Location',
                    widget.noteData['painLocation'] ?? 'N/A',
                  ),
                  _buildDetailCard(
                    'Pain Intensity',
                    widget.noteData['painIntensity'] ?? 'N/A',
                  ),
                  _buildDetailCard(
                    'Onset of Symptoms',
                    widget.noteData['onsetSymptoms'] ?? 'N/A',
                  ),
                  const SizedBox(height: 24),

                  // Medical Information Section
                  const Text(
                    'Medical Information',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF006A71),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailCard(
                    'Body Temperature',
                    widget.noteData['bodyTemperature'] ?? 'N/A',
                  ),
                  _buildDetailCard(
                    'Current Medication',
                    widget.noteData['currentMedication'] ?? 'None',
                  ),
                  const SizedBox(height: 24),

                  // Doctor's Response Section
                  if (widget.noteData['medicationPrescribe'] != null &&
                      widget.noteData['medicationPrescribe']!.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Doctor's Prescription",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF006A71),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          'Medication Prescribed',
                          widget.noteData['medicationPrescribe'] ?? 'N/A',
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  if (approvedStatus == null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.close),
                          label: const Text('Go Back'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color.fromARGB(255, 121, 121, 121),
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            )
          : const Center(
              child: Text('No note data available'),
            ),
    );
  }

  Widget _buildDetailCard(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF006A71).withOpacity(0.2), width: 0.5),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
