import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/meeting_utils.dart';
import '../utils/web_device_identifier.dart';

class GuestEntryWidget extends StatefulWidget {
  final String? meetingId;
  final String? creatorId;
  
  const GuestEntryWidget({
    super.key,
    this.meetingId,
    this.creatorId,
  }) : assert(meetingId != null || creatorId != null, 'Either meetingId or creatorId must be provided');

  @override
  State<GuestEntryWidget> createState() => _GuestEntryWidgetState();
}

class _GuestEntryWidgetState extends State<GuestEntryWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _commentsController = TextEditingController();
  
  String? _hearAboutUs; // Selected value for "Where did you hear about us?"
  
  bool _isSaving = false;
  String? _errorMessage;
  String? _deviceId;
  bool _hasCheckedDevice = false;
  bool _hasExistingEntryToday = false;
  int _totalAttendances = 0;
  Map<String, dynamic>? _previousGuestData; // Previous guest info if they've been before
  bool _showNormalForm = false; // If true, show normal form even if previous data exists
  
  // Options for "Where did you hear about us?"
  static const List<String> _hearAboutUsOptions = [
    'Flyers',
    'Website',
    'Word of Mouth',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _getDeviceId();
    await _loadGuestData();
  }
  
  /// Formats a DateTime to a date string (YYYY-MM-DD) for efficient querying
  static String _formatDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  /// Gets today's date string in local timezone
  static String _getTodayDateString() {
    final now = DateTime.now();
    return _formatDateString(now);
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

  Future<void> _loadGuestData() async {
    if (_deviceId == null) return;

    try {
      String? creatorId = widget.creatorId;
      if (creatorId == null && widget.meetingId != null) {
        creatorId = await MeetingUtils.getCreatorId(widget.meetingId!);
      }
      if (creatorId == null) return;

      final todayDateString = _getTodayDateString();
      final guestDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .collection('guests')
          .doc(_deviceId)
          .get();

      if (mounted) {
        final data = guestDoc.data();
        final lastEntryDate = data?['last_entry_date'] as String?;
        final hasEntryToday = lastEntryDate == todayDateString;
        
        setState(() {
          _hasExistingEntryToday = hasEntryToday;
          _totalAttendances = (data?['attendance_count'] as int?) ?? 0;
          // Store previous data if they've been before but not today
          if (!hasEntryToday && data != null && _totalAttendances > 0) {
            _previousGuestData = {
              'name': data['name'] ?? '',
              'email': data['email'] ?? '',
              'phone': data['phone'] ?? '',
              'hear_about_us': data['hear_about_us'] ?? '',
            };
          } else {
            _previousGuestData = null;
          }
        });
      }
    } catch (e) {
      print('Error loading guest data: $e');
      if (mounted) {
        setState(() {
          _hasExistingEntryToday = false;
          _totalAttendances = 0;
          _previousGuestData = null;
        });
      }
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

    if (_hasExistingEntryToday) {
      setState(() {
        _errorMessage = 'You have already submitted your information for today.';
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
      // Get the creator ID
      String? creatorId = widget.creatorId;
      if (creatorId == null && widget.meetingId != null) {
        creatorId = await MeetingUtils.getCreatorId(widget.meetingId!);
      }
      
      if (creatorId == null) {
        setState(() {
          _errorMessage = 'Could not find creator information. Please try again.';
          _isSaving = false;
        });
        return;
      }

      final todayDateString = _getTodayDateString();
      final guestDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .collection('guests')
          .doc(_deviceId);
      
      final phone = _phoneController.text.trim();
      final comments = _commentsController.text.trim();
      
      final batch = FirebaseFirestore.instance.batch();
      
      // Update main document
      final mainData = <String, dynamic>{
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'hear_about_us': _hearAboutUs ?? '',
        'last_entry_date': todayDateString,
        'last_updated': FieldValue.serverTimestamp(),
        'attendance_count': FieldValue.increment(1),
      };
      if (phone.isNotEmpty) mainData['phone'] = phone;
      batch.set(guestDocRef, mainData, SetOptions(merge: true));
      
      // Create attendance document
      final attendanceData = <String, dynamic>{
        'entry_date': todayDateString,
        'created_at': FieldValue.serverTimestamp(),
      };
      if (comments.isNotEmpty) attendanceData['comments'] = comments;
      batch.set(guestDocRef.collection('attendances').doc(todayDateString), attendanceData);
      
      await batch.commit();
      
      // Refresh data
      await _loadGuestData();
      
      setState(() {
        _isSaving = false;
        _hasExistingEntryToday = true;
      });

      // Clear form
      _nameController.clear();
      _emailController.clear();
      _phoneController.clear();
      _commentsController.clear();
      setState(() {
        _hearAboutUs = null;
      });

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

  Widget _buildIsThisYouView() {
    if (_previousGuestData == null) return const SizedBox.shrink();
    
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Container(
        key: const ValueKey('isThisYou'),
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.person_outline, size: 32, color: Colors.blue.shade700),
              ),
              const SizedBox(height: 24),
              
              // Title
              Text(
                'Is this you?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We found your previous information',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 32),
              
              // Info Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoItem(Icons.person, 'Name', _previousGuestData!['name'] ?? ''),
                    if (_previousGuestData!['email']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      _buildInfoItem(Icons.email, 'Email', _previousGuestData!['email'] ?? ''),
                    ],
                    if (_previousGuestData!['phone']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      _buildInfoItem(Icons.phone, 'Phone', _previousGuestData!['phone']),
                    ],
                    if (_previousGuestData!['hear_about_us']?.toString().isNotEmpty == true) ...[
                      const SizedBox(height: 16),
                      _buildInfoItem(Icons.info_outline, 'Heard about us', _previousGuestData!['hear_about_us']),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() => _showNormalForm = true);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('No, change info'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _usePreviousInfoAndSave,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: Colors.blue.shade700,
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)),
                            )
                          : const Text('Yes, use this'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _usePreviousInfoAndSave() async {
    if (_previousGuestData == null || _deviceId == null) return;
    
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      String? creatorId = widget.creatorId;
      if (creatorId == null && widget.meetingId != null) {
        creatorId = await MeetingUtils.getCreatorId(widget.meetingId!);
      }
      if (creatorId == null) {
        setState(() {
          _errorMessage = 'Could not find creator information.';
          _isSaving = false;
        });
        return;
      }

      final todayDateString = _getTodayDateString();
      final guestDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(creatorId)
          .collection('guests')
          .doc(_deviceId);
      
      final batch = FirebaseFirestore.instance.batch();
      
      // Update main document with previous info
      final mainData = <String, dynamic>{
        'name': _previousGuestData!['name'] ?? '',
        'email': _previousGuestData!['email'] ?? '',
        'hear_about_us': _previousGuestData!['hear_about_us'] ?? '',
        'last_entry_date': todayDateString,
        'last_updated': FieldValue.serverTimestamp(),
        'attendance_count': FieldValue.increment(1),
      };
      if (_previousGuestData!['phone']?.toString().isNotEmpty == true) {
        mainData['phone'] = _previousGuestData!['phone'];
      }
      batch.set(guestDocRef, mainData, SetOptions(merge: true));
      
      // Create attendance document
      batch.set(guestDocRef.collection('attendances').doc(todayDateString), {
        'entry_date': todayDateString,
        'created_at': FieldValue.serverTimestamp(),
      });
      
      await batch.commit();
      
      // Refresh data
      await _loadGuestData();
      
      setState(() {
        _isSaving = false;
        _hasExistingEntryToday = true;
      });

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
      print('Error saving: $e');
      setState(() {
        _errorMessage = 'Failed to save. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading only while checking device
    if (!_hasCheckedDevice || _deviceId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    
    final theme = Theme.of(context);
    
    // Show "Is this you?" view if previous data exists and not showing normal form
    final showIsThisYou = !_hasExistingEntryToday && _previousGuestData != null && !_showNormalForm;
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Content
            Expanded(
              child: Align(
                alignment: const Alignment(0, -0.15),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: showIsThisYou
                      ? _buildIsThisYouView()
                      : SingleChildScrollView(
                          key: const ValueKey('form'),
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
                              maxLength: 100,
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
                                counterText: '',
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
                              maxLength: 255,
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
                                counterText: '',
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
                          
                          // Where did you hear about us? (Required)
                          SizedBox(
                            width: 320,
                            child: DropdownButtonFormField<String>(
                              value: _hearAboutUs,
                              decoration: InputDecoration(
                                labelText: 'Where did you hear about us? *',
                                prefixIcon: const Icon(Icons.info_outline),
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
                              items: _hearAboutUsOptions.map((String option) {
                                return DropdownMenuItem<String>(
                                  value: option,
                                  child: Text(option),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  _hearAboutUs = newValue;
                                  _errorMessage = null; // Clear error when selection is made
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select how you heard about us';
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
                              maxLength: 20,
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
                                counterText: '',
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
                              maxLength: 500,
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
                                counterText: '',
                              ),
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) {
                                if (!_isSaving && !_hasExistingEntryToday) {
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
                          if (_hasExistingEntryToday && _errorMessage == null)
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
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.check_circle_outline, 
                                          color: Colors.green[700], 
                                          size: 20,
                                        ),
                                        Expanded(
                                          child: Text(
                                            'Your information has been submitted for today.',
                                            style: TextStyle(
                                              color: Colors.green[700],
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (_totalAttendances > 0)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          'Total attendances: $_totalAttendances',
                                          style: TextStyle(
                                            color: Colors.green[600],
                                            fontSize: 12,
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
                                  onPressed: (_isSaving || _hasExistingEntryToday || !_hasCheckedDevice) 
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
          ),
          ],
        ),
      ),
    );
  }
}

