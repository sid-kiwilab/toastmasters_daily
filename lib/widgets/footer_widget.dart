import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../dialogs/logout_dialog.dart';
import '../providers/auth_provider.dart';

class FooterWidget extends StatelessWidget {
  const FooterWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.isLoggedIn) {
          return const SizedBox.shrink(); // Don't show footer if not logged in
        }
        
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Center(
            child: TextButton(
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
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[800],
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Logout'),
            ),
          ),
        );
      },
    );
  }
}
