import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math';
import '../utils/web_device_identifier.dart';
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
  StreamSubscription<QuerySnapshot>? _pollsSubscription;
  int _selectedPollIndex = 0;
  String? _deviceId;
  Map<String, String?> _userVotes = {}; // pollId -> selectedOption

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

    // Filter only active polls
    final activePolls = _polls.entries
        .where((entry) => entry.value.isActive)
        .toList();

    if (activePolls.isEmpty) {
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
                'No active polls',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'All polls are currently inactive',
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
    if (_selectedPollIndex >= activePolls.length) {
      _selectedPollIndex = 0;
    }

    final selectedPoll = activePolls[_selectedPollIndex].value;

    return Container(
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
              children: activePolls.asMap().entries.map((entry) {
                final index = entry.key;
                final isSelected = index == _selectedPollIndex;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPollIndex = index;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected ? theme.colorScheme.primary : Colors.grey[200],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? theme.colorScheme.primary : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.grey[700],
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
                   // Question
                   Text(
                     selectedPoll.question,
                     style: theme.textTheme.headlineSmall?.copyWith(
                       fontWeight: FontWeight.bold,
                       color: theme.colorScheme.primary,
                     ),
                   ),
                   
                   const SizedBox(height: 32),
                   
                                       // Options
                    ...selectedPoll.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
                      final pollId = activePolls[_selectedPollIndex].key;
                      final isSelected = _userVotes[pollId] == option;
                     
                                           return GestureDetector(
                        onTap: () => _selectOption(pollId, option),
                        child: Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected ? theme.colorScheme.primary : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                         children: [
                           // Circular check circle
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
                                 color: isSelected ? theme.colorScheme.primary : Colors.grey[800],
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
    );
  }

  @override
  void initState() {
    super.initState();
    print('VotingWidget initState called for meeting: ${widget.meetingId}');
    _getDeviceId().then((_) {
      _setupPollsListener();
    });
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

    // Since we don't know the user ID, we'll search through all users
    // and find the meeting document by its ID
    _pollsSubscription = FirebaseFirestore.instance
        .collectionGroup('meetings')
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      print('Received snapshot update for meeting ${widget.meetingId}');
      print('Snapshot docs count: ${snapshot.docs.length}');
      
      // Find the meeting document with the specific ID
      final meetingDoc = snapshot.docs.where((doc) => doc.id == widget.meetingId).firstOrNull;
      
      if (meetingDoc != null) {
        print('Meeting document found in collection: ${meetingDoc.reference.path}');
        
        final data = meetingDoc.data();
        print('Meeting data keys: ${data.keys.toList()}');
        
        final pollsData = data['polls'] as Map<String, dynamic>?;
        print('Polls data: $pollsData');
        
        if (pollsData != null && pollsData.isNotEmpty) {
          print('Found ${pollsData.length} polls');
          setState(() {
            // Convert to Poll objects
            _polls = pollsData.map((key, value) {
              print('Processing poll $key: $value');
              return MapEntry(key, Poll.fromMap(value));
            });
          });
          print('Processed polls: ${_polls.keys.toList()}');
          
          // Check for existing votes from this device
          _checkExistingVotes();
        } else {
          print('No polls data found');
          setState(() {
            _polls = {};
          });
        }
      } else {
        print('Meeting document not found');
        setState(() {
          _polls = {};
        });
      }
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
    for (final entry in _polls.entries) {
      final pollId = entry.key;
      final poll = entry.value;
      
      // Check if this device has already voted in this poll
      if (poll.deviceVotes != null && poll.deviceVotes!.containsKey(_deviceId)) {
        _userVotes[pollId] = poll.deviceVotes![_deviceId];
        print('Device $_deviceId already voted for poll $pollId: ${poll.deviceVotes![_deviceId]}');
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

    try {
      // Find the meeting document using the same approach as the listener
      final meetingDocs = await FirebaseFirestore.instance
          .collectionGroup('meetings')
          .get();

      final meetingDoc = meetingDocs.docs.where((doc) => doc.id == widget.meetingId).firstOrNull;
      
      if (meetingDoc == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting not found.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final meetingData = meetingDoc.data();
      final pollsData = meetingData['polls'] as Map<String, dynamic>?;

      if (pollsData == null || !pollsData.containsKey(pollId)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll not found.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final pollData = pollsData[pollId] as Map<String, dynamic>;
      
      // Check if device already voted
      final deviceVotes = pollData['deviceVotes'] as Map<String, dynamic>? ?? {};
      final hasVoted = deviceVotes.containsKey(_deviceId);
      final previousVote = deviceVotes[_deviceId];
      
      // Update the poll with the new vote
      final newTallies = Map<String, int>.from(pollData['tallies'] ?? {});
      
      if (hasVoted && previousVote != null) {
        // If changing vote, decrement previous option and increment new option
        if (previousVote != option) {
          newTallies[previousVote] = (newTallies[previousVote] ?? 1) - 1;
          newTallies[option] = (newTallies[option] ?? 0) + 1;
        }
        // If same option selected, no change needed
      } else {
        // First time voting, just increment the new option
        newTallies[option] = (newTallies[option] ?? 0) + 1;
      }
      
      final newDeviceVotes = Map<String, dynamic>.from(deviceVotes);
      newDeviceVotes[_deviceId!] = option;

      // Update Firestore
      await meetingDoc.reference.update({
        'polls.$pollId.tallies': newTallies,
        'polls.$pollId.totalResponses': (pollData['totalResponses'] ?? 0) + 1,
        'polls.$pollId.deviceVotes': newDeviceVotes,
      });

      // Update local state
      setState(() {
        _userVotes[pollId] = option;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(hasVoted && previousVote != option 
              ? 'Vote changed to: $option' 
              : 'Vote recorded for: $option'),
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
    }
  }
}
