import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dialogs/auth_dialog.dart';
import '../providers/auth_provider.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor, // Same as main page background
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (authProvider.isLoggedIn) ...[
                // Show user info and logout button when logged in
                Text(
                  'Welcome, ${authProvider.userName ?? 'User'}!',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () async {
                    await authProvider.logout();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Logged out successfully!')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                  ),
                  child: const Text('Logout'),
                ),
              ] else ...[
                // Show sign up and login buttons when not logged in
                TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AuthDialog(initialTab: 0), // Sign Up tab
                    );
                  },
                  child: const Text('Sign Up'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => const AuthDialog(initialTab: 1), // Login tab
                    );
                  },
                  child: const Text('Login'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
