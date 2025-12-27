import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:provider/provider.dart';
import '../providers/manage_meetings_provider.dart';

class MeetingsCalendarWidget extends StatefulWidget {
  final List<Meeting> meetings;
  final bool isCreatingMeeting;
  final Map<String, bool> uploadingAgendas;
  final bool isSubscriptionActive;
  final Future<void> Function(String title, DateTime? dateTime)? onCreateMeetingWithDateTime;
  final VoidCallback onCreateMeeting;
  final Future<void> Function(BuildContext, String) onUploadAgenda;
  final void Function(BuildContext, Meeting) onSetupPolls;
  final void Function(BuildContext, Meeting) onPollResults;
  final Future<void> Function(BuildContext, Meeting, String) onDeleteMeeting;
  const MeetingsCalendarWidget({
    super.key,
    required this.meetings,
    required this.isCreatingMeeting,
    required this.uploadingAgendas,
    required this.isSubscriptionActive,
    this.onCreateMeetingWithDateTime,
    required this.onCreateMeeting,
    required this.onUploadAgenda,
    required this.onSetupPolls,
    required this.onPollResults,
    required this.onDeleteMeeting,
  });

  @override
  State<MeetingsCalendarWidget> createState() => _MeetingsCalendarWidgetState();
}

class _MeetingsCalendarWidgetState extends State<MeetingsCalendarWidget> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  // Get meetings for a specific day
  List<Meeting> _getMeetingsForDay(DateTime day) {
    return widget.meetings.where((meeting) {
      if (meeting.meetingDateTime == null) return false;
      final meetingDate = meeting.meetingDateTime!;
      return meetingDate.year == day.year &&
          meetingDate.month == day.month &&
          meetingDate.day == day.day;
    }).toList();
  }

  // Get all days that have meetings
  Set<DateTime> _getMeetingDays() {
    final days = <DateTime>{};
    for (final meeting in widget.meetings) {
      if (meeting.meetingDateTime != null) {
        final date = meeting.meetingDateTime!;
        days.add(DateTime(date.year, date.month, date.day));
      }
    }
    return days;
  }

  String _formatTime(DateTime time) {
    final hour = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Future<void> _createMeetingForDate(DateTime date) async {
    // Show dialog to create meeting with title and time
    final titleController = TextEditingController();
    TimeOfDay? selectedTime;
    bool isCreating = false;
    
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Create Meeting - ${_formatDate(date)}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  enabled: !isCreating,
                  decoration: const InputDecoration(
                    labelText: 'Meeting Title',
                    border: OutlineInputBorder(),
                  ),
                  autofocus: true,
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: isCreating ? null : () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setDialogState(() {
                        selectedTime = time;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.access_time, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          selectedTime == null
                              ? 'Select Time'
                              : selectedTime!.format(context),
                          style: TextStyle(
                            color: selectedTime == null ? Colors.grey : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isCreating ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: (isCreating || titleController.text.trim().isEmpty || selectedTime == null)
                  ? null
                  : () async {
                      setDialogState(() {
                        isCreating = true;
                      });
                      
                      // Create meeting with date and time
                      final combinedDateTime = DateTime(
                        date.year,
                        date.month,
                        date.day,
                        selectedTime!.hour,
                        selectedTime!.minute,
                      );
                      
                      try {
                        // Call the create meeting function with date/time if available
                        if (widget.onCreateMeetingWithDateTime != null) {
                          await widget.onCreateMeetingWithDateTime!(titleController.text.trim(), combinedDateTime);
                        } else {
                          // Fallback to regular create flow
                          widget.onCreateMeeting();
                        }
                        
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e) {
                        setDialogState(() {
                          isCreating = false;
                        });
                      }
                    },
              child: isCreating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final meetingDays = _getMeetingDays();
    final selectedDayMeetings = _getMeetingsForDay(_selectedDay);
    
    return Column(
      children: [
        // Calendar
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: TableCalendar<Meeting>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: _calendarFormat,
            startingDayOfWeek: StartingDayOfWeek.monday,
            calendarStyle: CalendarStyle(
              outsideDaysVisible: false,
              weekendTextStyle: const TextStyle(color: Color(0xFF757575)),
              selectedDecoration: BoxDecoration(
                color: const Color(0xFF424242),
                shape: BoxShape.circle,
              ),
              todayDecoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                shape: BoxShape.circle,
              ),
              markerDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
            calendarBuilders: CalendarBuilders(
              defaultBuilder: (context, date, events) {
                final hasMeetings = meetingDays.contains(DateTime(date.year, date.month, date.day));
                final isToday = isSameDay(date, DateTime.now());
                final isSelected = isSameDay(date, _selectedDay);
                
                if (hasMeetings && !isSelected && !isToday) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue[300]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
              todayBuilder: (context, date, events) {
                final hasMeetings = meetingDays.contains(DateTime(date.year, date.month, date.day));
                
                if (hasMeetings) {
                  return Container(
                    margin: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.blue[400]!,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
              selectedBuilder: (context, date, events) {
                final hasMeetings = meetingDays.contains(DateTime(date.year, date.month, date.day));
                
                return Container(
                  margin: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: hasMeetings ? Colors.blue[700] : const Color(0xFF424242),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: hasMeetings ? Colors.blue[900]! : const Color(0xFF212121),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                );
              },
              markerBuilder: (context, date, events) {
                if (meetingDays.contains(DateTime(date.year, date.month, date.day))) {
                  return Positioned(
                    bottom: 2,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.blue[700],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  );
                }
                return null;
              },
            ),
            headerStyle: HeaderStyle(
              formatButtonVisible: true,
              titleCentered: true,
              formatButtonShowsNext: false,
              formatButtonDecoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              formatButtonTextStyle: const TextStyle(
                color: Color(0xFF212121),
                fontSize: 12,
              ),
            ),
            eventLoader: _getMeetingsForDay,
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Selected day meetings
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE0E0E0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(_selectedDay),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF212121),
                      ),
                    ),
                    if (widget.isSubscriptionActive)
                      IconButton(
                        icon: const Icon(Icons.add, color: Color(0xFF424242)),
                        onPressed: widget.isCreatingMeeting ? null : () {
                          _createMeetingForDate(_selectedDay);
                        },
                        tooltip: 'Create Meeting',
                      ),
                  ],
                ),
              ),
              if (selectedDayMeetings.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.event_outlined,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No meetings scheduled',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...selectedDayMeetings.map((meeting) => _buildMeetingItem(meeting)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMeetingItem(Meeting meeting) {
    // Use Selector to rebuild when agendaUrl changes
    return Selector<ManageMeetingsProvider, String?>(
      selector: (context, provider) {
        final updatedMeeting = provider.meetings.firstWhere(
          (m) => m.id == meeting.id,
          orElse: () => meeting,
        );
        return updatedMeeting.agendaUrl;
      },
      builder: (context, updatedAgendaUrl, child) {
        final currentMeeting = widget.meetings.firstWhere(
          (m) => m.id == meeting.id,
          orElse: () => meeting,
        );
        
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
        final isUploading = widget.uploadingAgendas[finalMeeting.id] == true;
        
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFAFAFA),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Flexible(
                              child: Text(
                                finalMeeting.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF212121),
                                ),
                              ),
                            ),
                            if (isUploading) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.blue[200]!,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Uploading',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (finalMeeting.meetingDateTime != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            _formatTime(finalMeeting.meetingDateTime!),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: isUploading ? null : () {
                      Navigator.pushNamed(context, '/meetings/${finalMeeting.id}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF424242),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      minimumSize: const Size(0, 36),
                    ),
                    child: const Text('View'),
                  ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, size: 20, color: Color(0xFF757575)),
                onSelected: (value) {
                  switch (value) {
                    case 'upload':
                      if (!isUploading) {
                        widget.onUploadAgenda(context, finalMeeting.id);
                      }
                      break;
                    case 'view':
                      final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
                      meetingsProvider.viewAgenda(context, finalMeeting.agendaUrl!);
                      break;
                    case 'setup':
                      widget.onSetupPolls(context, finalMeeting);
                      break;
                    case 'results':
                      widget.onPollResults(context, finalMeeting);
                      break;
                    case 'delete':
                      _showDeleteDialog(context, finalMeeting);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'upload',
                    enabled: !isUploading,
                    child: Row(
                      children: [
                        if (isUploading)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          const Icon(Icons.upload_file, size: 18, color: Color(0xFF424242)),
                        const SizedBox(width: 12),
                        Text(isUploading ? 'Uploading...' : 'Upload Agenda'),
                      ],
                    ),
                  ),
                  if (hasAgenda)
                    const PopupMenuItem<String>(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.visibility, size: 18, color: Color(0xFF424242)),
                          SizedBox(width: 12),
                          Text('View Agenda'),
                        ],
                      ),

                    ),
                  const PopupMenuItem<String>(
                    value: 'setup',
                    child: Row(
                      children: [
                        Icon(Icons.poll, size: 18, color: Color(0xFF424242)),
                        SizedBox(width: 12),
                        Text('Setup Polls'),
                      ],
                    ),

                  ),
                  const PopupMenuItem<String>(
                    value: 'results',
                    child: Row(
                      children: [
                        Icon(Icons.analytics, size: 18, color: Color(0xFF424242)),
                        SizedBox(width: 12),
                        Text('Poll Results'),
                      ],
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        SizedBox(width: 12),
                        Text(
                          'Delete Meeting',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, Meeting meeting) {
    bool isDeleting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Delete Meeting'),
          content: Text('Are you sure you want to delete "${meeting.title}"?'),
          actions: [
            TextButton(
              onPressed: isDeleting ? null : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isDeleting
                  ? null
                  : () async {
                      setDialogState(() {
                        isDeleting = true;
                      });
                      
                      try {
                        await widget.onDeleteMeeting(context, meeting, meeting.id);
                        
                        if (dialogContext.mounted) {
                          Navigator.of(dialogContext).pop();
                        }
                      } catch (e) {
                        setDialogState(() {
                          isDeleting = false;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                foregroundColor: Colors.white,
              ),
              child: isDeleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }
}



