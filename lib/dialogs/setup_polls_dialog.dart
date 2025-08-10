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
  Set<String> _expandedPolls = {};
  Map<String, TextEditingController> _questionControllers = {};
  Map<String, List<TextEditingController>> _optionControllers = {};

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
                              final isExpanded = _expandedPolls.contains(pollId);
                              
                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: theme.colorScheme.outline,
                                    width: 2,
                                  ),
                                ),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Column(
                                    children: [
                                      ListTile(
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
                                          // Active/Inactive switch
                                          Transform.scale(
                                            scale: 0.7,
                                            child: Switch(
                                              value: poll.isActive,
                                              onChanged: (value) => _togglePollActive(pollId, value),
                                              activeColor: Colors.green,
                                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          IconButton(
                                            onPressed: () => _editPoll(pollId),
                                            icon: Icon(
                                              isExpanded ? Icons.expand_less : Icons.edit,
                                              color: theme.colorScheme.primary,
                                              size: 20,
                                            ),
                                            tooltip: isExpanded ? 'Collapse' : 'Edit Poll',
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
                                    
                                    // Expandable edit section
                                    if (isExpanded)
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                                          borderRadius: const BorderRadius.only(
                                            bottomLeft: Radius.circular(12),
                                            bottomRight: Radius.circular(12),
                                          ),
                                          border: Border(
                                            top: BorderSide(
                                              color: theme.colorScheme.outline.withOpacity(0.5),
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Question field
                                            Text(
                                              'Question',
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: _questionControllers[pollId],
                                              decoration: InputDecoration(
                                                hintText: 'Enter poll question',
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                isDense: true,
                                              ),
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            
                                            const SizedBox(height: 16),
                                            
                                            // Options section
                                            Row(
                                              children: [
                                                Text(
                                                  'Options',
                                                  style: theme.textTheme.titleSmall?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Spacer(),
                                                IconButton(
                                                  onPressed: () => _addOption(pollId),
                                                  icon: const Icon(Icons.add, size: 16),
                                                  tooltip: 'Add Option',
                                                  style: IconButton.styleFrom(
                                                    backgroundColor: theme.colorScheme.primary,
                                                    foregroundColor: Colors.white,
                                                    minimumSize: const Size(32, 32),
                                                    padding: EdgeInsets.zero,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            
                                            // Options list
                                            if (_optionControllers.containsKey(pollId))
                                              ...(_optionControllers[pollId]!.asMap().entries.map((entry) {
                                                final optionIndex = entry.key;
                                                final controller = entry.value;
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: Row(
                                                    children: [
                                                      Expanded(
                                                        child: TextField(
                                                          controller: controller,
                                                          decoration: InputDecoration(
                                                            hintText: 'Option ${optionIndex + 1}',
                                                            border: OutlineInputBorder(
                                                              borderRadius: BorderRadius.circular(8),
                                                            ),
                                                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                                            isDense: true,
                                                          ),
                                                          style: const TextStyle(fontSize: 14),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      if (_optionControllers[pollId]!.length > 1)
                                                        IconButton(
                                                          onPressed: () => _removeOption(pollId, optionIndex),
                                                          icon: const Icon(Icons.remove, size: 16),
                                                          tooltip: 'Remove Option',
                                                          style: IconButton.styleFrom(
                                                            backgroundColor: theme.colorScheme.error,
                                                            foregroundColor: Colors.white,
                                                            minimumSize: const Size(32, 32),
                                                            padding: EdgeInsets.zero,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                );
                                              })),
                                            
                                            const SizedBox(height: 8),
                                            
                                            // Save button
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.end,
                                              children: [
                                                TextButton(
                                                  onPressed: () => _editPoll(pollId),
                                                  child: const Text('Cancel'),
                                                ),
                                                const SizedBox(width: 12),
                                                ElevatedButton(
                                                  onPressed: () => _savePollChanges(pollId),
                                                  child: const Text('Save Changes'),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
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
    setState(() {
      if (_expandedPolls.contains(pollId)) {
        _expandedPolls.remove(pollId);
        // Clean up controllers when collapsing
        _questionControllers.remove(pollId);
        _optionControllers.remove(pollId);
      } else {
        _expandedPolls.add(pollId);
        // Initialize controllers when expanding
        final poll = _polls[pollId];
        if (poll != null) {
          _questionControllers[pollId] = TextEditingController(text: poll.question);
          _optionControllers[pollId] = poll.options.map((option) => TextEditingController(text: option)).toList();
        }
      }
    });
  }

  void _addOption(String pollId) {
    setState(() {
      if (_optionControllers.containsKey(pollId)) {
        _optionControllers[pollId]!.add(TextEditingController(text: 'Option ${_optionControllers[pollId]!.length + 1}'));
      }
    });
  }

  void _removeOption(String pollId, int optionIndex) {
    setState(() {
      if (_optionControllers.containsKey(pollId) && _optionControllers[pollId]!.length > 1) {
        _optionControllers[pollId]![optionIndex].dispose();
        _optionControllers[pollId]!.removeAt(optionIndex);
      }
    });
  }

  void _savePollChanges(String pollId) async {
    try {
      final questionController = _questionControllers[pollId];
      final optionControllers = _optionControllers[pollId];
      
      if (questionController == null || optionControllers == null) return;
      
      // Preserve the original createdAt timestamp to maintain poll order
      final originalPoll = _polls[pollId];
      if (originalPoll == null) return;
      
      final updatedPoll = Poll(
        question: questionController.text.trim(),
        options: optionControllers.map((controller) => controller.text.trim()).where((text) => text.isNotEmpty).toList(),
        isActive: originalPoll.isActive,
        createdAt: originalPoll.createdAt, // Preserve original creation time
      );
      
      final provider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      await provider.updatePoll(widget.meetingId, pollId, updatedPoll);
      
      // Collapse the edit section
      setState(() {
        _expandedPolls.remove(pollId);
        _questionControllers.remove(pollId);
        _optionControllers.remove(pollId);
      });
      
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          const SnackBar(
            content: Text('Poll updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text('Error updating poll: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
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

  void _togglePollActive(String pollId, bool isActive) async {
    final provider = Provider.of<ManageMeetingsProvider>(context, listen: false);
    try {
      await provider.updatePoll(widget.meetingId, pollId, Poll(
        question: _polls[pollId]!.question,
        options: _polls[pollId]!.options,
        isActive: isActive,
        createdAt: _polls[pollId]!.createdAt,
      ));

      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text('Poll "${_polls[pollId]!.question}" is now ${isActive ? 'Active' : 'Inactive'}'),
            backgroundColor: isActive ? Colors.green : Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted && _scaffoldMessenger != null) {
        _scaffoldMessenger!.showSnackBar(
          SnackBar(
            content: Text('Error toggling poll active status: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
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
    // Clean up all controllers
    for (final controller in _questionControllers.values) {
      controller.dispose();
    }
    for (final controllers in _optionControllers.values) {
      for (final controller in controllers) {
        controller.dispose();
      }
    }
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
            // Convert to list, sort by createdAt (latest first), then convert back to map
            final pollsList = pollsData.entries.map(
              (entry) => MapEntry(entry.key, Poll.fromMap(entry.value)),
            ).toList();
            
            // Sort by createdAt in descending order (latest first)
            pollsList.sort((a, b) => b.value.createdAt.compareTo(a.value.createdAt));
            
            _polls = Map.fromEntries(pollsList);
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


