import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/header_widget.dart';
import '../providers/auth_provider.dart';

class ManageMeetingsScreen extends StatelessWidget {
  const ManageMeetingsScreen({super.key});

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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Icon
                    Icon(
                      Icons.meeting_room,
                      size: 80,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 24),
                    
                    // Title
                    Text(
                      'Manage Meetings',
                      style: theme.textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    
                    // Subtitle
                    Text(
                      'Create and manage your Toastmasters meetings',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 48),
                    
                    // Create Meeting Button
                    SizedBox(
                      width: 200,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          // TODO: Implement create meeting functionality
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Create Meeting'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // View Meetings Button
                    SizedBox(
                      width: 200,
                      height: 50,
                      child: OutlinedButton(
                        onPressed: () {
                          // TODO: Implement view meetings functionality
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('View Meetings'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
