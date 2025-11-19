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
  String? _expandedPollId; // Only one poll expanded at a time
  Map<String, TextEditingController> _questionControllers = {};
  Map<String, List<TextEditingController>> _optionControllers = {};
  Set<String> _savingPolls = {}; // Track which polls are being saved
  Set<String> _deletingPolls = {}; // Track which polls are being deleted

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: false,
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
                          Icons.poll,
                          size: 22,
                          color: Color(0xFF424242),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Setup Polls',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF212121),
                            ),
                          ),
                          Text(
                            widget.meetingTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF757575),
                            ),
                          ),
                        ],
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 800),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Create Poll button
                      Row(
                        children: [
                          const Spacer(),
                          TextButton.icon(
                            onPressed: _isLoading ? null : _createPoll,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text(
                              'Create Poll',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[800],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Polls Section
                      if (_polls.isEmpty)
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.poll_outlined,
                                  size: 64,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No polls created yet',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Create your first poll to get started',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF757575),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else ...[
                        _buildSectionHeader(
                          'Polls',
                          'Manage your meeting polls',
                        ),
                        const SizedBox(height: 12),
                        ...(_polls.entries.map((entry) {
                          final pollId = entry.key;
                          final poll = entry.value;
                          final isExpanded = _expandedPollId == pollId;
                          
                          return _buildPollCard(pollId, poll, isExpanded);
                        })),
                      ],
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

  Widget _buildPollCard(String pollId, Poll poll, bool isExpanded) {
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
      child: Column(
        children: [
          // Poll header row
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleExpand(pollId),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                              const SizedBox(width: 8),
                              Text(
                                '${poll.options.length} ${poll.options.length == 1 ? 'option' : 'options'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF757575),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Active/Inactive switch
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: poll.isActive,
                        onChanged: (value) => _togglePollActive(pollId, value),
                        activeColor: Colors.green,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Delete button
                    GestureDetector(
                      onTap: _deletingPolls.contains(pollId) ? null : () => _deletePoll(pollId),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          border: Border.all(
                            color: const Color(0xFFE0E0E0),
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _deletingPolls.contains(pollId)
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: Colors.red,
                              ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Expand/Collapse icon
                    Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: const Color(0xFF757575),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Expandable edit section
          if (isExpanded)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFAFAFA),
                border: Border(
                  top: BorderSide(
                    color: const Color(0xFFF5F5F5),
                    width: 1,
                  ),
                ),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question field
                  const Text(
                    'Question',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _questionControllers[pollId],
                    decoration: InputDecoration(
                      hintText: 'Enter poll question',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF424242), width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    style: const TextStyle(fontSize: 14),
                  ),
                  
                  const SizedBox(height: 20),
                  
                  // Options section
                  Row(
                    children: [
                      const Text(
                        'Options',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF212121),
                        ),
                      ),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => _addOption(pollId),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Add Option'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF424242),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Options list
                  if (_optionControllers.containsKey(pollId))
                    ...(_optionControllers[pollId]!.asMap().entries.map((entry) {
                      final optionIndex = entry.key;
                      final controller = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: 'Option ${optionIndex + 1}',
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF424242), width: 2),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (_optionControllers[pollId]!.length > 1)
                              GestureDetector(
                                onTap: () => _removeOption(pollId, optionIndex),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    border: Border.all(
                                      color: Colors.red[300]!,
                                      width: 1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.remove,
                                    size: 16,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    })),
                  
                  const SizedBox(height: 20),
                  
                  // Save button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _savingPolls.contains(pollId) ? null : () => _toggleExpand(pollId),
                        child: const Text('Cancel'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF757575),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _savingPolls.contains(pollId) ? null : () => _savePollChanges(pollId),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: _savingPolls.contains(pollId)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Save Changes'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _createPoll() async {
    try {
      final provider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      
      final poll = Poll(
        question: 'Poll Question ${_polls.length + 1}',
        options: ['Option 1', 'Option 2'],
        isActive: false,
      );
      
      await provider.createPoll(widget.meetingId, poll);
      
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating poll: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _toggleExpand(String pollId) {
    setState(() {
      if (_expandedPollId == pollId) {
        // Collapse current poll
        _expandedPollId = null;
        // Clean up controllers when collapsing
        _questionControllers.remove(pollId);
        _optionControllers.remove(pollId);
      } else {
        // Collapse any previously expanded poll
        if (_expandedPollId != null) {
          final previousPollId = _expandedPollId!;
          _questionControllers.remove(previousPollId);
          _optionControllers.remove(previousPollId);
        }
        
        // Expand new poll
        _expandedPollId = pollId;
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
    setState(() {
      _savingPolls.add(pollId);
    });

    try {
      final questionController = _questionControllers[pollId];
      final optionControllers = _optionControllers[pollId];
      
      if (questionController == null || optionControllers == null) {
        setState(() {
          _savingPolls.remove(pollId);
        });
        return;
      }
      
      final originalPoll = _polls[pollId];
      if (originalPoll == null) {
        setState(() {
          _savingPolls.remove(pollId);
        });
        return;
      }
      
      final updatedPoll = Poll(
        question: questionController.text.trim(),
        options: optionControllers.map((controller) => controller.text.trim()).where((text) => text.isNotEmpty).toList(),
        isActive: originalPoll.isActive,
        createdAt: originalPoll.createdAt,
      );
      
      final provider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      await provider.updatePoll(widget.meetingId, pollId, updatedPoll);
      
      // Update controllers with new values but keep poll expanded
      if (mounted) {
        setState(() {
          _savingPolls.remove(pollId);
          _questionControllers[pollId] = TextEditingController(text: updatedPoll.question);
          _optionControllers[pollId] = updatedPoll.options.map((option) => TextEditingController(text: option)).toList();
        });
        
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
        setState(() {
          _savingPolls.remove(pollId);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating poll: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _deletePoll(String pollId) {
    final poll = _polls[pollId];
    if (poll == null) return;
    
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
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop();
              
              setState(() {
                _deletingPolls.add(pollId);
              });
              
              try {
                final provider = Provider.of<ManageMeetingsProvider>(context, listen: false);
                await provider.deletePoll(widget.meetingId, pollId);
                
                // Clean up controllers if this poll was expanded
                if (mounted) {
                  setState(() {
                    _deletingPolls.remove(pollId);
                    if (_expandedPollId == pollId) {
                      _expandedPollId = null;
                      _questionControllers.remove(pollId);
                      _optionControllers.remove(pollId);
                    }
                  });
                  
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Poll deleted successfully!'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  setState(() {
                    _deletingPolls.remove(pollId);
                  });
                  
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting poll: $e'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[600],
              foregroundColor: Colors.white,
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
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error toggling poll active status: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _setupPollsListener();
      }
    });
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

    _pollsSubscription?.cancel(); // Cancel existing subscription if any

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
        _polls = {
          for (var doc in snapshot.docs)
            doc.id: Poll.fromMap(doc.data())
        };
        
        // Update controllers if poll is expanded
        if (_expandedPollId != null && _polls.containsKey(_expandedPollId)) {
          final expandedId = _expandedPollId!;
          final poll = _polls[expandedId]!;
          _questionControllers[expandedId] = TextEditingController(text: poll.question);
          _optionControllers[expandedId] = poll.options.map((option) => TextEditingController(text: option)).toList();
        }
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
