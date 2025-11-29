import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import '../providers/auth_provider.dart';
import '../providers/manage_meetings_provider.dart';
import '../dialogs/create_meeting_dialog.dart';
import '../screens/setup_polls_screen.dart';
import '../screens/poll_results_screen.dart';
import '../widgets/footer_widget.dart';
import '../widgets/meetings_list_widget.dart';
import '../widgets/profile_widget.dart';
import '../widgets/app_info_widget.dart';
import '../widgets/my_club_widget.dart';
import '../widgets/header_widget.dart';

class ManageMeetingsScreen extends StatefulWidget {
  const ManageMeetingsScreen({super.key});

  @override
  State<ManageMeetingsScreen> createState() => _ManageMeetingsScreenState();
}

class _ManageMeetingsScreenState extends State<ManageMeetingsScreen> {
  bool _isCreatingMeeting = false;
  Map<String, bool> _uploadingAgendas = {}; // Track upload state for each meeting
  
  // Subscription status for meetings list
  bool _isSubscriptionActive = false;

  @override
  void initState() {
    super.initState();
    // Initialize the meetings provider when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      meetingsProvider.initialize();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _onSubscriptionStatusChanged(bool isActive) {
    setState(() {
      _isSubscriptionActive = isActive;
    });
  }


  Future<void> _createMeeting(BuildContext context, String userId, String title) async {
    try {
      // Set loading state
      if (mounted) {
        setState(() {
          _isCreatingMeeting = true;
        });
      }

      // Call the Cloud Function
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('create_meeting').call({
        'title': title,
        'creator_id': userId,
      });

      // Clear loading state
      if (mounted) {
        setState(() {
          _isCreatingMeeting = false;
        });
      }

      // Check result
      if (result.data['success']) {
        final meetingData = result.data['meeting'];
        
        // Add new meeting to the top of the list without reloading
        final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
        
        // Convert timestamp from Cloud Function response
        DateTime? createdAt;
        if (meetingData['created_at'] != null) {
          if (meetingData['created_at'] is Timestamp) {
            createdAt = (meetingData['created_at'] as Timestamp).toDate();
          } else if (meetingData['created_at'] is Map) {
            // Handle serialized timestamp from Cloud Function
            final tsData = meetingData['created_at'] as Map;
            if (tsData['_seconds'] != null) {
              createdAt = DateTime.fromMillisecondsSinceEpoch(
                (tsData['_seconds'] as int) * 1000 + 
                ((tsData['_nanoseconds'] as int?) ?? 0) ~/ 1000000,
              );
            }
          }
        }
        
        // Convert the meeting data to a Meeting object
        final newMeeting = Meeting(
          id: meetingData['id'],
          title: meetingData['title'] ?? title,
          description: 'No description',
          createdAt: createdAt ?? DateTime.now(),
          agendaUrl: null,
          meetingDateTime: null,
        );
        
        meetingsProvider.addMeeting(newMeeting);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting created successfully! ID: ${meetingData['id']}'),
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
      // Clear loading state
      if (mounted) {
        setState(() {
          _isCreatingMeeting = false;
        });
      }
      
      if (mounted) {
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
      // Pick PDF file from device
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
        withData: true, // This ensures we get bytes for web compatibility
      );

      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }

      final file = result.files.first;
      
      // Validate file type
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

      // Show loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Processing and uploading PDF...'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Get bytes from file (works on both web and mobile)
      List<int> bytes;
      if (file.bytes != null) {
        // Web: use bytes directly
        bytes = file.bytes!;
      } else if (file.path != null) {
        // Mobile: read from file path
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

      // Convert to base64
      final base64Data = base64Encode(bytes);

      // Set uploading state for the meeting (only when calling Cloud Function)
      if (mounted) {
        setState(() {
          _uploadingAgendas[meetingId] = true;
        });
      }

      // Call the Cloud Function to upload agenda
      final functions = FirebaseFunctions.instance;
      final result2 = await functions.httpsCallable('upload_agenda').call({
        'meetingId': meetingId,
        'fileData': base64Data,
        'fileName': file.name,
      });

      if (result2.data['success']) {
        final agenda = result2.data['agenda'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Agenda uploaded successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        
        print('Agenda uploaded: ${agenda['download_url'] ?? agenda['downloadUrl']}');
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
      // Clear uploading state for the meeting
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
      // Call the Cloud Function
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('delete_meeting').call({
        'meeting_id': meetingId,
        'creator_id': authProvider.currentUser!.uid,
      });

      // Check result
      if (result.data['success']) {
        // Remove meeting from local list without reloading
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
      rethrow; // Re-throw so dialog can handle it
    }
  }


  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Wait for auth state to be resolved before checking
        if (!authProvider.authStateResolved) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Auth gate: redirect to home if not authenticated
        if (!authProvider.isLoggedIn || authProvider.currentUser == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const HeaderWidget(),
                  
                  // Main content
                  Container(
                    constraints: const BoxConstraints(maxWidth: 800),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Consumer<ManageMeetingsProvider>(
                      builder: (context, meetingsProvider, child) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Profile Section
                            ProfileWidget(
                              onSubscriptionStatusChanged: _onSubscriptionStatusChanged,
                            ),
                            const SizedBox(height: 32),
                            
                            // My Club Section
                            const MyClubWidget(),
                            const SizedBox(height: 32),
                            
                            // Meetings Section
                            MeetingsListWidget(
                              meetings: meetingsProvider.meetings,
                              isCreatingMeeting: _isCreatingMeeting,
                              uploadingAgendas: _uploadingAgendas,
                              isSubscriptionActive: _isSubscriptionActive,
                              hasMoreMeetings: meetingsProvider.hasMoreMeetings,
                              isLoadingMore: meetingsProvider.isLoadingMore,
                              onLoadMore: () {
                                meetingsProvider.loadMoreMeetings();
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
                              onSetDateTime: (context, meeting) => _showSetDateTimeDialog(context, meeting),
                            ),
                            const SizedBox(height: 32),
                            
                            // App Info Section
                            const AppInfoWidget(),
                          ],
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  const FooterWidget(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }


  Future<void> _showSetDateTimeDialog(BuildContext context, Meeting meeting) async {
    final now = DateTime.now();
    final existingDateTime = meeting.meetingDateTime ?? now;
    
    // Show date picker first
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: existingDateTime,
      firstDate: existingDateTime.isBefore(now) ? existingDateTime : now,
      lastDate: now.add(const Duration(days: 365)),
    );
    
    if (pickedDate == null) return; // User cancelled
    
    // Show time picker
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(existingDateTime),
    );
    
    if (pickedTime == null) return; // User cancelled
    
    // Combine date and time
    final combinedDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
    
    try {
      final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      await meetingsProvider.updateMeetingDateTime(meeting.id, combinedDateTime);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Meeting date and time updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating meeting datetime: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }



}

