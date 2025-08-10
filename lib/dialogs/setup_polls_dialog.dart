import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../providers/manage_meetings_provider.dart';

class SetupPollsDialog extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;

  const SetupPollsDialog({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
  });

  @override
  State<SetupPollsDialog> createState() => _SetupPollsDialogState();
}

class _SetupPollsDialogState extends State<SetupPollsDialog> {
  Map<String, Poll> _polls = {};
  bool _isLoading = false;
  StreamSubscription<DocumentSnapshot>? _pollsSubscription;
  ScaffoldMessengerState? _scaffoldMessenger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
             child: Container(
         constraints: const BoxConstraints(
           maxWidth: 600,
           maxHeight: double.infinity,
         ),
                 child: Column(
           mainAxisSize: MainAxisSize.max,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
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
                    Icons.poll,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Setup Polls',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    
                    // Polls section header
                    Row(
                      children: [
                        Text(
                          'Polls',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _isLoading ? null : _createPoll,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Create Poll'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                                         // Polls list
                     if (_polls.isEmpty)
                       Expanded(
                         child: Center(
                           child: Column(
                             mainAxisAlignment: MainAxisAlignment.center,
                             children: [
                               Icon(
                                 Icons.poll_outlined,
                                 size: 64,
                                 color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                               ),
                               const SizedBox(height: 16),
                               Text(
                                 'No polls created yet',
                                 style: theme.textTheme.titleMedium?.copyWith(
                                   color: theme.colorScheme.onSurfaceVariant,
                                 ),
                               ),
                               const SizedBox(height: 8),
                               Text(
                                 'Create your first poll to get started',
                                 style: theme.textTheme.bodyMedium?.copyWith(
                                   color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
                                 ),
                               ),
                             ],
                           ),
                         ),
                       )
                     else
                       Expanded(
                         child: ListView.builder(
                           itemCount: _polls.length,
                           itemBuilder: (context, index) {
                             final pollId = _polls.keys.elementAt(index);
                             final poll = _polls[pollId]!;
                             return Card(
                               margin: const EdgeInsets.only(bottom: 12),
                               child: ListTile(
                                 leading: CircleAvatar(
                                   backgroundColor: theme.colorScheme.primaryContainer,
                                   child: Text(
                                     '${index + 1}',
                                     style: TextStyle(
                                       color: theme.colorScheme.onPrimaryContainer,
                                       fontWeight: FontWeight.bold,
                                     ),
                                   ),
                                 ),
                                 title: Text(
                                   poll.question,
                                   style: const TextStyle(fontWeight: FontWeight.w600),
                                 ),
                                 subtitle: Text(
                                   '${poll.options.length} options • ${poll.isActive ? 'Active' : 'Inactive'}',
                                 ),
                                 trailing: Row(
                                   mainAxisSize: MainAxisSize.min,
                                   children: [
                                     IconButton(
                                       onPressed: () => _editPoll(pollId),
                                       icon: Icon(
                                         Icons.edit,
                                         color: theme.colorScheme.primary,
                                         size: 20,
                                       ),
                                       tooltip: 'Edit Poll',
                                     ),
                                     IconButton(
                                       onPressed: () => _deletePoll(pollId),
                                       icon: Icon(
                                         Icons.delete,
                                         color: theme.colorScheme.error,
                                         size: 20,
                                       ),
                                       tooltip: 'Delete Poll',
                                     ),
                                   ],
                                 ),
                               ),
                             );
                           },
                         ),
                       ),
                  ],
                ),
              ),
            ),
            
                         // Footer
             Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                 borderRadius: const BorderRadius.only(
                   bottomLeft: Radius.circular(16),
                   bottomRight: Radius.circular(16),
                 ),
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                   ElevatedButton(
                     onPressed: _savePolls,
                     child: const Text('Close'),
                   ),
                 ],
               ),
             ),
          ],
        ),
      ),
    );
  }

  void _createPoll() async {
    try {
      final provider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      
                    // Create a sample poll for now - you can enhance this with a form dialog later
        final poll = Poll(
          question: 'Poll Question ${_polls.length + 1}',
          options: ['Option 1'],
          isActive: false,
        );
      
      await provider.createPoll(widget.meetingId, poll);
      
      // Check if widget is still mounted before showing snackbar
      if (mounted && _scaffoldMessenger != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scaffoldMessenger != null) {
            _scaffoldMessenger!.showSnackBar(
              const SnackBar(
                content: Text('Poll created successfully!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      }
    } catch (e) {
      // Check if widget is still mounted before showing snackbar
      if (mounted && _scaffoldMessenger != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scaffoldMessenger != null) {
            _scaffoldMessenger!.showSnackBar(
              SnackBar(
                content: Text('Error creating poll: $e'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        });
      }
    }
  }

  void _editPoll(String pollId) {
    // TODO: Implement poll editing with a form dialog
    if (_scaffoldMessenger != null) {
      _scaffoldMessenger!.showSnackBar(
        SnackBar(
          content: Text('Edit poll - Implement editing logic.'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _deletePoll(String pollId) {
    final poll = _polls[pollId];
    if (poll == null) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Poll'),
        content: Text('Are you sure you want to delete "${poll.question}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final provider = Provider.of<ManageMeetingsProvider>(context, listen: false);
                await provider.deletePoll(widget.meetingId, pollId);
                
                // Check if widget is still mounted before showing snackbar
                if (mounted && _scaffoldMessenger != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _scaffoldMessenger != null) {
                      _scaffoldMessenger!.showSnackBar(
                        const SnackBar(
                          content: Text('Poll deleted successfully!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  });
                }
              } catch (e) {
                // Check if widget is still mounted before showing snackbar
                if (mounted && _scaffoldMessenger != null) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && _scaffoldMessenger != null) {
                      _scaffoldMessenger!.showSnackBar(
                        SnackBar(
                          content: Text('Error deleting poll: $e'),
                          backgroundColor: Colors.red,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  });
                }
              }
            },
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _savePolls() {
    // Since we're saving polls immediately when created/updated/deleted,
    // this method just closes the dialog
    Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    _setupPollsListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scaffoldMessenger = ScaffoldMessenger.of(context);
  }

  @override
  void dispose() {
    _pollsSubscription?.cancel();
    super.dispose();
  }

  void _setupPollsListener() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Listen to real-time changes in the polls field
    _pollsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meetings')
        .doc(widget.meetingId)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return; // Check if widget is still mounted
      
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final pollsData = data['polls'] as Map<String, dynamic>?;
        
        if (pollsData != null) {
          setState(() {
            _polls = Map.fromEntries(
              pollsData.entries.map(
                (entry) => MapEntry(entry.key, Poll.fromMap(entry.value)),
              ),
            );
          });
        } else {
          setState(() {
            _polls = {};
          });
        }
      } else {
        setState(() {
          _polls = {};
        });
      }
    }, onError: (error) {
      // Only show error if widget is still mounted
      if (mounted && _scaffoldMessenger != null) {
        // Use a delayed callback to ensure the widget is fully built
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _scaffoldMessenger != null) {
            _scaffoldMessenger!.showSnackBar(
              SnackBar(
                content: Text('Error loading polls: $error'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        });
      }
    });
  }
}


