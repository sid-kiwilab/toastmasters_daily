import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'dart:html' as html;
import 'firebase_options.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart';
import 'screens/manage_meetings_screen.dart';
import 'screens/view_meeting_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/manage_meetings_provider.dart';
import 'providers/view_meeting_provider.dart';

// Cache busting version - increment this when making changes that require browser cache clearing
const String appVersion = '1.0.12';

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
  
  // NUCLEAR OPTION: Completely disable all caching for Flutter web
  if (kIsWeb) {
    try {
      // 1. Disable service worker completely
      final serviceWorker = html.window.navigator.serviceWorker;
      if (serviceWorker != null) {
        final registrations = await serviceWorker.getRegistrations();
        for (final registration in registrations) {
          await registration.unregister();
        }
        print('🚫 Service workers disabled');
      }
      
      // 2. Clear all caches
      final caches = html.window.caches;
      if (caches != null) {
        final cacheNames = await caches.keys();
        for (final name in cacheNames) {
          await caches.delete(name);
        }
        print('🧹 All caches cleared');
      }
      
      // 3. Disable browser caching headers
      final head = html.window.document.querySelector('head');
      if (head != null) {
        head.appendHtml('''
          <meta http-equiv="Cache-Control" content="no-cache, no-store, must-revalidate, max-age=0">
          <meta http-equiv="Pragma" content="no-cache">
          <meta http-equiv="Expires" content="-1">
        ''');
      }
      
      // 4. Force reload on every navigation
      html.window.addEventListener('beforeunload', (event) {
        html.window.location.reload();
      });
      
      // 5. Disable Flutter's built-in caching
      html.window.addEventListener('load', (event) {
        // Force fresh asset loading
        final links = html.window.document.querySelectorAll('link[rel="stylesheet"]');
        for (final link in links) {
          final href = link.getAttribute('href');
          if (href != null && !href.contains('?')) {
            link.setAttribute('href', '$href?v=${DateTime.now().millisecondsSinceEpoch}');
          }
        }
      });
      
      print('💥 Nuclear cache disabling complete');
      
    } catch (e) {
      print('Nuclear cache disabling error: $e');
    }
  }
  
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
        themeMode: ThemeMode.light,
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
  // Remove any non-digit characters and return the clean meeting ID
  // This should match exactly what's stored in the active_meetings collection
  return urlMeetingId.replaceAll(RegExp(r'[^0-9]'), '');
}
