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
  List<String> _pollOrder = []; // Maintain stable poll order
  StreamSubscription<QuerySnapshot>? _pollsSubscription;
  int _selectedPollIndex = 0;
  String? _deviceId;
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
                    ...selectedPoll.options.asMap().entries.map((entry) {
                      final index = entry.key;
                      final option = entry.value;
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
           
           // Always order by createdAt date for consistent ordering
           _pollOrder = _polls.entries.toList()
               .map((entry) => entry.key)
               .toList()
               ..sort((a, b) {
                 final pollA = _polls[a]!;
                 final pollB = _polls[b]!;
                 
                 // Sort by createdAt date (oldest first)
                 if (pollA.createdAt != null && pollB.createdAt != null) {
                   return pollA.createdAt!.compareTo(pollB.createdAt!);
                 }
                 
                 // Fallback: if createdAt is null, put them at the end
                 if (pollA.createdAt == null && pollB.createdAt != null) return 1;
                 if (pollA.createdAt != null && pollB.createdAt == null) return -1;
                 
                 // If both are null, maintain some order
                 return a.compareTo(b);
               });
           
           print('Processed polls: ${_polls.keys.toList()}');
           print('Poll order by createdAt: $_pollOrder');
           
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
      // Use Firestore transaction to prevent race conditions
      // First, find the meeting document path
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

      // Now use transaction with the specific document reference
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Get the latest data within the transaction
        final meetingSnapshot = await transaction.get(meetingDoc.reference);
        final meetingData = meetingSnapshot.data();
        
        if (meetingData == null) {
          throw Exception('Meeting data not found');
        }

        final pollsData = meetingData['polls'] as Map<String, dynamic>?;

        if (pollsData == null || !pollsData.containsKey(pollId)) {
          throw Exception('Poll not found');
        }

        final pollData = pollsData[pollId] as Map<String, dynamic>;
        
        // Check if device already voted
        final deviceVotes = pollData['deviceVotes'] as Map<String, dynamic>? ?? {};
        final hasVoted = deviceVotes.containsKey(_deviceId);
        final previousVote = deviceVotes[_deviceId];
        
        // Update the poll with the new vote
        final newTallies = Map<String, int>.from(pollData['tallies'] ?? {});
        int responseIncrement = 0;
        
        if (hasVoted && previousVote != null) {
          // If changing vote, decrement previous option and increment new option
          if (previousVote != option) {
            newTallies[previousVote] = (newTallies[previousVote] ?? 1) - 1;
            newTallies[option] = (newTallies[option] ?? 0) + 1;
            // No increment to totalResponses for vote changes
          }
          // If same option selected, no change needed
        } else {
          // First time voting, just increment the new option
          newTallies[option] = (newTallies[option] ?? 0) + 1;
          responseIncrement = 1; // Only increment for new votes
        }
        
        final newDeviceVotes = Map<String, dynamic>.from(deviceVotes);
        newDeviceVotes[_deviceId!] = option;

        // Update Firestore within transaction - only the necessary fields, createdAt remains unchanged
        transaction.update(meetingDoc.reference, {
          'polls.$pollId.tallies': newTallies,
          'polls.$pollId.totalResponses': (pollData['totalResponses'] ?? 0) + responseIncrement,
          'polls.$pollId.deviceVotes': newDeviceVotes,
        });
      });

      // Update local state after successful transaction
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
