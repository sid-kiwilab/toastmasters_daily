import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/manage_meetings_provider.dart';
import '../../widgets/footer_widget.dart';
import '../../widgets/app_info_widget.dart';
import '../../widgets/header_widget.dart';

class MemberBaseScreen extends StatefulWidget {
  const MemberBaseScreen({super.key});

  @override
  State<MemberBaseScreen> createState() => _MemberBaseScreenState();
}

class _MemberBaseScreenState extends State<MemberBaseScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Wait for auth state to be resolved before checking
        if (!authProvider.authStateResolved) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        // Auth gate: redirect to home if not authenticated
        if (!authProvider.isLoggedIn || authProvider.currentUser == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        return Scaffold(
          body: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const HeaderWidget(),
                  // Main content
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      margin: const EdgeInsets.symmetric(horizontal: 40),
                      padding: const EdgeInsets.only(top: 16, bottom: 32),
                      child: Consumer<ManageMeetingsProvider>(
                        builder: (context, meetingsProvider, child) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // App Info Section
                              const AppInfoWidget(),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  const FooterWidget(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
