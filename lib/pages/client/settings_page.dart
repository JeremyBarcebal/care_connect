import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;

class SettingsPage extends StatefulWidget {
  @override
  _SettingsPageState createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  // Editing state
  Map<String, bool> _editingState = {};
  bool _isUploadingPhoto = false;

  // Controllers for all fields
  final Map<String, TextEditingController> _controllers = {
    'name': TextEditingController(),
    'email': TextEditingController(),
    'mobileNo': TextEditingController(),
    'dob': TextEditingController(),
    'gender': TextEditingController(),
    'street': TextEditingController(),
    'city': TextEditingController(),
    'state': TextEditingController(),
    'zipCode': TextEditingController(),
    'insuranceProvider': TextEditingController(),
    'policyNumber': TextEditingController(),
    'emergencyContact': TextEditingController(),
    'governmentId': TextEditingController(),
  };

  String? _profilePhotoUrl;
  File? _selectedImage;
  bool _isPickingImage = false; // Flag to prevent multiple picker calls

  @override
  void initState() {
    super.initState();
    // Initialize all editing states to false
    for (var key in _controllers.keys) {
      _editingState[key] = false;
    }
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      _profilePhotoUrl = user.photoURL;

      // Load all data from Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('accounts').doc(user.uid).get();
      if (userDoc.exists) {
        setState(() {
          _controllers['name']!.text = userDoc['name'] ?? '';
          _controllers['email']!.text = userDoc['email'] ?? user.email ?? '';
          _controllers['mobileNo']!.text = userDoc['mobileNo'] ?? '';
          _controllers['dob']!.text = userDoc['dob'] ?? '';
          _controllers['gender']!.text = userDoc['gender'] ?? '';
          _controllers['street']!.text = userDoc['street'] ?? '';
          _controllers['city']!.text = userDoc['city'] ?? '';
          _controllers['state']!.text = userDoc['state'] ?? '';
          _controllers['zipCode']!.text = userDoc['zipCode'] ?? '';
          _controllers['insuranceProvider']!.text =
              userDoc['insuranceProvider'] ?? '';
          _controllers['policyNumber']!.text = userDoc['policyNumber'] ?? '';
          _controllers['emergencyContact']!.text =
              userDoc['emergencyContact'] ?? '';
          _controllers['governmentId']!.text = userDoc['governmentId'] ?? '';
          // Safe access to photo - use .get() method with null coalescing
          _profilePhotoUrl =
              (userDoc.data() as Map?)?.containsKey('photo') == true
                  ? userDoc['photo']
                  : user.photoURL;
        });

        // If photo field doesn't exist, add it to the document
        if ((userDoc.data() as Map?)?.containsKey('photo') != true) {
          await _firestore.collection('accounts').doc(user.uid).update({
            'photo': user.photoURL ?? '',
          }).catchError((e) {
            print('Error adding photo field: $e');
          });
        }
      }
    }
  }

  Future<void> _pickImage() async {
    // Prevent multiple simultaneous image picker calls
    if (_isPickingImage) {
      return;
    }

    _isPickingImage = true;

    try {
      final XFile? pickedFile =
          await _imagePicker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
        await _uploadProfilePhoto();
      }
    } catch (e) {
      print('Error picking image: $e');

      // Only show error if it's not the "already_active" error (user cancelled)
      if (!e.toString().contains('already_active')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error picking image: $e')),
              ],
            ),
            backgroundColor: Colors.red[500],
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } finally {
      _isPickingImage = false; // Reset flag when done
    }
  }

  Future<void> _uploadProfilePhoto() async {
    if (_selectedImage == null) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Get file from the selected image
        final file = _selectedImage!;

        // Verify file exists and is readable
        if (!file.existsSync()) {
          throw Exception('Selected image file no longer exists');
        }

        print('Reading and compressing image...');
        print('Original file size: ${file.lengthSync()} bytes');

        // Read the image file
        final bytes = await file.readAsBytes();

        // Decode the image
        img.Image? originalImage = img.decodeImage(bytes);

        if (originalImage == null) {
          throw Exception('Failed to decode image');
        }

        // Resize image to reduce size (max 400x400 pixels)
        img.Image resizedImage = img.copyResize(
          originalImage,
          width: 400,
          height: 400,
          interpolation: img.Interpolation.average,
        );

        // Encode to JPEG with quality 80 to compress
        final compressedBytes = img.encodeJpg(resizedImage, quality: 80);

        print('Compressed file size: ${compressedBytes.length} bytes');

        // Convert to Base64
        final base64String = base64Encode(compressedBytes);
        final dataUrl = 'data:image/jpeg;base64,$base64String';

        print('Data URL length: ${dataUrl.length}');

        // Update in Firestore (store Base64 directly)
        await _firestore.collection('accounts').doc(user.uid).update({
          'photo': dataUrl,
        });

        await user.reload();

        setState(() {
          _profilePhotoUrl = dataUrl;
          _selectedImage = null;
          _isUploadingPhoto = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Profile photo updated successfully!')),
              ],
            ),
            backgroundColor: const Color(0xFF4DBFB8),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print('Error uploading photo: $e');
      setState(() {
        _isUploadingPhoto = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error uploading photo: $e')),
            ],
          ),
          backgroundColor: Color(0xFF4DBFB8),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _logout(BuildContext context) async {
    await _auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  Future<void> _saveUserInfo() async {
    try {
      User? user = _auth.currentUser;
      if (user != null) {
        // Update all fields in Firestore
        Map<String, dynamic> updateData = {};
        _controllers.forEach((key, controller) {
          updateData[key] = controller.text;
        });

        await _firestore
            .collection('accounts')
            .doc(user.uid)
            .update(updateData);

        // Update display name in auth if changed
        if (_controllers['name']!.text.isNotEmpty) {
          await user.updateDisplayName(_controllers['name']!.text);
          await user.reload();
        }

        setState(() {
          _editingState.forEach((key, _) {
            _editingState[key] = false;
          });
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Information updated successfully!')),
              ],
            ),
            backgroundColor: Colors.green[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      print('Error saving user info: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('Error updating information: $e')),
            ],
          ),
          backgroundColor: const Color.fromARGB(255, 152, 4, 4),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  void _cancelEdit() {
    setState(() {
      _editingState.forEach((key, _) {
        _editingState[key] = false;
      });
    });
    _loadUserData();
  }

  @override
  Widget build(BuildContext context) {
    User? user = _auth.currentUser;
    bool isEditingAny = _editingState.values.any((value) => value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF48A6A7),
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Profile Photo Section
              Stack(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[300],
                      border: Border.all(
                        color: const Color(0XFF006A71),
                        width: 3,
                      ),
                    ),
                    child: _profilePhotoUrl != null
                        ? ClipOval(
                            child: _buildProfileImage(_profilePhotoUrl!),
                          )
                        : Center(
                            child: Icon(
                              Icons.person,
                              size: 60,
                              color: Colors.grey[600],
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF006A71),
                      ),
                      child: _isUploadingPhoto
                          ? Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: SizedBox(
                                width: 30,
                                height: 30,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              onPressed: _isPickingImage ? null : _pickImage,
                              icon: const Icon(Icons.camera_alt,
                                  color: Colors.white, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              // User Information Section
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFF9ACBD0).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Personal Information Section
                    _buildSectionHeader('Personal Information' ),
                    _buildEditableField(
                        'name', 'Full Name', Icons.person, TextInputType.text),
                    const SizedBox(height: 12),
                    _buildEditableField('email', 'Email', Icons.email,
                        TextInputType.emailAddress),
                    const SizedBox(height: 12),
                    _buildEditableField('mobileNo', 'Mobile Number',
                        Icons.phone, TextInputType.phone),
                    const SizedBox(height: 12),
                    _buildEditableField('dob', 'Date of Birth',
                        Icons.calendar_today, TextInputType.text),
                    const SizedBox(height: 12),
                    _buildEditableField(
                        'gender', 'Gender', Icons.wc, TextInputType.text),
                    const SizedBox(height: 20),

                    // Address Section
                    _buildSectionHeader('Address'),
                    _buildEditableField('street', 'Street', Icons.location_on,
                        TextInputType.text),
                    const SizedBox(height: 12),
                    _buildEditableField('city', 'City', Icons.location_city,
                        TextInputType.text),
                    const SizedBox(height: 12),
                    _buildEditableField(
                        'state', 'State', Icons.map, TextInputType.text),
                    const SizedBox(height: 12),
                    _buildEditableField(
                        'zipCode', 'Zip Code', Icons.mail, TextInputType.text),
                    const SizedBox(height: 20),

                    // Insurance Information Section
                    _buildSectionHeader('Insurance Information'),
                    _buildEditableField(
                        'insuranceProvider',
                        'Insurance Provider',
                        Icons.security,
                        TextInputType.text),
                    const SizedBox(height: 12),
                    _buildEditableField('policyNumber', 'Policy Number',
                        Icons.receipt, TextInputType.text),
                    const SizedBox(height: 20),

                    // Emergency Information Section
                    _buildSectionHeader('Emergency Information'),
                    _buildEditableField('emergencyContact', 'Emergency Contact',
                        Icons.warning, TextInputType.phone),
                    const SizedBox(height: 12),
                    _buildEditableField('governmentId', 'Government ID',
                        Icons.badge, TextInputType.text),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Edit/Save/Cancel Buttons
              if (isEditingAny)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                        onPressed: _cancelEdit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 255, 253, 253),
                        ),
                        child: const Text(
                          'Cancel',
                          style: TextStyle(color: Color(0xFF006A71)),
                        )),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _saveUserInfo,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4DBFB8),
                      ),
                      child: const Text('Save',
                          style: TextStyle(
                              color: Color.fromARGB(255, 255, 255, 255))),
                    ),
                  ],
                ),
              const SizedBox(height: 30),

              // Logout Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _logout(context),
                  icon: const Icon(Icons.logout),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF006A71),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF006A71),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(
      String key, String label, IconData icon, TextInputType keyboardType) {
    bool isEditing = _editingState[key] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isEditing)
          ListTile(
            leading: Icon(icon, color: const Color(0xFF4DBFB8)),
            title: Text(
              label,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              _controllers[key]!.text.isEmpty
                  ? 'Not provided'
                  : _controllers[key]!.text,
              style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            trailing: Icon(Icons.edit, color: Colors.grey[400]),
            onTap: () {
              setState(() {
                _editingState[key] = true;
              });
            },
            contentPadding: EdgeInsets.zero,
          )
        else
          TextFormField(
            controller: _controllers[key],
            keyboardType: keyboardType,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: Icon(icon),
            ),
          ),
      ],
    );
  }

  Widget _buildProfileImage(String photoUrl) {
    // Check if URL is valid and not a blob URL
    if (photoUrl.isEmpty || photoUrl.startsWith('blob:')) {
      return Center(
        child: Icon(
          Icons.person,
          size: 60,
          color: Colors.grey[600],
        ),
      );
    }

    // Check if it's a data URL (Base64 encoded image)
    if (photoUrl.startsWith('data:image')) {
      try {
        // Extract Base64 string from data URL
        final parts = photoUrl.split(',');
        if (parts.length > 1) {
          final base64String = parts[1];
          final decodedBytes = base64Decode(base64String);
          return Image.memory(
            decodedBytes,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              print('Error loading base64 image: $error');
              return Center(
                child: Icon(
                  Icons.person,
                  size: 60,
                  color: Colors.grey[600],
                ),
              );
            },
          );
        }
      } catch (e) {
        print('Error decoding Base64 image: $e');
        return Center(
          child: Icon(
            Icons.person,
            size: 60,
            color: Colors.grey[600],
          ),
        );
      }
    }

    // If not a data URL, try to load as network image
    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        print('Error loading network image: $error');
        return Center(
          child: Icon(
            Icons.person,
            size: 60,
            color: Colors.grey[600],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _controllers.forEach((key, controller) {
      controller.dispose();
    });
    super.dispose();
  }
}
