import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../utils/meeting_utils.dart';
import '../providers/manage_meetings_provider.dart';

class PollResultsDialog extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;

  const PollResultsDialog({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
  });

  @override
  State<PollResultsDialog> createState() => _PollResultsDialogState();
}

class _PollResultsDialogState extends State<PollResultsDialog> {
  Map<String, Poll> _polls = {};
  bool _isLoading = true;
  String? _error;
  String? _creatorId;
  StreamSubscription<QuerySnapshot>? _pollsSubscription;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      // Get creator_id first
      _creatorId = await MeetingUtils.getCreatorId(widget.meetingId);
      
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
    if (_creatorId == null) return;
    
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 800,
          maxHeight: double.infinity,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.only(top: 8, bottom: 8, left: 16, right: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.analytics,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Poll Results - ${widget.meetingTitle}',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    tooltip: 'Close',
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
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: theme.colorScheme.error,
                                  size: 48,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading polls',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    color: theme.colorScheme.error,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _error!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
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
                                  children: [
                                    Icon(
                                      Icons.poll_outlined,
                                      color: theme.colorScheme.onSurfaceVariant,
                                      size: 48,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No polls found',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'This meeting doesn\'t have any polls yet.',
                                      style: theme.textTheme.bodyMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SingleChildScrollView(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _polls.entries.map((entry) {
                                  final poll = entry.value;
                                  
                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Poll question header
                                          Row(
                                            children: [
                                              Icon(
                                                Icons.question_answer,
                                                color: theme.colorScheme.primary,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  poll.question,
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: poll.isActive 
                                                      ? Colors.green.withOpacity(0.2)
                                                      : Colors.grey.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  poll.isActive ? 'Active' : 'Inactive',
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: poll.isActive ? Colors.green : Colors.grey,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          const SizedBox(height: 12),
                                          
                                          // Poll options with results
                                          ...poll.options.map((option) {
                                            final votes = poll.tallies[option] ?? 0;
                                            
                                            return Padding(
                                              padding: const EdgeInsets.only(bottom: 8),
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          option,
                                                          style: theme.textTheme.bodyMedium?.copyWith(
                                                            fontWeight: FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                      Text(
                                                        '$votes votes',
                                                        style: theme.textTheme.bodySmall?.copyWith(
                                                          color: theme.colorScheme.onSurfaceVariant,
                                                          fontWeight: FontWeight.w600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            );
                                          }),
                                          
                                          if (poll.totalResponses > 0) ...[
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.people,
                                                    color: theme.colorScheme.primary,
                                                    size: 14,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    'Total Responses: ${poll.totalResponses}',
                                                    style: theme.textTheme.bodySmall?.copyWith(
                                                      fontWeight: FontWeight.w600,
                                                      color: theme.colorScheme.primary,
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
                                }).toList(),
                              ),
                            ),
            ),
            
            // Bottom padding
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
