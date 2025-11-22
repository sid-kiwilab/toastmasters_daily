import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:html' as html;
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

class _ClubScreenState extends State<ClubScreen> with SingleTickerProviderStateMixin {
  String? _clubName;
  String? _clubInfo;
  String? _userId;
  List<Meeting> _meetings = [];
  bool _isLoading = true;
  String? _error;
  bool _showWelcomeDialog = false;
  bool _shouldShowWelcome = false;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  StreamSubscription<DocumentSnapshot>? _clubCodeSubscription;
  StreamSubscription<QuerySnapshot>? _meetingsSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    // Check welcome dialog synchronously before first build to prevent flash
    _checkWelcomeDialog();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadClubData();
      }
    });
  }

  void _checkWelcomeDialog() {
    if (kIsWeb) {
      // Check if welcome dialog has been shown for this club in this session
      final welcomeKey = 'club_welcome_shown_${widget.clubCode}';
      final hasShownWelcome = html.window.sessionStorage[welcomeKey] == 'true';
      
      // Set synchronously to prevent flash on first build
      _shouldShowWelcome = !hasShownWelcome;
    }
  }

  void _showWelcomeWithAnimation() {
    if (_clubName != null && _shouldShowWelcome && !_showWelcomeDialog) {
      setState(() {
        _showWelcomeDialog = true;
      });
      _animationController.forward();
    }
  }

  void _handleWelcomeContinue({bool isGuest = false}) {
    if (kIsWeb) {
      // Mark welcome as shown in sessionStorage
      final welcomeKey = 'club_welcome_shown_${widget.clubCode}';
      html.window.sessionStorage[welcomeKey] = 'true';
    }
    
    if (isGuest && _meetings.isNotEmpty) {
      // Show guest entry widget for the first (latest) meeting
      Navigator.of(context).pushNamed('/clubs/${widget.clubCode}/guest').then((_) {
        // After guest entry is closed, show club content
        if (mounted) {
          setState(() {
            _showWelcomeDialog = false;
            _shouldShowWelcome = false;
          });
        }
      });
    } else {
      // Member or no meetings - just show club content
      setState(() {
        _showWelcomeDialog = false;
        _shouldShowWelcome = false; // Allow club content to show
      });
    }
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
          // Show welcome screen with animation after club name is loaded
          if (_shouldShowWelcome) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _showWelcomeWithAnimation();
              }
            });
          }
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

    // Calculate UTC range for "today" in local timezone
    // This ensures we query server-side efficiently
    final now = DateTime.now();
    final todayStartLocal = DateTime(now.year, now.month, now.day);
    final todayEndLocal = todayStartLocal.add(const Duration(days: 1));
    
    // Convert to UTC for Firestore query (since dates are stored in UTC)
    final todayStartUTC = todayStartLocal.toUtc();
    final todayEndUTC = todayEndLocal.toUtc();

    // Query Firestore server-side to only get today's meetings
    // This is much more efficient than loading all meetings and filtering client-side
    _meetingsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_userId!)
        .collection('meetings')
        .where('meeting_date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStartUTC))
        .where('meeting_date', isLessThan: Timestamp.fromDate(todayEndUTC))
        .orderBy('meeting_date', descending: false)
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
    _animationController.dispose();
    _clubCodeSubscription?.cancel();
    _meetingsSubscription?.cancel();
    super.dispose();
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

  // Helper function to format date
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }
  
  // Helper function to format time
  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    // If there's an error, show it immediately (don't wait for welcome screen)
    if (_error != null && !_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Oops! Nothing lives here...',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF757575),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        Navigator.of(context).pushNamed('/');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Back to Home'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    
    // If welcome should be shown, NEVER show club content - only loading or welcome
    if (_shouldShowWelcome) {
      // Show welcome screen with animation after club name is loaded
      if (_showWelcomeDialog && _clubName != null) {
        return Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth < 600;
                  final buttonWidth = isMobile ? constraints.maxWidth * 0.8 : 320.0;
                  
                  return Center(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 24.0 : 40.0,
                        vertical: 40.0,
                      ),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: 500,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Toastmasters logo
                            Image.asset(
                              'assets/images/logo.png',
                              width: isMobile ? 100 : 120,
                              height: isMobile ? 100 : 120,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 40),
                            
                            // Welcome text
                            Text(
                              'Welcome',
                              style: TextStyle(
                                fontSize: isMobile ? 36 : 42,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF212121),
                                letterSpacing: -1,
                                height: 1.2,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'to $_clubName',
                              style: TextStyle(
                                fontSize: isMobile ? 24 : 28,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF424242),
                                letterSpacing: -0.5,
                                height: 1.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 48),
                            
                            // Decorative line with Toastmasters colors
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFC41E3A),
                                        Color(0xFF003366), // Toastmasters blue
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 60,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE0E0E0),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  width: 40,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF003366),
                                        Color(0xFFC41E3A),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 48),
                            
                            // Question text
                            const Text(
                              'Are you a member or guest?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF757575),
                                letterSpacing: 0.3,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 40),
                            
                            // Member button (Toastmasters red)
                            SizedBox(
                              width: buttonWidth,
                              height: isMobile ? 56 : 60,
                              child: ElevatedButton(
                                onPressed: _handleWelcomeContinue,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFC41E3A),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Member',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Guest button (outlined)
                            SizedBox(
                              width: buttonWidth,
                              height: isMobile ? 56 : 60,
                              child: OutlinedButton(
                                onPressed: () => _handleWelcomeContinue(isGuest: true),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF424242),
                                  side: const BorderSide(
                                    color: Color(0xFFE0E0E0),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Guest',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      }
      
      // Show loading while waiting for club name
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Show club content only after welcome is dismissed
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _isLoading
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(),
                ),
              )
            : SingleChildScrollView(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final isMobile = constraints.maxWidth < 600;
                        
                        return Column(
                          children: [
                            // Header with logo and club name (matching welcome screen style)
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 24.0 : 40.0,
                                vertical: isMobile ? 32.0 : 40.0,
                              ),
                              child: Column(
                                children: [
                                  // Logo
                                  Image.asset(
                                    'assets/images/logo.png',
                                    width: isMobile ? 60 : 80,
                                    height: isMobile ? 60 : 80,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(height: 24),
                                  
                                  // Club name
                                  Text(
                                    _clubName ?? 'Unnamed Club',
                                    style: TextStyle(
                                      fontSize: isMobile ? 28 : 32,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF212121),
                                      letterSpacing: -1,
                                      height: 1.2,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Decorative line with Toastmasters colors
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 40,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFFC41E3A),
                                              Color(0xFF003366),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 60,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0E0E0),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Container(
                                        width: 40,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [
                                              Color(0xFF003366),
                                              Color(0xFFC41E3A),
                                            ],
                                          ),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            
                            // Content
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 24.0 : 40.0,
                                vertical: 32.0,
                              ),
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 800),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                // Meetings Section
                                Text(
                                  'Join Meetings',
                                  style: TextStyle(
                                    fontSize: isMobile ? 20 : 24,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF212121),
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                
                                if (_meetings.isEmpty)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(48),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE0E0E0),
                                        width: 2,
                                      ),
                                    ),
                                    child: Center(
                                      child: Column(
                                        children: [
                                          Icon(
                                            Icons.event_note_outlined,
                                            size: 64,
                                            color: Colors.grey[300],
                                          ),
                                          const SizedBox(height: 20),
                                          const Text(
                                            'No meetings today',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF212121),
                                              letterSpacing: -0.3,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          const Text(
                                            'There are no meetings scheduled for today',
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
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: const Color(0xFFE0E0E0),
                                          width: 2,
                                        ),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _navigateToMeeting(meeting.id),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Padding(
                                            padding: const EdgeInsets.all(24),
                                            child: Row(
                                              children: [
                                                // Meeting icon with gradient background
                                                Container(
                                                  width: 56,
                                                  height: 56,
                                                  decoration: BoxDecoration(
                                                    gradient: const LinearGradient(
                                                      colors: [
                                                        Color(0xFFC41E3A),
                                                        Color(0xFF003366),
                                                      ],
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                    ),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: const Icon(
                                                    Icons.event,
                                                    size: 28,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                const SizedBox(width: 20),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        meeting.title,
                                                        style: const TextStyle(
                                                          fontSize: 18,
                                                          fontWeight: FontWeight.w600,
                                                          color: Color(0xFF212121),
                                                          letterSpacing: -0.3,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Text(
                                                        _formatMeetingCode(meeting.id),
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w500,
                                                          letterSpacing: 2,
                                                          color: Color(0xFF757575),
                                                        ),
                                                      ),
                                                      // Date and Time display - vertically stacked
                                                      if (meeting.meetingDate != null || meeting.meetingTime != null) ...[
                                                        const SizedBox(height: 10),
                                                        Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            if (meeting.meetingDate != null)
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFFF5F5F5),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Icon(
                                                                      Icons.calendar_today,
                                                                      size: 16,
                                                                      color: Color(0xFF424242),
                                                                    ),
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                      _formatDate(meeting.meetingDate!),
                                                                      style: const TextStyle(
                                                                        fontSize: 13,
                                                                        color: Color(0xFF424242),
                                                                        fontWeight: FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                            if (meeting.meetingDate != null && meeting.meetingTime != null)
                                                              const SizedBox(height: 6),
                                                            if (meeting.meetingTime != null)
                                                              Container(
                                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                                decoration: BoxDecoration(
                                                                  color: const Color(0xFFF5F5F5),
                                                                  borderRadius: BorderRadius.circular(6),
                                                                ),
                                                                child: Row(
                                                                  mainAxisSize: MainAxisSize.min,
                                                                  children: [
                                                                    const Icon(
                                                                      Icons.access_time,
                                                                      size: 16,
                                                                      color: Color(0xFF424242),
                                                                    ),
                                                                    const SizedBox(width: 6),
                                                                    Text(
                                                                      _formatTime(meeting.meetingTime!),
                                                                      style: const TextStyle(
                                                                        fontSize: 13,
                                                                        color: Color(0xFF424242),
                                                                        fontWeight: FontWeight.w600,
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                      ],
                                                    ],
                                                  ),
                                                ),
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFF5F5F5),
                                                    borderRadius: BorderRadius.circular(8),
                                                  ),
                                                  child: const Icon(
                                                    Icons.chevron_right,
                                                    color: Color(0xFF424242),
                                                    size: 24,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  })),
                                
                                // Club Info Section (if info exists)
                                if (_clubInfo != null && _clubInfo!.isNotEmpty) ...[
                                  const SizedBox(height: 40),
                                  Text(
                                    'About',
                                    style: TextStyle(
                                      fontSize: isMobile ? 20 : 24,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF212121),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: const Color(0xFFE0E0E0),
                                        width: 2,
                                      ),
                                    ),
                                    child: Text(
                                      _clubInfo!,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w400,
                                        color: Color(0xFF424242),
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}
