import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/meeting_utils.dart';
import '../utils/web_device_identifier.dart';

class GuestEntryWidget extends StatefulWidget {
  final String meetingId;
  
  const GuestEntryWidget({
    super.key,
    required this.meetingId,
  });

  @override
  State<GuestEntryWidget> createState() => _GuestEntryWidgetState();
}

class _GuestEntryWidgetState extends State<GuestEntryWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentsController = TextEditingController();
  
  bool _isSaving = false;
  String? _errorMessage;
  String? _deviceId;
  bool _hasCheckedDevice = false;
  bool _hasExistingEntry = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getDeviceId();
    await _checkExistingEntry();
  }

  Future<void> _getDeviceId() async {
    try {
      _deviceId = await WebDeviceIdentifier.getDeviceId();
      setState(() {
        _hasCheckedDevice = true;
      });
    } catch (e) {
      print('Error getting device ID: $e');
      // Fallback device ID
      _deviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
      setState(() {
        _hasCheckedDevice = true;
      });
    }
  }

  Future<void> _checkExistingEntry() async {
    if (_deviceId == null) return;

    try {
      final creatorId = await MeetingUtils.getCreatorId(widget.meetingId);
      if (creatorId == null) return;

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .collection('guests')
          .where('device_id', isEqualTo: _deviceId)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _hasExistingEntry = querySnapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking existing entry: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _saveGuestInfo() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_hasExistingEntry) {
      setState(() {
        _errorMessage = 'You have already submitted your information for this meeting.';
      });
      return;
    }

    if (_deviceId == null) {
      setState(() {
        _errorMessage = 'Device ID not available. Please try again.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      // Get the meeting creator ID
      final creatorId = await MeetingUtils.getCreatorId(widget.meetingId);
      
      if (creatorId == null) {
        setState(() {
          _errorMessage = 'Could not find meeting information. Please try again.';
          _isSaving = false;
        });
        return;
      }

      // Double-check for existing entry before saving
      final existingCheck = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .collection('guests')
          .where('device_id', isEqualTo: _deviceId)
          .limit(1)
          .get();

      if (existingCheck.docs.isNotEmpty) {
        setState(() {
          _errorMessage = 'You have already submitted your information for this meeting.';
          _isSaving = false;
          _hasExistingEntry = true;
        });
        return;
      }

      // Prepare guest data
      final guestData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'device_id': _deviceId,
        'created_at': FieldValue.serverTimestamp(),
      };

      // Add phone only if provided
      final phone = _phoneController.text.trim();
      if (phone.isNotEmpty) {
        guestData['phone'] = phone;
      }

      // Add comments only if provided
      final comments = _commentsController.text.trim();
      if (comments.isNotEmpty) {
        guestData['comments'] = comments;
      }

      // Save to Firestore: users/{creatorId}/guests/{autoId}
      await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .collection('guests')
          .add(guestData);

      setState(() {
        _isSaving = false;
        _hasExistingEntry = true;
      });

      // Clear form
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _commentsController.clear();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your information has been saved.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 1),
          ),
        );
        
        // Close the widget after 1 second
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.of(context).pop();
          }
        });
      }
    } catch (e) {
      print('Error saving guest info: $e');
      setState(() {
        _errorMessage = 'Failed to save information. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(
              child: Align(
                alignment: const Alignment(0, -0.15),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.all(32),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Title
                          Text(
                            'New to the Club?',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Please enter your information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 32),
                          
                          // Name Field
                          SizedBox(
                            width: 320,
                            child: TextFormField(
                              controller: _nameController,
                              decoration: InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: const Icon(Icons.person_outline),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF2F1F0),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Email Field
                          SizedBox(
                            width: 320,
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: const Icon(Icons.email_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF2F1F0),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter your email';
                                }
                                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                  return 'Please enter a valid email';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Phone Field (Optional)
                          SizedBox(
                            width: 320,
                            child: TextFormField(
                              controller: _phoneController,
                              keyboardType: TextInputType.phone,
                              decoration: InputDecoration(
                                labelText: 'Phone (Optional)',
                                prefixIcon: const Icon(Icons.phone_outlined),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF2F1F0),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Comments Field (Optional)
                          SizedBox(
                            width: 320,
                            child: TextFormField(
                              controller: _commentsController,
                              maxLines: 4,
                              decoration: InputDecoration(
                                labelText: 'Comments (Optional)',
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(bottom: 60),
                                  child: Icon(Icons.comment_outlined),
                                ),
                                alignLabelWithHint: true,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                filled: true,
                                fillColor: const Color(0xFFF2F1F0),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isSaving && !_hasExistingEntry) {
                                  _saveGuestInfo();
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Error Message
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: SizedBox(
                                width: 320,
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    color: Colors.red,
                                    fontSize: 14,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          
                          // Already Submitted Message
                          if (_hasExistingEntry && _errorMessage == null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Container(
                                width: 320,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.green[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle_outline, 
                                      color: Colors.green[700], 
                                      size: 20,
                                    ),
                                    Expanded(
                                      child: Text(
                                        'Your information has been submitted.',
                                        style: TextStyle(
                                          color: Colors.green[700],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          // Buttons Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Close Button
                              SizedBox(
                                width: 140,
                                height: 48,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF424242),
                                    side: const BorderSide(
                                      color: Color(0xFFE0E0E0),
                                      width: 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  child: const Text(
                                    'Close',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Save Button
                              SizedBox(
                                width: 140,
                                height: 48,
                                child: ElevatedButton(
                                  onPressed: (_isSaving || _hasExistingEntry || !_hasCheckedDevice) 
                                      ? null 
                                      : _saveGuestInfo,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey[800],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Save',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

