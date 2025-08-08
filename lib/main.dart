import 'package:flutter/material.dart';

// Cache busting version - increment this when making changes that require browser cache clearing
const String appVersion = '1.0.0';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text('Hello World!'),
        ),
      ),
    );
  }
}
