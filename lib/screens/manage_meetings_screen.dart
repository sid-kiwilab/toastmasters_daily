import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../widgets/header_widget.dart';
import '../widgets/footer_widget.dart';
import '../providers/auth_provider.dart';
import '../providers/manage_meetings_provider.dart';
import '../dialogs/create_meeting_dialog.dart';
import '../screens/setup_polls_screen.dart';
import '../dialogs/poll_results_dialog.dart';
import '../dialogs/qr_code_dialog.dart';

class ManageMeetingsScreen extends StatefulWidget {
  const ManageMeetingsScreen({super.key});

  @override
  State<ManageMeetingsScreen> createState() => _ManageMeetingsScreenState();
}

class _ManageMeetingsScreenState extends State<ManageMeetingsScreen> {
  bool _isCreatingMeeting = false;
  Map<String, bool> _uploadingAgendas = {}; // Track upload state for each meeting

  @override
  void initState() {
    super.initState();
    // Initialize the meetings provider when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      meetingsProvider.initialize();
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
        final meeting = result.data['meeting'];
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Meeting created successfully! ID: ${meeting['id']}'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        // Refresh the meetings list
        final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
        meetingsProvider.initialize();
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
    showDialog(
      context: context,
      builder: (context) => PollResultsDialog(
        meetingId: meeting.id,
        meetingTitle: meeting.title,
      ),
    );
  }

  void _showQRCodeDialog(BuildContext context, Meeting meeting) {
    showDialog(
      context: context,
      builder: (context) => QRCodeDialog(
        meetingId: meeting.id,
        meetingTitle: meeting.title,
      ),
    );
  }

