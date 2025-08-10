import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_functions/cloud_functions.dart';
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
                                     child: ListTile(
                                       leading: Icon(
                                         Icons.event,
                                         color: theme.colorScheme.primary,
                                       ),
                                       title: Text(
                                         meeting.title,
                                         style: const TextStyle(fontWeight: FontWeight.w500),
                                       ),
                                       subtitle: Text(
                                         meeting.description,
                                         maxLines: 2,
                                         overflow: TextOverflow.ellipsis,
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
