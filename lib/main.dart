import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'firebase_options.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart';
import 'screens/manage_meetings_screen.dart';
import 'screens/view_meeting_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/manage_meetings_provider.dart';
import 'providers/view_meeting_provider.dart';

// Cache busting version - increment this when making changes that require browser cache clearing
const String appVersion = '1.0.0';

// Custom page transitions builder that removes all animations
class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();

  @override
  Widget buildTransitions<T extends Object?>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return child;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set URL strategy for web
  setUrlStrategy(PathUrlStrategy());
  
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (context) => ManageMeetingsProvider()),
        ChangeNotifierProvider(create: (context) => ViewMeetingProvider()),
      ],
      child: MaterialApp(
        title: 'Toastmasters Daily',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: NoTransitionsBuilder(),
              TargetPlatform.iOS: NoTransitionsBuilder(),
              TargetPlatform.linux: NoTransitionsBuilder(),
              TargetPlatform.macOS: NoTransitionsBuilder(),
              TargetPlatform.windows: NoTransitionsBuilder(),
            },
          ),
        ),
        darkTheme: AppTheme.darkTheme.copyWith(
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: NoTransitionsBuilder(),
              TargetPlatform.iOS: NoTransitionsBuilder(),
              TargetPlatform.linux: NoTransitionsBuilder(),
              TargetPlatform.macOS: NoTransitionsBuilder(),
              TargetPlatform.windows: NoTransitionsBuilder(),
            },
          ),
        ),
        themeMode: ThemeMode.system,
        initialRoute: '/',
        routes: {
          '/': (context) => const AuthWrapper(),
        },
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';
          if (name.startsWith('/meetings/')) {
            final meetingId = name.substring('/meetings/'.length);
            final actualMeetingId = _convertUrlToMeetingId(meetingId);
            return MaterialPageRoute(
              builder: (_) => ViewMeetingScreen(meetingId: actualMeetingId),
              settings: settings,
            );
          }
          return null;
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Show ManageMeetingsScreen if logged in, otherwise show HomeScreen
        if (authProvider.isLoggedIn) {
          return const ManageMeetingsScreen();
        } else {
          return const HomeScreen();
        }
      },
    );
  }
}

// Helper function to convert URL meeting ID to actual meeting ID
String _convertUrlToMeetingId(String urlMeetingId) {
  // Remove any non-digit characters first
  final digits = urlMeetingId.replaceAll(RegExp(r'[^0-9]'), '');
  
  // If it's 8 digits, add space in the middle
  if (digits.length == 8) {
    return '${digits.substring(0, 4)} ${digits.substring(4)}';
  }
  
  // If it's already in the correct format (with space), return as is
  if (urlMeetingId.contains(' ')) {
    return urlMeetingId;
  }
  
  // Fallback: return original if conversion not possible
  return urlMeetingId;
}
