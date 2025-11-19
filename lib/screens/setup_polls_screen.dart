import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';
import '../providers/manage_meetings_provider.dart';

class SetupPollsScreen extends StatefulWidget {
  final String meetingId;
  final String meetingTitle;

  const SetupPollsScreen({
    super.key,
    required this.meetingId,
    required this.meetingTitle,
  });

  @override
  State<SetupPollsScreen> createState() => _SetupPollsScreenState();
}

class _SetupPollsScreenState extends State<SetupPollsScreen> {
  Map<String, Poll> _polls = {};
  bool _isLoading = false;
  StreamSubscription<QuerySnapshot>? _pollsSubscription;
  Set<String> _expandedPolls = {};
  Map<String, TextEditingController> _questionControllers = {};
  Map<String, List<TextEditingController>> _optionControllers = {};

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
         return Scaffold(
       resizeToAvoidBottomInset: false,
       appBar: AppBar(
        title: Row(
          children: [
            Icon(
              Icons.poll,
              color: Colors.white,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              'Setup Polls - ${widget.meetingTitle}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
            tooltip: 'Close',
          ),
        ],
      ),
             body: SingleChildScrollView(
         padding: const EdgeInsets.all(16),
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             // Create Poll button - right aligned
             Row(
               children: [
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
               SizedBox(
                 height: MediaQuery.of(context).size.height * 0.6,
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
               ...(_polls.entries.map((entry) {
                 final pollId = entry.key;
                 final poll = entry.value;
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
                             padding: const EdgeInsets.only(top: 16, bottom: 16, left: 8, right: 8),
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
               })),
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
        options: ['Option 1', 'Option 2'],
        isActive: false,
      );
      
      await provider.createPoll(widget.meetingId, poll);
      
      // Check if widget is still mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll created successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Check if widget is still mounted before showing snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating poll: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
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
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Poll updated successfully!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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
    
    // Get ScaffoldMessenger from widget's context before showing dialog
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Poll'),
        content: Text('Are you sure you want to delete "${poll.question}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              try {
                final provider = Provider.of<ManageMeetingsProvider>(context, listen: false);
                await provider.deletePoll(widget.meetingId, pollId);
                
                // Check if widget is still mounted before showing snackbar
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Poll deleted successfully!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                // Check if widget is still mounted before showing snackbar
                if (mounted) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting poll: $e'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
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

  void _togglePollActive(String pollId, bool isActive) async {
    final provider = Provider.of<ManageMeetingsProvider>(context, listen: false);
    try {
      await provider.updatePoll(widget.meetingId, pollId, Poll(
        question: _polls[pollId]!.question,
        options: _polls[pollId]!.options,
        isActive: isActive,
        createdAt: _polls[pollId]!.createdAt,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Poll "${_polls[pollId]!.question}" is now ${isActive ? 'Active' : 'Inactive'}'),
            backgroundColor: isActive ? Colors.green : Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
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

    // Listen to real-time changes in polls subcollection
    _pollsSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meetings')
        .doc(widget.meetingId)
        .collection('polls')
        .orderBy('created_at', descending: true)
        .snapshots()
        .listen((snapshot) {
      if (!mounted) return;
      
      setState(() {
        // Convert to map, sorted by createdAt (latest first)
        _polls = {
          for (var doc in snapshot.docs)
            doc.id: Poll.fromMap(doc.data())
        };
      });
    }, onError: (error) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
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
    });
  }
}
