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
import 'screens/club_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/terms_of_service_screen.dart';
import 'screens/voting_screen.dart';
import 'screens/guest_entry_screen.dart';
import 'screens/agenda_viewer_screen.dart';
import 'screens/login_screen.dart';
import 'screens/sign_up_screen.dart';
import 'screens/role_holders_list_screen.dart';
import 'screens/role_detail_screen.dart';
import 'screens/guest_list_screen.dart';
import 'screens/payment_success_screen.dart';
import 'screens/payment_cancelled_screen.dart';
import 'providers/auth_provider.dart';
import 'providers/manage_meetings_provider.dart';
import 'providers/view_meeting_provider.dart';

// Cache busting version - increment this when making changes that require browser cache clearing
const String appVersion = '1.1.14';

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
          '/base': (context) => const ManageMeetingsScreen(),
          '/privacy': (context) => const PrivacyPolicyScreen(),
          '/terms': (context) => const TermsOfServiceScreen(),
          '/login': (context) => const LoginAuthGate(),
          '/signup': (context) => const SignUpAuthGate(),
          '/guest-list': (context) => const GuestListScreen(),
          '/payment-success': (context) => const PaymentSuccessScreen(),
          '/payment-cancelled': (context) => const PaymentCancelledScreen(),
        },
        onGenerateRoute: (settings) {
          final name = settings.name ?? '';
          
          // Handle voting route: /meetings/{meetingId}/voting
          if (name.contains('/voting')) {
            final parts = name.split('/');
            if (parts.length >= 3 && parts[0] == '' && parts[1] == 'meetings') {
              final meetingId = _convertUrlToMeetingId(parts[2]);
              return MaterialPageRoute(
                builder: (_) => VotingScreen(meetingId: meetingId),
                settings: settings,
              );
            }
          }
          
          // Handle agenda viewer route: /meetings/{meetingId}/agenda
          if (name.contains('/agenda')) {
            final parts = name.split('/');
            if (parts.length >= 3 && parts[0] == '' && parts[1] == 'meetings') {
              final meetingId = _convertUrlToMeetingId(parts[2]);
              return MaterialPageRoute(
                builder: (context) => _AgendaRouteScreen(meetingId: meetingId),
                settings: settings,
              );
            }
          }
          
          // Handle role holders list route: /meetings/{meetingId}/roles
          if (name.contains('/roles') && !name.contains('/roles/')) {
            final parts = name.split('/');
            if (parts.length >= 4 && parts[0] == '' && parts[1] == 'meetings' && parts[3] == 'roles') {
              final meetingId = _convertUrlToMeetingId(parts[2]);
              return MaterialPageRoute(
                builder: (context) => _RoleHoldersListRouteScreen(meetingId: meetingId),
                settings: settings,
              );
            }
          }
          
          // Handle role detail route: /meetings/{meetingId}/roles/{roleName}
          if (name.contains('/roles/')) {
            final parts = name.split('/');
            if (parts.length >= 5 && parts[0] == '' && parts[1] == 'meetings' && parts[3] == 'roles') {
              final meetingId = _convertUrlToMeetingId(parts[2]);
              final urlRoleName = parts[4];
              final roleName = _urlToRoleName(urlRoleName);
              return MaterialPageRoute(
                builder: (context) => _RoleDetailRouteScreen(meetingId: meetingId, roleName: roleName),
                settings: settings,
              );
            }
          }
          
          // Handle guest entry route: /meetings/{meetingId}/guest
          if (name.contains('/guest')) {
            final parts = name.split('/');
            if (parts.length >= 3 && parts[0] == '' && parts[1] == 'meetings') {
              final meetingId = _convertUrlToMeetingId(parts[2]);
              return MaterialPageRoute(
                builder: (_) => GuestEntryScreen(meetingId: meetingId),
                settings: settings,
              );
            }
            // Handle guest entry route: /clubs/{clubCode}/guest
            if (parts.length >= 3 && parts[0] == '' && parts[1] == 'clubs') {
              final clubCode = parts[2];
              return MaterialPageRoute(
                builder: (_) => GuestEntryScreen(clubCode: clubCode),
                settings: settings,
              );
            }
          }
          
          // Handle meeting view route: /meetings/{meetingId}
          if (name.startsWith('/meetings/')) {
            final meetingId = name.substring('/meetings/'.length);
            // Remove /voting or /guest if present
            final cleanMeetingId = meetingId.split('/').first;
            final actualMeetingId = _convertUrlToMeetingId(cleanMeetingId);
            return MaterialPageRoute(
              builder: (_) => ViewMeetingScreen(meetingId: actualMeetingId),
              settings: settings,
            );
          }
          
          // Handle club route: /clubs/{clubCode}
          if (name.startsWith('/clubs/')) {
            final clubCode = name.substring('/clubs/'.length);
            // Check if it's /guest route
            if (clubCode.endsWith('/guest')) {
              final actualClubCode = clubCode.substring(0, clubCode.length - '/guest'.length);
              return MaterialPageRoute(
                builder: (_) => GuestEntryScreen(clubCode: actualClubCode),
                settings: settings,
              );
            }
            return MaterialPageRoute(
              builder: (_) => ClubScreen(clubCode: clubCode),
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
    // Always show HomeScreen - no gating
    return const HomeScreen();
  }
}

// Reverse auth gate for login screen - redirects if already authenticated
class LoginAuthGate extends StatelessWidget {
  const LoginAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Wait for auth state to be resolved
        if (!authProvider.authStateResolved) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If authenticated, redirect to base
        if (authProvider.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/base');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not authenticated, show login screen
        return const LoginScreen();
      },
    );
  }
}

