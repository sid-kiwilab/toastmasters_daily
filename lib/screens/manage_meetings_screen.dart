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

class ManageMeetingsScreen extends StatefulWidget {
  const ManageMeetingsScreen({super.key});

  @override
  State<ManageMeetingsScreen> createState() => _ManageMeetingsScreenState();
}

class _ManageMeetingsScreenState extends State<ManageMeetingsScreen> {
  bool _isCreatingMeeting = false;

  @override
  void initState() {
    super.initState();
    // Initialize the meetings provider when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
      meetingsProvider.initialize();
    });
  }

  Future<void> _createMeeting(BuildContext context, String userId) async {
    try {
      // Set loading state
      setState(() {
        _isCreatingMeeting = true;
      });

      // Call the Cloud Function
      final functions = FirebaseFunctions.instance;
      final result = await functions.httpsCallable('createMeeting').call({
        'title': 'New Meeting',
        'creatorId': userId,
      });

      // Clear loading state
      setState(() {
        _isCreatingMeeting = false;
      });

      // Check result
      if (result.data['success']) {
        final meeting = result.data['meeting'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Meeting created successfully! ID: ${meeting['id']}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh the meetings list
        final meetingsProvider = Provider.of<ManageMeetingsProvider>(context, listen: false);
        meetingsProvider.initialize();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create meeting: ${result.data['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Clear loading state
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only PDF files are allowed'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Show loading indicator
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Processing and uploading PDF...'),
          duration: Duration(seconds: 2),
        ),
      );

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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not access file data'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Convert to base64
      final base64Data = base64Encode(bytes);

      // Call the Cloud Function to upload agenda
      final functions = FirebaseFunctions.instance;
      final result2 = await functions.httpsCallable('uploadAgenda').call({
        'meetingId': meetingId,
        'fileData': base64Data,
        'fileName': file.name,
      });

      if (result2.data['success']) {
        final agenda = result2.data['agenda'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Agenda uploaded successfully!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        
        print('Agenda uploaded: ${agenda['downloadUrl']}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload agenda: ${result2.data['error']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error uploading agenda: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                             onPressed: _isCreatingMeeting ? null : () async {
                               await _createMeeting(context, authProvider.currentUser!.uid);
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
                                   return Card(
                                     margin: const EdgeInsets.only(bottom: 12),
                                     child: Padding(
                                       padding: const EdgeInsets.all(16),
                                                                               child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            // Meeting ID row
                                            Row(
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    meeting.id ?? 'Unknown ID',
                                                    style: theme.textTheme.headlineSmall?.copyWith(
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                                
                                                // Copy button
                                                IconButton(
                                                  onPressed: () {
                                                    // Copy meeting ID to clipboard
                                                    final meetingId = meeting.id ?? 'Unknown ID';
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
                                            
                                            // Action buttons row
                                            Row(
                                              children: [
                                                                                                 // Upload Agenda button
                                                 Expanded(
                                                   child: ElevatedButton.icon(
                                                     onPressed: () {
                                                       _uploadAgenda(context, meeting.id ?? '');
                                                     },
                                                     icon: const Icon(Icons.upload_file, size: 18),
                                                     label: const Text('Upload Agenda'),
                                                     style: ElevatedButton.styleFrom(
                                                       backgroundColor: theme.colorScheme.secondary,
                                                       foregroundColor: Colors.white,
                                                       padding: const EdgeInsets.symmetric(vertical: 8),
                                                     ),
                                                   ),
                                                 ),
                                                
                                                const SizedBox(width: 12),
                                                
                                                // Setup Polls button
                                                Expanded(
                                                  child: ElevatedButton.icon(
                                                    onPressed: () {
                                                      // TODO: Implement polls setup functionality
                                                    },
                                                    icon: const Icon(Icons.poll, size: 18),
                                                    label: const Text('Setup Polls'),
                                                    style: ElevatedButton.styleFrom(
                                                      backgroundColor: theme.colorScheme.tertiary,
                                                      foregroundColor: Colors.white,
                                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
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
