import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dialogs/auth_dialog.dart';
import '../dialogs/logout_dialog.dart';
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
                // Show logout button when logged in
                ElevatedButton(
                  onPressed: () async {
                    // Show logout confirmation dialog
                    final shouldLogout = await showDialog<bool>(
                      context: context,
                      builder: (context) => const LogoutDialog(),
                    );
                    
                    // If user confirmed logout, proceed with logout
                    if (shouldLogout == true && context.mounted) {
                      await authProvider.logout();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Logged out successfully!')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Logout'),
                ),
              ] else ...[
                // Show "Want to create a meeting?" text and login button when not logged in
                Text(
                  'Want to create a meeting?',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
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
