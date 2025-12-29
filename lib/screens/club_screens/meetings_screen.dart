import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/manage_meetings_provider.dart';
import '../../widgets/meetings_calendar_widget.dart';
import '../../dialogs/create_meeting_dialog.dart';
import '../../screens/club_screens/setup_polls_screen.dart';
import '../../screens/club_screens/poll_results_screen.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  bool _isCreatingMeeting = false;
  Map<String, bool> _uploadingAgendas = {};
  bool _isSubscriptionActive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      meetingsProvider.initialize();
      // Check subscription status
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.currentUser != null) {
        FirebaseFirestore.instance
            .collection('club')
            .doc(authProvider.currentUser!.uid)
            .snapshots()
            .listen((snapshot) {
          if (!mounted) return;
          if (snapshot.exists) {
            final data = snapshot.data()!;
            final subscription = data['subscription'] as String?;
            final trialEndDate = data['trial_end_date'] as Timestamp?;
            final isActive = subscription == 'active' || 
                (trialEndDate != null && trialEndDate.toDate().isAfter(DateTime.now()));
            setState(() {
              _isSubscriptionActive = isActive;
            });
          } else {
            setState(() {
              _isSubscriptionActive = false;
            });
          }
        });
      }
    });
  }

  Future<void> _createMeeting(BuildContext context, String userId, String title, {DateTime? dateTime}) async {
    try {
      if (mounted) {
        setState(() {
          _isCreatingMeeting = true;
        });
      }

      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('create_meeting').call({
        'title': title,
        'creator_id': userId,
      });

      if (mounted) {
        setState(() {
          _isCreatingMeeting = false;
        });
      }

      if (result.data['success']) {
        final meetingData = result.data['meeting'];
        final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
        
        DateTime? createdAt;
        if (meetingData['created_at'] != null) {
          if (meetingData['created_at'] is Timestamp) {
            createdAt = (meetingData['created_at'] as Timestamp).toDate();
          } else if (meetingData['created_at'] is Map) {
            final tsData = meetingData['created_at'] as Map;
            if (tsData['_seconds'] != null) {
              createdAt = DateTime.fromMillisecondsSinceEpoch(
                (tsData['_seconds'] as int) * 1000 + 
                ((tsData['_nanoseconds'] as int?) ?? 0) ~/ 1000000,
              );
            }
          }
        }
        
        final newMeeting = Meeting(
          id: meetingData['id'],
          title: meetingData['title'] ?? title,
          description: 'No description',
          createdAt: createdAt ?? DateTime.now(),
          agendaUrl: null,
          meetingDateTime: dateTime,
        );
        
        meetingsProvider.addMeeting(newMeeting);
        
        // If dateTime was provided, update it immediately
        if (dateTime != null) {
          await meetingsProvider.updateMeetingDateTime(meetingData['id'], dateTime);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meeting created successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to create meeting: ${result.data['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCreatingMeeting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _uploadAgenda(BuildContext context, String meetingId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      
      if (file.extension?.toLowerCase() != 'pdf') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Only PDF files are allowed'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      List<int> bytes;
      if (file.bytes != null) {
        bytes = file.bytes!;
      } else if (file.path != null) {
        final fileData = File(file.path!);
        bytes = await fileData.readAsBytes();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not access file data'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final base64Data = base64Encode(bytes);

      if (mounted) {
        setState(() {
          _uploadingAgendas[meetingId] = true;
        });
      }

      final functions = FirebaseFunctions.instance;
      final result2 = await functions.httpsCallable('upload_agenda').call({
        'meetingId': meetingId,
        'fileData': base64Data,
        'fileName': file.name,
      });

      if (result2.data['success']) {
        final agenda = result2.data['agenda'];
        final agendaUrl = agenda['download_url'] ?? agenda['downloadUrl'];
        
        // Update the meeting in the provider with the new agenda URL
        if (agendaUrl != null && agendaUrl.isNotEmpty) {
          final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
          meetingsProvider.updateMeetingAgenda(meetingId, agendaUrl);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agenda uploaded successfully!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to upload agenda: ${result2.data['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading agenda: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadingAgendas.remove(meetingId);
        });
      }
    }
  }

  void _showSetupPollsDialog(BuildContext context, Meeting meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SetupPollsScreen(
          meetingId: meeting.id,
          meetingTitle: meeting.title,
        ),
      ),
    );
  }

  void _showPollResultsDialog(BuildContext context, Meeting meeting) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PollResultsScreen(
          meetingId: meeting.id,
          meetingTitle: meeting.title,
        ),
      ),
    );
  }

  Future<void> _deleteMeeting(BuildContext context, Meeting meeting, String meetingId) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.currentUser == null) return;

    try {
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('delete_meeting').call({
        'meeting_id': meetingId,
        'creator_id': authProvider.currentUser!.uid,
      });

      if (result.data['success']) {
        final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
        meetingsProvider.removeMeeting(meetingId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Meeting deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete meeting: ${result.data['error']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting meeting: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Meetings'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF212121),
        elevation: 0,
      ),
      body: Consumer<ManageMeetingsProvider>(
        builder: (context, meetingsProvider, child) {
          return Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: MeetingsCalendarWidget(
                      meetings: meetingsProvider.meetings,
                      isCreatingMeeting: _isCreatingMeeting,
                      uploadingAgendas: _uploadingAgendas,
                      isSubscriptionActive: _isSubscriptionActive,
                      onCreateMeetingWithDateTime: (title, dateTime) async {
                        await _createMeeting(context, authProvider.currentUser!.uid, title, dateTime: dateTime);
                      },
                      onCreateMeeting: () {
                        showDialog(
                          context: context,
                          builder: (context) => CreateMeetingDialog(
                            onConfirm: (title) async {
                              await _createMeeting(context, authProvider.currentUser!.uid, title);
                            },
                          ),
                        );
                      },
                      onUploadAgenda: _uploadAgenda,
                      onSetupPolls: _showSetupPollsDialog,
                      onPollResults: _showPollResultsDialog,
                      onDeleteMeeting: _deleteMeeting,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

