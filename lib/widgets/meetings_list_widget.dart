import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/manage_meetings_provider.dart';

class MeetingsListWidget extends StatelessWidget {
  final List<Meeting> meetings;
  final bool isCreatingMeeting;
  final Map<String, bool> uploadingAgendas;
  final VoidCallback onCreateMeeting;
  final Future<void> Function(BuildContext, String) onUploadAgenda;
  final void Function(BuildContext, Meeting) onSetupPolls;
  final void Function(BuildContext, Meeting) onPollResults;
  final Future<void> Function(BuildContext, Meeting, String) onDeleteMeeting;
  final bool isSubscriptionActive;
  final bool hasMoreMeetings;
  final bool isLoadingMore;
  final VoidCallback? onLoadMore;
  final Future<void> Function(BuildContext, Meeting) onSetDateTime;

  const MeetingsListWidget({
    super.key,
    required this.meetings,
    required this.isCreatingMeeting,
    required this.uploadingAgendas,
    required this.onCreateMeeting,
    required this.onUploadAgenda,
    required this.onSetupPolls,
    required this.onPollResults,
    required this.onDeleteMeeting,
    this.isSubscriptionActive = false,
    this.hasMoreMeetings = false,
    this.isLoadingMore = false,
    this.onLoadMore,
    required this.onSetDateTime,
  });

  // Helper method to check if a meeting is past
  bool _isPastMeeting(Meeting meeting) {
    if (meeting.meetingDateTime == null) return false;
    return meeting.meetingDateTime!.isBefore(DateTime.now());
  }

