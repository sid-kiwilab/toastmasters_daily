import 'package:flutter/material.dart';

enum NotificationType { success, error, info }

class NotificationSnackbarWidget {
  // Global Key for the ScaffoldMessenger
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static bool _isSnackbarVisible = false; // Track visibility

  static void show(
    String message, {
    required NotificationType type,
  }) {
    final scaffoldMessengerState = scaffoldMessengerKey.currentState;

    if (scaffoldMessengerState != null && !_isSnackbarVisible) {
      _isSnackbarVisible = true; // Mark as visible

      scaffoldMessengerState.showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontFamily: 'OldschoolGrotesk',
            ),
          ),
          backgroundColor: _getBackgroundColor(type),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      ).closed.then((_) {
        _isSnackbarVisible = false; // Reset flag when snackbar disappears
      });
    }
  }

  static Color _getBackgroundColor(NotificationType type) {
    switch (type) {
      case NotificationType.success:
        return Colors.green;
      case NotificationType.error:
        return Colors.red;
      case NotificationType.info:
        return Colors.grey[800]!;
    }
  }
}
