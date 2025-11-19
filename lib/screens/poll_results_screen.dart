import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/meeting_utils.dart';
import '../providers/manage_meetings_provider.dart';

class PollResultsScreen extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;

  const PollResultsScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
  });

  @override
  State<PollResultsScreen> createState() => _PollResultsScreenState();
}

class _PollResultsScreenState extends State<PollResultsScreen> {
  Map<String, Poll> _polls = {};
  bool _isLoading = true;
  String? _error;
  String? _creatorId;
  StreamSubscription<QuerySnapshot>? _pollsSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initialize();
      }
    });
  }

  Future<void> _initialize() async {
    if (!mounted) return;
    
    try {
      // Get creator_id first
      _creatorId = await MeetingUtils.getCreatorId(widget.meetingId);
      
      if (!mounted) return;
      
      if (_creatorId == null) {
        if (mounted) {
          setState(() {
            _error = 'Could not load meeting information';
            _isLoading = false;
          });
        }
        return;
      }
      
      // Set up real-time listener
      _setupPollsListener();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error initializing: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _setupPollsListener() {
    if (_creatorId == null || !mounted) return;
    
    _pollsSubscription?.cancel(); // Cancel existing subscription if any
    
    _pollsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(_creatorId)
        .collection('meetings')
        .doc(widget.meetingId)
        .collection('polls')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _error = null;
        
        // Convert to Poll objects (already sorted by query)
        _polls = {
          for (var doc in snapshot.docs)
            doc.id: Poll.fromMap(doc.data())
        };
      });
    }, onError: (error) {
      if (mounted) {
        setState(() {
          _error = 'Error loading polls: $error';
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _pollsSubscription?.cancel();
    super.dispose();
  }

  void _handleClose() {
    if (mounted) {
      Navigator.of(context).pop();
    }
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

  Widget _buildPollCard(Poll poll) {
    final totalVotes = poll.totalResponses;

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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poll question header
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.poll,
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
                        poll.question,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: poll.isActive 
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              poll.isActive ? 'Active' : 'Inactive',
                              style: TextStyle(
                                fontSize: 12,
                                color: poll.isActive ? Colors.green[700] : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (totalVotes > 0) ...[
                            const SizedBox(width: 8),
                            Text(
                              '$totalVotes ${totalVotes == 1 ? 'response' : 'responses'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF757575),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (poll.options.isNotEmpty) ...[
              const SizedBox(height: 20),
              // Poll options with visual bars
              ...poll.options.map((option) {
                final votes = poll.tallies[option] ?? 0;
                final percentage = totalVotes > 0 ? (votes / totalVotes * 100) : 0.0;
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ),
                          Text(
                            '$votes ${votes == 1 ? 'vote' : 'votes'}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF424242),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: totalVotes > 0 ? percentage / 100 : 0,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFF5F5F5),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            poll.isActive 
                                ? const Color(0xFF424242)
                                : Colors.grey[400]!,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            
            // Winner display
            if (totalVotes > 0) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.emoji_events,
                      size: 20,
                      color: Colors.amber[700],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _getWinnerText(poll),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getWinnerText(Poll poll) {
    if (poll.totalResponses == 0) return 'No votes yet';
    
    final tallies = poll.tallies;
    if (tallies.isEmpty) return 'No votes yet';
    
    // Find the option(s) with the highest vote count
    final maxVotes = tallies.values.reduce((a, b) => a > b ? a : b);
    final winners = tallies.entries
        .where((entry) => entry.value == maxVotes)
        .map((entry) => entry.key)
        .toList();
    
    if (winners.isEmpty) return 'No votes yet';
    
    if (winners.length == 1) {
      return 'Winner: ${winners[0]}';
    } else {
      // Tie situation
      return 'Tie: ${winners.join(', ')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Header with title and close button
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              decoration: const BoxDecoration(
                color: Color(0xFFF0F0F0),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.analytics,
                          size: 22,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Text(
                        'Poll Results',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: _handleClose,
                    icon: const Icon(Icons.close, size: 24),
                    color: const Color(0xFF424242),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
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
                                  'Error loading polls',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF757575),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : _polls.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.poll_outlined,
                                      size: 64,
                                      color: Colors.grey[300],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No polls found',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF212121),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'This meeting doesn\'t have any polls yet.',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF757575),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionHeader(
                                    'Results',
                                    'Live poll results',
                                  ),
                                  const SizedBox(height: 12),
                                  ..._polls.entries.map((entry) {
                                    return _buildPollCard(entry.value);
                                  }).toList(),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