// Reverse auth gate for signup screen - redirects if already authenticated
class SignUpAuthGate extends StatelessWidget {
  const SignUpAuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Wait for auth state to be resolved
        if (!authProvider.authStateResolved) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // If authenticated, redirect to base
        if (authProvider.isLoggedIn) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/base');
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // Not authenticated, show signup screen
        return const SignUpScreen();
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

// Helper function to convert URL format back to role name (proper capitalization)
String _urlToRoleName(String urlRoleName) {
  // Map of known role names for proper capitalization
  const roleNameMap = {
    'toastmaster': 'Toastmaster',
    'general-evaluator': 'General Evaluator',
    'timer': 'Timer',
    'grammarian': 'Grammarian',
    'ah-counter': 'Ah Counter',
    'table-topics-master': 'Table Topics Master',
    'speaker': 'Speaker',
    'evaluator': 'Evaluator',
  };
  
  // Check if we have a mapping for this role
  if (roleNameMap.containsKey(urlRoleName)) {
    return roleNameMap[urlRoleName]!;
  }
  
  // Fallback: convert hyphens to spaces and capitalize words
  final parts = urlRoleName.split('-');
  return parts.map((part) {
    if (part.isEmpty) return '';
    return part[0].toUpperCase() + part.substring(1).toLowerCase();
  }).join(' ');
}

// Simple screen that uses ViewMeetingProvider to get agenda URL and show AgendaViewerScreen
class _AgendaRouteScreen extends StatelessWidget {
  final String meetingId;

  const _AgendaRouteScreen({required this.meetingId});

  @override
  Widget build(BuildContext context) {
    return Consumer<ViewMeetingProvider>(
      builder: (context, provider, child) {
        // Initialize if not already done
        if (provider.meeting == null && !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.initialize(meetingId);
          });
        }

        if (provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.error != null || provider.meeting == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Agenda')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error ?? 'Meeting not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final meeting = provider.meeting!;
        if (meeting.agendaUrl == null || meeting.agendaUrl!.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Agenda')),
            body: const Center(
              child: Text('No agenda available for this meeting'),
            ),
          );
        }

        return AgendaViewerScreen(agendaUrl: meeting.agendaUrl!);
      },
    );
  }
}

// Route screen for role holders list - fetches meeting title
class _RoleHoldersListRouteScreen extends StatelessWidget {
  final String meetingId;

  const _RoleHoldersListRouteScreen({required this.meetingId});

  @override
  Widget build(BuildContext context) {
    return Consumer<ViewMeetingProvider>(
      builder: (context, provider, child) {
        // Initialize if not already done
        if (provider.meeting == null && !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.initialize(meetingId);
          });
        }

        if (provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.error != null || provider.meeting == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Role Holders')),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error ?? 'Meeting not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final meeting = provider.meeting!;
        return RoleHoldersListScreen(
          meetingId: meetingId,
          meetingTitle: meeting.title,
        );
      },
    );
  }
}

// Route screen for role detail - fetches meeting title
class _RoleDetailRouteScreen extends StatelessWidget {
  final String meetingId;
  final String roleName;

  const _RoleDetailRouteScreen({
    required this.meetingId,
    required this.roleName,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ViewMeetingProvider>(
      builder: (context, provider, child) {
        // Initialize if not already done
        if (provider.meeting == null && !provider.isLoading) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            provider.initialize(meetingId);
          });
        }

        if (provider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.error != null || provider.meeting == null) {
          return Scaffold(
            appBar: AppBar(title: Text(roleName)),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error ?? 'Meeting not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            ),
          );
        }

        final meeting = provider.meeting!;
        return RoleDetailScreen(
          meetingId: meetingId,
          meetingTitle: meeting.title,
          roleName: roleName,
        );
      },
    );
  }
}
