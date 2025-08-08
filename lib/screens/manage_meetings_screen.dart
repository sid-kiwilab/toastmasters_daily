import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/header_widget.dart';
import '../providers/auth_provider.dart';
import '../providers/manage_meetings_provider.dart';

class ManageMeetingsScreen extends StatefulWidget {
  const ManageMeetingsScreen({super.key});

  @override
  State<ManageMeetingsScreen> createState() => _ManageMeetingsScreenState();
}

class _ManageMeetingsScreenState extends State<ManageMeetingsScreen> {
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    if (authProvider.currentUser == null) {
                      return const SizedBox.shrink();
                    }
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          'Upcoming Meetings',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 24),
                        
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
                              return Center(
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.event_busy,
                                      size: 64,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'You have no upcoming meetings',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