  // Helper function to format date
  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day.toString().padLeft(2, '0')}, ${date.year}';
  }
  
  // Helper function to format time
  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Build combined date and time button widget (for mobile)
  Widget _buildDateTimeButtons(BuildContext context, Meeting meeting) {
    final hasDateTime = meeting.meetingDateTime != null;
    final displayText = hasDateTime
        ? '${_formatDate(meeting.meetingDateTime!)} • ${_formatTime(meeting.meetingDateTime!)}'
        : 'Set Date & Time';
    
    return GestureDetector(
      onTap: () => onSetDateTime(context, meeting),
      child: Container(
        width: double.infinity,
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.transparent,
          border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.event, size: 16, color: Color(0xFF757575)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                displayText,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF757575),
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildMeetingItem(BuildContext context, Meeting meeting, {bool isLast = false}) {
    // Use Selector to listen to specific meeting's agendaUrl updates from provider
    return Selector<ManageMeetingsProvider, String?>(
      key: ValueKey('meeting_${meeting.id}'),
      selector: (_, provider) {
        try {
          final updatedMeeting = provider.meetings.firstWhere((m) => m.id == meeting.id);
          return updatedMeeting.agendaUrl;
        } catch (e) {
          return meeting.agendaUrl;
        }
      },
      builder: (context, updatedAgendaUrl, child) {
        // Get the latest meeting from provider to ensure we have all updated fields
        final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
        Meeting currentMeeting;
        try {
          currentMeeting = meetingsProvider.meetings.firstWhere((m) => m.id == meeting.id);
        } catch (e) {
          currentMeeting = meeting;
        }
        
        // Use the updated agendaUrl from selector
        final finalMeeting = Meeting(
          id: currentMeeting.id,
          title: currentMeeting.title,
          description: currentMeeting.description,
          createdAt: currentMeeting.createdAt,
          agendaUrl: updatedAgendaUrl ?? currentMeeting.agendaUrl,
          meetingDateTime: currentMeeting.meetingDateTime,
        );
        
        final hasAgenda = finalMeeting.agendaUrl != null && finalMeeting.agendaUrl!.isNotEmpty;
        final isMobile = MediaQuery.of(context).size.width < 700;
        
        return _buildMeetingItemContent(context, finalMeeting, hasAgenda, isMobile, isLast);
      },
    );
  }

  Widget _buildMeetingItemContent(BuildContext context, Meeting meeting, bool hasAgenda, bool isMobile, bool isLast) {
    
    return Container(
      margin: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
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
          // Main meeting info row
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, '/meetings/${meeting.id}');
              },
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
                        Icons.event,
                        size: 22,
                        color: Color(0xFF424242),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  meeting.title,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF212121),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_isPastMeeting(meeting)) ...[
                                const SizedBox(width: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF616161),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: const Text(
                                    'Past',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          // Date and Time buttons - only show on mobile (vertically stacked)
                          if (isMobile) ...[
                            const SizedBox(height: 8),
                            _buildDateTimeButtons(context, meeting),
                          ],
                        ],
                      ),
                    ),
                    // Date/Time and Delete buttons - only show on desktop
                    if (!isMobile) ...[
                      // Combined Date & Time button
                      Builder(
                        builder: (context) {
                          final hasDateTime = meeting.meetingDateTime != null;
                          final displayText = hasDateTime
                              ? '${_formatDate(meeting.meetingDateTime!)} • ${_formatTime(meeting.meetingDateTime!)}'
                              : 'Set Date & Time';
                          
                          return GestureDetector(
                            onTap: () => onSetDateTime(context, meeting),
                            child: Container(
                              height: 52,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(color: const Color(0xFFE0E0E0), width: 1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const Icon(Icons.event, size: 16, color: Color(0xFF757575)),
                                  const SizedBox(width: 6),
                                  Text(
                                    displayText,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF757575),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      // Delete button
                      GestureDetector(
                        onTap: () {
                          _showDeleteDialog(context, meeting);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            border: Border.all(
                              color: const Color(0xFFE0E0E0),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 28,
                            color: Color(0xFF757575),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          // Action buttons - mobile uses dropdown, desktop uses horizontal buttons
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              border: Border(
                top: BorderSide(
                  color: const Color(0xFFF5F5F5),
                  width: 1,
                ),
              ),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: isMobile
                ? _buildMobileActions(context, meeting, hasAgenda)
                : _buildDesktopActions(context, meeting, hasAgenda),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileActions(BuildContext context, Meeting meeting, bool hasAgenda) {
    final isUploading = uploadingAgendas[meeting.id] == true;
    
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'upload':
            if (!isUploading) {
              onUploadAgenda(context, meeting.id);
            }
            break;
          case 'view':
            final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
            meetingsProvider.viewAgenda(context, meeting.agendaUrl!);
            break;
          case 'setup':
            onSetupPolls(context, meeting);
            break;
          case 'results':
            onPollResults(context, meeting);
            break;
          case 'delete':
            _showDeleteDialog(context, meeting);
            break;
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                if (isUploading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  const Icon(Icons.more_vert, size: 18, color: Color(0xFF424242)),
                const SizedBox(width: 12),
                Text(
                  isUploading ? 'Uploading...' : 'Meeting Actions',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF424242),
                  ),
                ),
              ],
            ),
            if (!isUploading)
              const Icon(Icons.arrow_drop_down, size: 20, color: Color(0xFF757575)),
          ],
        ),
      ),
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          value: 'upload',
          enabled: !isUploading,
          child: Row(
            children: [
              const Icon(Icons.upload_file, size: 20, color: Color(0xFF424242)),
              const SizedBox(width: 12),
              const Text('Upload Agenda'),
            ],
          ),
        ),
        if (hasAgenda)
          const PopupMenuItem<String>(
            value: 'view',
            child: Row(
              children: [
                Icon(Icons.visibility, size: 20, color: Color(0xFF424242)),
                SizedBox(width: 12),
                Text('View Agenda'),
              ],
            ),
          ),
        const PopupMenuItem<String>(
          value: 'setup',
          child: Row(
            children: [
              Icon(Icons.poll, size: 20, color: Color(0xFF424242)),
              SizedBox(width: 12),
              Text('Setup Polls'),
            ],
          ),
        ),
        const PopupMenuItem<String>(
          value: 'results',
          child: Row(
            children: [
              Icon(Icons.analytics, size: 20, color: Color(0xFF424242)),
              SizedBox(width: 12),
              Text('Poll Results'),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Delete Meeting',
                style: TextStyle(color: Colors.red[700]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showDeleteDialog(BuildContext context, Meeting meeting) {
    showDialog(
      context: context,
      builder: (dialogContext) => _DeleteMeetingDialog(
        meeting: meeting,
        onDelete: () => onDeleteMeeting(context, meeting, meeting.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Meetings Section
        _buildSectionHeader(
          'Meetings',
          'Create and manage your meetings.',
        ),
        const SizedBox(height: 12),
        // Create Meeting button - simple style like logout
        Opacity(
          opacity: (isCreatingMeeting || !isSubscriptionActive) ? 0.5 : 1.0,
          child: TextButton.icon(
            onPressed: (isCreatingMeeting || !isSubscriptionActive) ? null : onCreateMeeting,
            icon: isCreatingMeeting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : (!isSubscriptionActive
                    ? const SizedBox.shrink()
                    : const Icon(
                        Icons.add,
                        size: 18,
                        color: Colors.white,
                      )),
            label: Text(
              isCreatingMeeting
                  ? 'Creating Meeting...'
                  : (!isSubscriptionActive
                      ? 'Create Meeting (Subscription Required)'
                      : 'Create Meeting'),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
            style: TextButton.styleFrom(
              backgroundColor: Colors.grey[800],
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(double.infinity, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        // Existing meetings - show latest 5 only
        if (meetings.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...meetings.take(5).toList().asMap().entries.map((entry) {
            final index = entry.key;
            final meeting = entry.value;
            final isLast = index == (meetings.length > 5 ? 4 : meetings.length - 1);
            return _buildMeetingItem(context, meeting, isLast: isLast);
          }),
        ],
      ],
    );
  }

  Widget _buildDesktopActions(BuildContext context, Meeting meeting, bool hasAgenda) {
    return Row(
      children: [
        // Upload Agenda button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: uploadingAgendas[meeting.id] == true
                ? null
                : () => onUploadAgenda(context, meeting.id),
            icon: uploadingAgendas[meeting.id] == true
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.upload_file, size: 16),
            label: Text(
              uploadingAgendas[meeting.id] == true ? 'Uploading...' : 'Upload Agenda',
              style: const TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF424242),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        if (hasAgenda) ...[
          const SizedBox(width: 8),
          // View Agenda button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {
                final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
                meetingsProvider.viewAgenda(context, meeting.agendaUrl!);
              },
              icon: const Icon(Icons.visibility, size: 16),
              label: const Text(
                'View Agenda',
                style: TextStyle(fontSize: 13),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF424242),
                side: const BorderSide(color: Color(0xFFE0E0E0)),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(width: 8),
        // Setup Polls button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onSetupPolls(context, meeting),
            icon: const Icon(Icons.poll, size: 16),
            label: const Text(
              'Setup Polls',
              style: TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF424242),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Poll Results button
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => onPollResults(context, meeting),
            icon: const Icon(Icons.analytics, size: 16),
            label: const Text(
              'Poll Results',
              style: TextStyle(fontSize: 13),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF424242),
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DeleteMeetingDialog extends StatefulWidget {
  final Meeting meeting;
  final Future<void> Function() onDelete;

  const _DeleteMeetingDialog({
    required this.meeting,
    required this.onDelete,
  });

  @override
  State<_DeleteMeetingDialog> createState() => _DeleteMeetingDialogState();
}

class _DeleteMeetingDialogState extends State<_DeleteMeetingDialog> {
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete Meeting'),
      content: Text(
        'Are you sure you want to delete "${widget.meeting.title}"? This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isDeleting
              ? null
              : () async {
                  setState(() {
                    _isDeleting = true;
                  });

                  try {
                    await widget.onDelete();
                    if (mounted) {
                      Navigator.of(context).pop();
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        _isDeleting = false;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error deleting meeting: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[600],
            foregroundColor: Colors.white,
          ),
          child: _isDeleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Delete'),
        ),
      ],
    );
  }
}

