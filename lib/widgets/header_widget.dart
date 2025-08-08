import 'package:flutter/material.dart';
import '../dialogs/auth_dialog.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Same as main page background
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sign up and login buttons centered
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
      ),
    );
  }
}
