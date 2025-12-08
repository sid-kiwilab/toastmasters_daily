import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

class ThemeSwitcherWidget extends StatefulWidget {
  const ThemeSwitcherWidget({super.key});

  @override
  State<ThemeSwitcherWidget> createState() => _ThemeSwitcherWidgetState();
}

class _ThemeSwitcherWidgetState extends State<ThemeSwitcherWidget> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: PopupMenuButton<AppThemeType>(
            tooltip: 'Theme',
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            offset: const Offset(0, 12),
            color: Colors.white,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: _isHovered
                    ? themeProvider.colors.secondaryButtonDefault.withOpacity(0.05)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: themeProvider.colors.primaryButtonGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: _isHovered
                      ? [
                          BoxShadow(
                            color: themeProvider.colors.primaryButtonGradient.first
                                .withOpacity(0.2),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
              ),
            ),
            onSelected: (AppThemeType theme) {
              themeProvider.setTheme(theme);
            },
            itemBuilder: (BuildContext context) => [
              _buildMenuItem(
                context: context,
                themeProvider: themeProvider,
                theme: AppThemeType.purple,
                gradient: const [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                ],
                label: 'Quirky',
              ),
              _buildMenuItem(
                context: context,
                themeProvider: themeProvider,
                theme: AppThemeType.toastmasters,
                gradient: const [
                  Color(0xFF004165),
                  Color(0xFF772432),
                ],
                label: 'Classic',
              ),
            ],
          ),
        );
      },
    );
  }

  PopupMenuItem<AppThemeType> _buildMenuItem({
    required BuildContext context,
    required ThemeProvider themeProvider,
    required AppThemeType theme,
    required List<Color> gradient,
    required String label,
  }) {
    final isSelected = themeProvider.currentTheme == theme;
    
    return PopupMenuItem<AppThemeType>(
      value: theme,
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          themeProvider.setTheme(theme);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? themeProvider.colors.primaryButtonGradient.first.withOpacity(0.08)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? gradient.first
                        : Colors.grey.withOpacity(0.2),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: gradient.first.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? themeProvider.colors.secondaryButtonDefault
                        : const Color(0xFF212121),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  size: 20,
                  color: gradient.first,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

