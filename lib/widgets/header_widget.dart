import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';

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
                  _HeaderButton(
                    text: 'Home',
                    onPressed: () {
                      Navigator.of(context).pushNamed('/');
                    },
                    isPrimary: false,
                  ),
                  if (!authProvider.isLoggedIn)
                    Row(
                      children: [
                        _HeaderButton(
                          text: 'Member Login',
                          onPressed: () {
                            Navigator.of(context).pushNamed('/member-login');
                          },
                          isPrimary: false,
                        ),
                        const SizedBox(width: 12),
                        _HeaderButton(
                          text: 'Club Login',
                          onPressed: () {
                            Navigator.of(context).pushNamed('/club-login');
                          },
                          isPrimary: true,
                        ),
                      ],
                    )
                  else if (authProvider.authStateResolved)
                    _HeaderButton(
                      text: 'Profile',
                      onPressed: authProvider.accountTypeResolved
                          ? () {
                              // Navigate based on account type
                              if (authProvider.accountType == AccountType.club) {
                                Navigator.of(context).pushNamed('/club-base');
                              } else if (authProvider.accountType == AccountType.member) {
                                Navigator.of(context).pushNamed('/member-base');
                              }
                              // If account type is unknown, don't navigate
                            }
                          : null, // Disable button if account type not determined
                      isPrimary: true,
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
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _HeaderButton({
    required this.text,
    this.onPressed,
    this.isPrimary = false,
  });

  @override
  State<_HeaderButton> createState() => _HeaderButtonState();
}

class _HeaderButtonState extends State<_HeaderButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = themeProvider.colors;
        
        if (widget.isPrimary) {
          // Primary button with gradient
          final isEnabled = widget.onPressed != null;
          return MouseRegion(
            onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
            onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(8),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isEnabled
                          ? (_isHovered
                              ? colors.primaryButtonGradient
                              : colors.primaryButtonGradient
                                  .map((c) => c.withOpacity(0.9))
                                  .toList())
                          : colors.primaryButtonGradient
                              .map((c) => c.withOpacity(0.5))
                              .toList(),
                    ),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: isEnabled && _isHovered
                        ? [
                            BoxShadow(
                              color: colors.buttonShadow.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      widget.text,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? Colors.white : Colors.white.withOpacity(0.6),
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
          final isEnabled = widget.onPressed != null;
          return MouseRegion(
            onEnter: isEnabled ? (_) => setState(() => _isHovered = true) : null,
            onExit: isEnabled ? (_) => setState(() => _isHovered = false) : null,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                borderRadius: BorderRadius.circular(8),
                hoverColor: isEnabled ? Colors.grey.withOpacity(0.1) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Text(
                    widget.text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: isEnabled
                          ? (_isHovered
                              ? colors.secondaryButtonHover
                              : colors.secondaryButtonDefault)
                          : colors.secondaryButtonDefault.withOpacity(0.5),
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      },
    );
  }
}
