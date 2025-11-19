import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../providers/manage_meetings_provider.dart';

class ClubScreen extends StatefulWidget {
  final String clubCode;

  const ClubScreen({
    super.key,
    required this.clubCode,
  });

  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  String? _clubName;
  String? _clubInfo;
  String? _userId;
  List<Meeting> _meetings = [];
  bool _isLoading = true;
  String? _error;
  StreamSubscription<DocumentSnapshot>? _clubCodeSubscription;
  StreamSubscription<QuerySnapshot>? _meetingsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadClubData();
      }
    });
  }

  Future<void> _loadClubData() async {
    if (!mounted) return;

    try {
      // Get club code document
      final clubCodeDoc = await FirebaseFirestore.instance
          .collection('club_codes')
          .doc(widget.clubCode)
          .get();

      if (!clubCodeDoc.exists) {
        if (mounted) {
          setState(() {
            _error = 'Club not found';
            _isLoading = false;
          });
        }
        return;
      }

      final uid = clubCodeDoc.data()?['uid'] as String?;
      if (uid == null) {
        if (mounted) {
          setState(() {
            _error = 'Invalid club data';
            _isLoading = false;
          });
        }
        return;
      }

      _userId = uid;

      // Set up real-time listener for club code (in case it changes)
      _clubCodeSubscription = FirebaseFirestore.instance
          .collection('club_codes')
          .doc(widget.clubCode)
          .snapshots()
          .listen((snapshot) {
        if (!mounted) return;
        if (!snapshot.exists) {
          setState(() {
            _error = 'Club not found';
            _isLoading = false;
          });
          return;
        }
        final newUid = snapshot.data()?['uid'] as String?;
        if (newUid != null && newUid != _userId) {
          _userId = newUid;
          _loadUserData();
          _setupMeetingsListener();
        }
      });

      // Load user data and set up meetings listener
      await _loadUserData();
      _setupMeetingsListener();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading club: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadUserData() async {
    if (_userId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userId!)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (mounted) {
          setState(() {
            _clubName = data?['club_name'] as String? ?? 'Unnamed Club';
            _clubInfo = data?['club_info'] as String?;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _error = 'Club owner information not available';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error loading club information: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _setupMeetingsListener() {
    if (_userId == null) return;

    _meetingsSubscription?.cancel();

    _meetingsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId!)
        .collection('meetings')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;

      setState(() {
        _meetings = snapshot.docs
            .map((doc) => Meeting.fromFirestore(doc))
            .toList();
      });
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _error = 'Error loading meetings: $error';
        });
      }
    });
  }

  @override
  void dispose() {
    _clubCodeSubscription?.cancel();
    _meetingsSubscription?.cancel();
    super.dispose();
  }

  Widget _buildSectionHeader(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF757575),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToMeeting(String meetingId) {
    // Use Navigator.pushNamed to update URL in browser without full reload
    Navigator.pushNamed(context, '/meetings/$meetingId');
  }

  String _formatMeetingCode(String meetingId) {
    // Format meeting code with spaces for readability (e.g., "1234 5678")
    if (meetingId.length <= 4) return meetingId;
    final chunks = <String>[];
    for (int i = 0; i < meetingId.length; i += 4) {
      final end = (i + 4 < meetingId.length) ? i + 4 : meetingId.length;
      chunks.add(meetingId.substring(i, end));
    }
    return chunks.join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F0),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.groups,
                      size: 22,
                      color: Color(0xFF424242),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Club',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(40),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 48,
                                  color: Colors.red[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF212121),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 800),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Club Info Section
                                _buildSectionHeader(
                                  'Club Information',
                                  'View club details',
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE0E0E0)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.08),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 40,
                                          height: 40,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF5F5F5),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.groups,
                                            size: 22,
                                            color: Color(0xFF424242),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                _clubName ?? 'Unnamed Club',
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF212121),
                                                ),
                                              ),
                                              if (_clubInfo != null && _clubInfo!.isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  _clubInfo!,
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF757575),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                
                                const SizedBox(height: 32),
                                
                                // Meetings Section
                                _buildSectionHeader(
                                  'Meetings',
                                  'Browse available meetings',
                                ),
                                const SizedBox(height: 12),
                                
                                if (_meetings.isEmpty)
                                  Container(
                                    padding: const EdgeInsets.all(40),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE0E0E0)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.08),
                                          blurRadius: 3,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.event_note_outlined,
                                            size: 64,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'No meetings available',
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF212121),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'Check back later for upcoming meetings',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Color(0xFF757575),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                else
                                  ...(_meetings.map((meeting) {
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFE0E0E0)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(0.08),
                                            blurRadius: 3,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _navigateToMeeting(meeting.id),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(20),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 40,
                                                  height: 40,
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF5F5F5),
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(
                                                    Icons.event,
                                                    size: 22,
                                                    color: Color(0xFF424242),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        meeting.title,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight: FontWeight.w500,
                                                          color: Color(0xFF212121),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        _formatMeetingCode(meeting.id),
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w500,
                                                          letterSpacing: 2,
                                                          color: Color(0xFF424242),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const Icon(
                                                  Icons.chevron_right,
                                                  color: Color(0xFF757575),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  })),
                              ],
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
