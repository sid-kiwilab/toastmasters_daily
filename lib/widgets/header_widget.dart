import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';

class HeaderWidget extends StatelessWidget {
  const HeaderWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: const BoxDecoration(
            color: Colors.white,
          ),
          child: Center(
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Home link - clean text button
                  _HeaderButton(
                    text: 'Home',
                    onPressed: () {
                      Navigator.of(context).pushNamed('/');
                    },
                    isActive: false,
                    isPrimary: false,
                  ),
                  // Login buttons group
                  Row(
                    children: [
                      _HeaderButton(
                        text: authProvider.isLoggedIn ? 'Club Profile' : 'Club Login',
                        onPressed: () {
                          if (authProvider.isLoggedIn) {
                            Navigator.of(context).pushNamed('/base');
                          } else {
                            Navigator.of(context).pushNamed('/club-login');
                          }
                        },
                        isActive: false,
                        isPrimary: false,
                      ),
                      const SizedBox(width: 8),
                      _HeaderButton(
                        text: authProvider.isLoggedIn ? 'User Profile' : 'User Login',
                        onPressed: () async {
                          if (authProvider.isLoggedIn) {
                            // Check account type and route accordingly
                            final userId = authProvider.userId;
                            if (userId != null) {
                              try {
                                final userDoc = await FirebaseFirestore.instance
                                    .collection('users')
                                    .doc(userId)
                                    .get();
                                
                                final accountType = userDoc.data()?['account_type'] as String?;
                                
                                if (accountType == 'individual') {
                                  Navigator.of(context).pushNamed('/user-profile');
                                } else {
                                  Navigator.of(context).pushNamed('/base');
                                }
                              } catch (e) {
                                Navigator.of(context).pushNamed('/base');
                              }
                            } else {
                              Navigator.of(context).pushNamed('/base');
                            }
                          } else {
                            Navigator.of(context).pushNamed('/user-login');
                          }
                        },
                        isActive: false,
                        isPrimary: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HeaderButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isActive;
  final bool isPrimary;

  const _HeaderButton({
    required this.text,
    required this.onPressed,
    required this.isActive,
    required this.isPrimary,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.isPrimary) {
      // Primary button with gradient
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isHovered
                  ? [
                      const Color(0xFF6366F1), // Indigo
                      const Color(0xFF8B5CF6), // Purple
                    ]
                  : [
                      const Color(0xFF6366F1).withOpacity(0.9),
                      const Color(0xFF8B5CF6).withOpacity(0.9),
                    ],
            ),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [
                    BoxShadow(
                      color: const Color(0xFF6366F1).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onPressed,
              borderRadius: BorderRadius.circular(8),
              child: Center(
                child: Text(
                  widget.text,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    } else {
      // Secondary button - clean text style
      return MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(8),
            hoverColor: Colors.grey.withOpacity(0.1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Text(
                widget.text,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                  color: _isHovered
                      ? const Color(0xFF6366F1)
                      : const Color(0xFF1E1B4B),
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }
}
