import 'package:flutter/material.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart';

// Cache busting version - increment this when making changes that require browser cache clearing
const String appVersion = '1.0.0';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Toastmasters Daily',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system, // Automatically switch between light and dark
      home: const HomeScreen(),
    );
  }
}
