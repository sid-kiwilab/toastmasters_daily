import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'dart:math';
import '../utils/web_device_identifier.dart';
import '../utils/meeting_utils.dart';
import '../providers/manage_meetings_provider.dart';

class VotingWidget extends StatefulWidget {
  final String meetingId;
  
  const VotingWidget({
    super.key,
    required this.meetingId,
  });

  @override
  State<VotingWidget> createState() => _VotingWidgetState();
}

class _VotingWidgetState extends State<VotingWidget> {
  Map<String, Poll> _polls = {};
  List<String> _pollOrder = []; // Maintain stable poll order
  StreamSubscription<QuerySnapshot>? _pollsSubscription;
  int _selectedPollIndex = 0;
  String? _deviceId;
  String? _creatorId; // Cache creator_id to avoid repeated lookups
  Map<String, String?> _userVotes = {}; // pollId -> selectedOption
  bool _isVoting = false; // Track if a vote is currently being processed

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    print('Building VotingWidget with ${_polls.length} polls');
    print('Poll IDs: ${_polls.keys.toList()}');
    
    if (_polls.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!, width: 0.1),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.poll_outlined,
                size: 48,
                color: Colors.grey,
              ),
              const SizedBox(height: 16),
              Text(
                'No polls available',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Polls will appear here when they are created',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

         // Get all polls in stable order (both active and inactive)
     final allPolls = _pollOrder.map((pollId) => MapEntry(pollId, _polls[pollId]!)).toList();
     
     if (allPolls.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey[300]!, width: 0.1),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.poll_outlined,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'No polls available',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Polls will appear here when they are created',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Ensure selected index is valid
    if (_selectedPollIndex >= allPolls.length) {
      _selectedPollIndex = 0;
    }

    final selectedPoll = allPolls[_selectedPollIndex].value;

    return Stack(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!, width: 0.1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Circular numbered pills at the top
          Container(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: allPolls.asMap().entries.map((entry) {
                final index = entry.key;
                final isSelected = index == _selectedPollIndex;
                final poll = entry.value;
                
                                 return GestureDetector(
                   onTap: _isVoting ? null : () {
                     setState(() {
                       _selectedPollIndex = index;
                     });
                   },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 36,
                    height: 36,
                                         decoration: BoxDecoration(
                       color: isSelected ? theme.colorScheme.primary : 
                              (poll.value.isActive ? Colors.grey[200] : Colors.grey[400]),
                       shape: BoxShape.circle,
                       border: Border.all(
                         color: isSelected ? theme.colorScheme.primary : 
                                (poll.value.isActive ? Colors.grey[300]! : Colors.grey[500]!),
                         width: 2,
                       ),
                     ),
                                          child: Center(
                       child: Text(
                         '${index + 1}',
                         style: TextStyle(
                           color: isSelected ? Colors.white : 
                                  (poll.value.isActive ? Colors.grey[700] : Colors.grey[500]),
                           fontSize: 16,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                     ),
                  ),
                );
              }).toList(),
            ),
          ),
          
                     // Question and options below (scrollable)
           Expanded(
             child: SingleChildScrollView(
               padding: const EdgeInsets.all(24),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   // Question with active/inactive status
                   Row(
                     children: [
                       Expanded(
                         child: Text(
                           selectedPoll.question,
                           style: theme.textTheme.headlineSmall?.copyWith(
                             fontWeight: FontWeight.bold,
                             color: selectedPoll.isActive ? theme.colorScheme.primary : Colors.grey[500],
                           ),
                         ),
                       ),
                       if (!selectedPoll.isActive)
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(
                             color: Colors.grey[300],
                             borderRadius: BorderRadius.circular(12),
                           ),
                           child: Text(
                             'INACTIVE',
                             style: TextStyle(
                               color: Colors.grey[600],
                               fontSize: 12,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                     ],
                   ),
                   
                   const SizedBox(height: 32),
                   
                                       // Options
                    ...selectedPoll.options.map((option) {
                      final pollId = allPolls[_selectedPollIndex].key;
                      final isSelected = _userVotes[pollId] == option;
                     
                                           return GestureDetector(
                        onTap: (selectedPoll.isActive && !_isVoting) ? () => _selectOption(pollId, option) : null,
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: selectedPoll.isActive 
                                ? (_isVoting ? Colors.grey[50] : Colors.grey[100])
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : 
                                     (selectedPoll.isActive ? Colors.grey[300]! : Colors.grey[400]!),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                         children: [
                           // Circular check circle with progress indicator
                           Container(
                             width: 24,
                             height: 24,
                             decoration: BoxDecoration(
                               color: isSelected ? theme.colorScheme.primary : Colors.white,
                               shape: BoxShape.circle,
                               border: Border.all(
                                 color: isSelected ? theme.colorScheme.primary : Colors.grey[400]!,
                                 width: 2,
                               ),
                             ),
                             child: isSelected
                                 ? Icon(
                                     Icons.check,
                                     color: Colors.white,
                                     size: 16,
                                   )
                                 : null,
                           ),
                           
                           const SizedBox(width: 16),
                           
                           // Option text
                           Expanded(
                             child: Text(
                               option,
                               style: theme.textTheme.titleMedium?.copyWith(
                                 fontWeight: FontWeight.w500,
                                 color: isSelected ? theme.colorScheme.primary : 
                                        (selectedPoll.isActive ? Colors.grey[800] : Colors.grey[500]),
                               ),
                             ),
                           ),
                           
                           
                         ],
                       ),
                     ),
                   );
                 }),
                 ],
               ),
             ),
           ),
        ],
      ),
    ),
    
    // Loading overlay when voting is in progress
    if (_isVoting)
      Container(
        color: Colors.black.withOpacity(0.3),
        child: const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Recording your vote...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
  ],
);
  }

  @override
  void initState() {
    super.initState();
    print('VotingWidget initState called for meeting: ${widget.meetingId}');
    _initialize();
  }

  Future<void> _initialize() async {
    await _getDeviceId();
    await _loadCreatorId();
    _setupPollsListener();
  }

  Future<void> _loadCreatorId() async {
    _creatorId = await MeetingUtils.getCreatorId(widget.meetingId);
    if (_creatorId == null) {
      print('Warning: Could not get creator_id for meeting ${widget.meetingId}');
    }
  }

  Future<void> _getDeviceId() async {
    try {
      // Use web-specific device identifier that works even in incognito mode
      _deviceId = await WebDeviceIdentifier.getDeviceId();
      print('Web Device ID generated: $_deviceId');
    } catch (e) {
      // Fallback to timestamp-based ID
      _deviceId = 'web_fallback_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1000000)}';
      print('Fallback web device ID generated: $_deviceId');
    }
  }

  @override
  void dispose() {
    _pollsSubscription?.cancel();
    super.dispose();
  }

  void _setupPollsListener() {
    print('Setting up polls listener for meeting: ${widget.meetingId}');

    // Use cached creator_id or return if not available
    if (_creatorId == null) {
      print('Creator ID not available, cannot set up listener');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Could not load meeting information'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    
    // Listen to polls subcollection
    _pollsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_creatorId)
        .collection('meetings')
        .doc(widget.meetingId)
        .collection('polls')
        .orderBy('created_at', descending: false)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      print('Received polls update for meeting ${widget.meetingId}: ${snapshot.docs.length} polls');
      
      setState(() {
        // Convert to Poll objects
        _polls = {
          for (var doc in snapshot.docs)
            doc.id: Poll.fromMap(doc.data())
        };
        
        // Order by createdAt (already sorted by query, but maintain list for UI)
        _pollOrder = _polls.entries.toList()
            .map((entry) => entry.key)
            .toList()
            ..sort((a, b) {
              return _polls[a]!.createdAt.compareTo(_polls[b]!.createdAt);
            });
      });
      
      print('Processed polls: ${_polls.keys.toList()}');
      
      // Check for existing votes from this device
      _checkExistingVotes();
    }, onError: (error) {
      print('Error in polls listener: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading polls: $error'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
  }

     void _checkExistingVotes() {
     if (_deviceId == null) return;
     
     _userVotes.clear();
     for (final pollId in _pollOrder) {
       final poll = _polls[pollId];
       if (poll != null) {
         // Check if this device has already voted in this poll
         if (poll.deviceVotes != null && poll.deviceVotes!.containsKey(_deviceId)) {
           _userVotes[pollId] = poll.deviceVotes![_deviceId];
           print('Device $_deviceId already voted for poll $pollId: ${poll.deviceVotes![_deviceId]}');
         }
       }
     }
   }

  Future<void> _selectOption(String pollId, String option) async {
    if (_deviceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Device ID not available. Please try again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Set voting state to prevent multiple clicks
    setState(() {
      _isVoting = true;
    });

    try {
      // Use Cloud Function to submit vote (handles atomicity server-side)
      final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      await meetingsProvider.submitPollResponse(widget.meetingId, pollId, option, _deviceId!);

      // Update local state after successful vote
      setState(() {
        _userVotes[pollId] = option;
        _isVoting = false; // Reset voting state
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Vote recorded successfully for: $option'),
          backgroundColor: Colors.green,
        ),
      );

    } catch (e) {
      print('Error recording vote: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error recording vote: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Always reset voting state, even if there was an error
      if (mounted) {
        setState(() {
          _isVoting = false;
        });
      }
    }
  }
}
