import 'package:flutter/material.dart';

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
  List<Poll> _polls = [];
  bool _isLoading = false;

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
          maxHeight: 500,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
                            final poll = _polls[index];
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
                                      onPressed: () => _editPoll(index),
                                      icon: Icon(
                                        Icons.edit,
                                        color: theme.colorScheme.primary,
                                        size: 20,
                                      ),
                                      tooltip: 'Edit Poll',
                                    ),
                                    IconButton(
                                      onPressed: () => _deletePoll(index),
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
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _polls.isNotEmpty ? _savePolls : null,
                    child: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createPoll() {
    // TODO: Implement poll creation
    setState(() {
      _polls.add(Poll(
        question: 'Sample Poll Question ${_polls.length + 1}',
        options: ['Option 1', 'Option 2', 'Option 3'],
        isActive: false,
      ));
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sample poll created! Implement full creation logic.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _editPoll(int index) {
    // TODO: Implement poll editing
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Edit poll ${index + 1} - Implement editing logic.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _deletePoll(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Poll'),
        content: Text('Are you sure you want to delete "${_polls[index].question}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _polls.removeAt(index);
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Poll deleted'),
                  duration: Duration(seconds: 2),
                ),
              );
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
    // TODO: Implement saving polls to database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Polls saved successfully!'),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
    Navigator.of(context).pop();
  }
}

// Simple Poll model for now
class Poll {
  final String question;
  final List<String> options;
  final bool isActive;

  Poll({
    required this.question,
    required this.options,
    this.isActive = false,
  });
}
