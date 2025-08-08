import 'package:flutter/material.dart';

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
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.onSurface.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Sign up and login buttons centered
          TextButton(
            onPressed: () {
              // TODO: Add sign up functionality
            },
            child: const Text('Sign Up'),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: () {
              // TODO: Add login functionality
            },
            child: const Text('Login'),
          ),
        ],
      ),
    );
  }
}