  // Helper method to format meeting ID with space for display
  String _formatMeetingId(String meetingId) {
    if (meetingId == 'Unknown ID') return meetingId;
    
    // Remove any existing spaces and non-digit characters
    final digits = meetingId.replaceAll(RegExp(r'[^0-9]'), '');
    
    // If it's 8 digits, add space in the middle
    if (digits.length == 8) {
      return '${digits.substring(0, 4)} ${digits.substring(4)}';
    }
    
    // Return original if not 8 digits
    return meetingId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
         return Scaffold(
       body: SafeArea(
         child: Column(
           children: [
             // Header at the top
             const HeaderWidget(),
             
             // Main content
             Expanded(
               child: Consumer<AuthProvider>(
                 builder: (context, authProvider, child) {
                   if (authProvider.currentUser == null) {
                     return const SizedBox.shrink();
                   }
                   
                   return Center(
                     child: SingleChildScrollView(
                       padding: const EdgeInsets.all(24),
                       child: Column(
                         mainAxisAlignment: MainAxisAlignment.center,
                         crossAxisAlignment: CrossAxisAlignment.center,
                         children: [
                           // Create Meeting Button
                           ElevatedButton(
                             onPressed: _isCreatingMeeting ? null : () {
                               showDialog(
                                 context: context,
                                 builder: (context) => CreateMeetingDialog(
                                   onConfirm: (title) async {
                                     await _createMeeting(context, authProvider.currentUser!.uid, title);
                                   },
                                 ),
                               );
                             },
                             style: ElevatedButton.styleFrom(
                               backgroundColor: theme.colorScheme.primary,
                               foregroundColor: Colors.white,
                               padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                             ),
                             child: _isCreatingMeeting
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
                           const SizedBox(height: 32),
                           
                           // Meetings list using the provider
                           Consumer<ManageMeetingsProvider>(
                             builder: (context, meetingsProvider, child) {
                               if (meetingsProvider.isLoading) {
                                 return const Center(
                                   child: CircularProgressIndicator(),
                                 );
                               }
                               
                               if (meetingsProvider.error != null) {
                                 return Center(
                                   child: Column(
                                     children: [
                                       Icon(
                                         Icons.error_outline,
                                         size: 64,
                                         color: theme.colorScheme.error,
                                       ),
                                       const SizedBox(height: 16),
                                       Text(
                                         'Unable to load meetings',
                                         style: theme.textTheme.titleMedium?.copyWith(
                                           color: theme.colorScheme.error,
                                         ),
                                         textAlign: TextAlign.center,
                                       ),
                                       const SizedBox(height: 8),
                                       Text(
                                         meetingsProvider.error!,
                                         style: theme.textTheme.bodyMedium?.copyWith(
                                           color: theme.colorScheme.onSurfaceVariant,
                                         ),
                                         textAlign: TextAlign.center,
                                       ),
                                     ],
                                   ),
                                 );
                               }
                               
                               if (meetingsProvider.meetings.isEmpty) {
                                 return Text(
                                   'You have no upcoming meetings',
                                   style: theme.textTheme.titleMedium?.copyWith(
                                     color: theme.colorScheme.onSurfaceVariant,
                                   ),
                                   textAlign: TextAlign.center,
                                 );
                               }
                               
                                                                                             // Display meetings list
                               return Column(
                                 children: meetingsProvider.meetings.map((meeting) {
                                   return Center(
                                     child: ConstrainedBox(
                                       constraints: const BoxConstraints(maxWidth: 1000),
                                       child: Card(
                                         margin: const EdgeInsets.only(bottom: 12),
                                         shape: RoundedRectangleBorder(
                                           borderRadius: BorderRadius.circular(8),
                                           side: const BorderSide(color: Colors.purple, width: 2),
                                         ),
                                         child: Padding(
                                           padding: const EdgeInsets.all(16),
                                           child: Column(
                                             crossAxisAlignment: CrossAxisAlignment.start,
                                             children: [
                                               // Meeting ID and Title row
                                               Row(
                                                 children: [
                                                   // Meeting ID
                                                   Text(
                                                     _formatMeetingId(meeting.id),
                                                     style: theme.textTheme.headlineSmall?.copyWith(
                                                       fontWeight: FontWeight.bold,
                                                     ),
                                                   ),
                                                   
                                                   const SizedBox(width: 16),
                                                   
                                                   // Meeting Title
                                                   Expanded(
                                                     child: GestureDetector(
                                                       onTap: () {
                                                         final urlMeetingId = meeting.id.replaceAll(' ', '');
                                                         Navigator.pushNamed(context, '/meetings/$urlMeetingId');
                                                       },
                                                       child: Text(
                                                         meeting.title,
                                                         style: theme.textTheme.titleMedium?.copyWith(
                                                           color: theme.colorScheme.primary,
                                                           decoration: TextDecoration.underline,
                                                         ),
                                                       ),
                                                     ),
                                                   ),
                                                   
                                                   // Copy button
                                                   IconButton(
                                                     onPressed: () {
                                                       // Copy meeting ID to clipboard
                                                       final meetingId = meeting.id;
                                                       Clipboard.setData(ClipboardData(text: meetingId));
                                                       ScaffoldMessenger.of(context).showSnackBar(
                                                         SnackBar(
                                                           content: Text('Meeting ID copied to clipboard'),
                                                           duration: const Duration(seconds: 2),
                                                         ),
                                                       );
                                                     },
                                                     icon: Icon(
                                                       Icons.copy,
                                                       color: theme.colorScheme.primary,
                                                       size: 18,
                                                     ),
                                                     tooltip: 'Copy Meeting ID',
                                                     constraints: const BoxConstraints(
                                                       minWidth: 32,
                                                       minHeight: 32,
                                                     ),
                                                   ),
                                                 ],
                                               ),
                                               
                                               const SizedBox(height: 16),
                                               
                                               // Action buttons - responsive layout
                                               LayoutBuilder(
                                                 builder: (context, constraints) {
                                                   // Check if we have enough width for side-by-side layout
                                                   final hasViewAgenda = meeting.agendaUrl != null && meeting.agendaUrl!.isNotEmpty;
                                                   final useSideBySide = constraints.maxWidth >= 800; // Switch to mobile view at 800px instead of calculating
                                                   
                                                   if (useSideBySide) {
                                                     // Side by side layout
                                                     return Row(
                                                       children: [
                                                         // Upload Agenda button
                                                         Expanded(
                                                           child: ElevatedButton.icon(
                                                             onPressed: _uploadingAgendas[meeting.id] == true
                                                                 ? null
                                                                 : () {
                                                                     _uploadAgenda(context, meeting.id);
                                                                   },
                                                             icon: _uploadingAgendas[meeting.id] == true
                                                                 ? const SizedBox(
                                                                     width: 20,
                                                                     height: 20,
                                                                   )
                                                                 : const Icon(Icons.upload_file, size: 18),
                                                             label: _uploadingAgendas[meeting.id] == true
                                                                 ? const Text('Uploading...')
                                                                 : const Text('Upload Agenda'),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: theme.colorScheme.primary,
                                                               foregroundColor: Colors.white,
                                                               padding: const EdgeInsets.symmetric(vertical: 8),
                                                               elevation: 2,
                                                             ),
                                                           ),
                                                         ),
                                                         
                                                         const SizedBox(width: 12),
                                                         
                                                         // View Agenda button (only show if agendaUrl exists)
                                                         if (hasViewAgenda) ...[
                                                           Expanded(
                                                             child: ElevatedButton.icon(
                                                               onPressed: () {
                                                                 // Use the provider to view agenda
                                                                 final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
                                                                 meetingsProvider.viewAgenda(context, meeting.agendaUrl!);
                                                               },
                                                               icon: const Icon(Icons.visibility, size: 18),
                                                               label: const Text('View Agenda'),
                                                               style: ElevatedButton.styleFrom(
                                                                 backgroundColor: theme.colorScheme.primary,
                                                                 foregroundColor: Colors.white,
                                                                 padding: const EdgeInsets.symmetric(vertical: 8),
                                                                 elevation: 2,
                                                               ),
                                                             ),
                                                           ),
                                                           const SizedBox(width: 12),
                                                         ],
                                                         
                                                         // Setup Polls button
                                                         Expanded(
                                                           child: ElevatedButton.icon(
                                                             onPressed: () {
                                                               _showSetupPollsDialog(context, meeting);
                                                             },
                                                             icon: const Icon(Icons.poll, size: 18),
                                                             label: const Text('Setup Polls'),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: theme.colorScheme.primary,
                                                               foregroundColor: Colors.white,
                                                               padding: const EdgeInsets.symmetric(vertical: 8),
                                                               elevation: 2,
                                                             ),
                                                           ),
                                                         ),
                                                         const SizedBox(width: 12),
                                                         // Poll Results button
                                                         Expanded(
                                                           child: ElevatedButton.icon(
                                                             onPressed: () {
                                                               _showPollResultsDialog(context, meeting);
                                                             },
                                                             icon: const Icon(Icons.analytics, size: 18),
                                                             label: const Text('Poll Results'),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: theme.colorScheme.secondary,
                                                               foregroundColor: Colors.white,
                                                               padding: const EdgeInsets.symmetric(vertical: 8),
                                                               elevation: 2,
                                                             ),
                                                           ),
                                                         ),
                                                         
                                                         const SizedBox(width: 12),
                                                         
                                                         // QR Code button
                                                         Expanded(
                                                           child: ElevatedButton.icon(
                                                             onPressed: () {
                                                               _showQRCodeDialog(context, meeting);
                                                             },
                                                             icon: const Icon(Icons.qr_code, size: 18),
                                                             label: const Text('QR Code'),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: theme.colorScheme.tertiary,
                                                               foregroundColor: Colors.white,
                                                               padding: const EdgeInsets.symmetric(vertical: 8),
                                                               elevation: 2,
                                                             ),
                                                           ),
                                                         ),
                                                       ],
                                                     );
                                                   } else {
                                                     // Stacked layout for small screens
                                                     return Column(
                                                       children: [
                                                         // Upload Agenda button
                                                         SizedBox(
                                                           width: double.infinity,
                                                           child: ElevatedButton.icon(
                                                             onPressed: _uploadingAgendas[meeting.id] == true
                                                                 ? null
                                                                 : () {
                                                                     _uploadAgenda(context, meeting.id);
                                                                   },
                                                             icon: _uploadingAgendas[meeting.id] == true
                                                                 ? const SizedBox(
                                                                     width: 20,
                                                                     height: 20,
                                                                   )
                                                                 : const Icon(Icons.upload_file, size: 18),
                                                             label: _uploadingAgendas[meeting.id] == true
                                                                 ? const Text('Uploading...')
                                                                 : const Text('Upload Agenda'),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: theme.colorScheme.primary,
                                                               foregroundColor: Colors.white,
                                                               padding: const EdgeInsets.symmetric(vertical: 8),
                                                               elevation: 2,
                                                             ),
                                                           ),
                                                         ),
                                                         
                                                         if (hasViewAgenda) ...[
                                                           const SizedBox(height: 12),
                                                           // View Agenda button
                                                           SizedBox(
                                                             width: double.infinity,
                                                             child: ElevatedButton.icon(
                                                               onPressed: () {
                                                                 // Use the provider to view agenda
                                                                 final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
                                                                 meetingsProvider.viewAgenda(context, meeting.agendaUrl!);
                                                               },
                                                               icon: const Icon(Icons.visibility, size: 18),
                                                               label: const Text('View Agenda'),
                                                               style: ElevatedButton.styleFrom(
                                                                 backgroundColor: theme.colorScheme.primary,
                                                                 foregroundColor: Colors.white,
                                                                 padding: const EdgeInsets.symmetric(vertical: 8),
                                                                 elevation: 2,
                                                               ),
                                                             ),
                                                           ),
                                                         ],
                                                         
                                                         const SizedBox(height: 12),
                                                         
                                                         // Setup Polls button
                                                         SizedBox(
                                                           width: double.infinity,
                                                           child: ElevatedButton.icon(
                                                             onPressed: () {
                                                               _showSetupPollsDialog(context, meeting);
                                                             },
                                                             icon: const Icon(Icons.poll, size: 18),
                                                             label: const Text('Setup Polls'),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: theme.colorScheme.primary,
                                                               foregroundColor: Colors.white,
                                                               padding: const EdgeInsets.symmetric(vertical: 8),
                                                               elevation: 2,
                                                             ),
                                                           ),
                                                         ),
                                                         
                                                         const SizedBox(height: 12),
                                                         
                                                         // Poll Results button
                                                         SizedBox(
                                                           width: double.infinity,
                                                           child: ElevatedButton.icon(
                                                             onPressed: () {
                                                               _showPollResultsDialog(context, meeting);
                                                             },
                                                             icon: const Icon(Icons.analytics, size: 18),
                                                             label: const Text('Poll Results'),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: theme.colorScheme.secondary,
                                                               foregroundColor: Colors.white,
                                                               padding: const EdgeInsets.symmetric(vertical: 8),
                                                               elevation: 2,
                                                             ),
                                                           ),
                                                         ),
                                                         
                                                         const SizedBox(height: 12),
                                                         
                                                         // QR Code button
                                                         SizedBox(
                                                           width: double.infinity,
                                                           child: ElevatedButton.icon(
                                                             onPressed: () {
                                                               _showQRCodeDialog(context, meeting);
                                                             },
                                                             icon: const Icon(Icons.qr_code, size: 18),
                                                             label: const Text('QR Code'),
                                                             style: ElevatedButton.styleFrom(
                                                               backgroundColor: theme.colorScheme.tertiary,
                                                               foregroundColor: Colors.white,
                                                               padding: const EdgeInsets.symmetric(vertical: 8),
                                                               elevation: 2,
                                                             ),
                                                           ),
                                                         ),
                                                       ],
                                                     );
                                                   }
                                                 },
                                               ),
                                             ],
                                           ),
                                         ),
                                       ),
                                     ),
                                   );
                                 }).toList(),
                               );
                             },
                           ),
                         ],
                       ),
                     ),
                   );
                 },
               ),
             ),
             
             // Footer at the bottom
             const FooterWidget(),
           ],
         ),
       ),
     );
  }
}
