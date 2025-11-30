import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Center(
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          // Home button pill
                          ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pushNamed('/');
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: const Text(
                                    'Home',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E1B4B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Create Meeting button pill
                          ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(50),
                                ),
                                child: TextButton(
                                  onPressed: () {
                                    if (authProvider.isLoggedIn) {
                                      Navigator.of(context).pushNamed('/base');
                                    } else {
                                      Navigator.of(context).pushNamed('/club-login');
                                    }
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                  ),
                                  child: const Text(
                                    'Create Meeting',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E1B4B),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Login button pill
                      ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1B4B).withOpacity(0.9),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: TextButton(
                              onPressed: () {
                                if (authProvider.isLoggedIn) {
                                  // Navigate to base/profile
                                  Navigator.of(context).pushNamed('/base');
                                } else {
                                  Navigator.of(context).pushNamed('/club-login');
                                }
                              },
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                              child: Text(
                                authProvider.isLoggedIn ? 'Profile' : 'Login',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
