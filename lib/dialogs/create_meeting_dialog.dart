import 'package:flutter/material.dart';

class CreateMeetingDialog extends StatefulWidget {
  final Function(String title) onConfirm;

  const CreateMeetingDialog({
    super.key,
    required this.onConfirm,
  });

  @override
  State<CreateMeetingDialog> createState() => _CreateMeetingDialogState();
}

class _CreateMeetingDialogState extends State<CreateMeetingDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        await widget.onConfirm(_titleController.text.trim());
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create meeting: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return AlertDialog(
      title: Text(
        'Create New Meeting',
        style: theme.textTheme.headlineSmall,
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter a title for your new meeting:',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Meeting Title',
                hintText: 'e.g., Weekly Team Standup',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a meeting title';
                }
                if (value.trim().length < 3) {
                  return 'Title must be at least 3 characters long';
                }
                if (value.trim().length > 100) {
                  return 'Title must be less than 100 characters';
                }
                return null;
              },
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _handleSubmit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Create Meeting'),
        ),
      ],
      actionsAlignment: MainAxisAlignment.end,
    );
  }
}
