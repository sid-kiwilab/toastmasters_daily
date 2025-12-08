import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppThemeType {
  purple, // Original purple/indigo gradient design
  toastmasters, // Toastmasters classic colors
}

class AppThemeColors {
  // Banner gradient colors
  final List<Color> bannerGradient;
  
  // Footer gradient colors
  final List<Color> footerGradient;
  
  // Primary button gradient colors
  final List<Color> primaryButtonGradient;
  
  // Secondary button colors
  final Color secondaryButtonDefault;
  final Color secondaryButtonHover;
  
  // Shadow colors
  final Color bannerShadow;
  final Color buttonShadow;
  
  // Accent colors
  final Color footerAccent;
  
  // Button text color (for banner)
  final Color bannerButtonBackground;
  final Color bannerButtonText;

  const AppThemeColors({
    required this.bannerGradient,
    required this.footerGradient,
    required this.primaryButtonGradient,
    required this.secondaryButtonDefault,
    required this.secondaryButtonHover,
    required this.bannerShadow,
    required this.buttonShadow,
    required this.footerAccent,
    required this.bannerButtonBackground,
    required this.bannerButtonText,
  });

  // Purple theme (original design)
  static const AppThemeColors purple = AppThemeColors(
    bannerGradient: [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Purple
    ],
    footerGradient: [
      Color(0xFF1E1B4B), // Dark indigo
      Color(0xFF312E81), // Darker purple
    ],
    primaryButtonGradient: [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Purple
    ],
    secondaryButtonDefault: Color(0xFF1E1B4B), // Dark indigo
    secondaryButtonHover: Color(0xFF6366F1), // Indigo
    bannerShadow: Color(0xFF6366F1), // Indigo
    buttonShadow: Color(0xFF6366F1), // Indigo
    footerAccent: Color(0xFFA5B4FC), // Light purple
    bannerButtonBackground: Colors.white,
    bannerButtonText: Color(0xFF6366F1), // Indigo
  );

  // Toastmasters classic theme
  static const AppThemeColors toastmasters = AppThemeColors(
    bannerGradient: [
      Color(0xFF004165), // Toastmasters Loyal Blue
      Color(0xFF772432), // Toastmasters True Maroon
    ],
    footerGradient: [
      Color(0xFF004165), // Toastmasters Loyal Blue
      Color(0xFF003049), // Darker blue
    ],
    primaryButtonGradient: [
      Color(0xFF772432), // Toastmasters True Maroon
      Color(0xFF5A1A25), // Darker maroon
    ],
    secondaryButtonDefault: Color(0xFF003049), // Darker blue
    secondaryButtonHover: Color(0xFF004165), // Toastmasters Loyal Blue
    bannerShadow: Color(0xFF004165), // Toastmasters Loyal Blue
    buttonShadow: Color(0xFF772432), // Toastmasters True Maroon
    footerAccent: Color(0xFFA9B2B1), // Toastmasters Cool Gray
    bannerButtonBackground: Color(0xFFF2DF74), // Toastmasters Happy Yellow
    bannerButtonText: Color(0xFF004165), // Toastmasters Loyal Blue
  );
}

class ThemeProvider extends ChangeNotifier {
  AppThemeType _currentTheme = AppThemeType.toastmasters;
  static const String _themeKey = 'selected_theme';
  bool _isInitialized = false;

  AppThemeType get currentTheme => _currentTheme;
  
  AppThemeColors get colors {
    switch (_currentTheme) {
      case AppThemeType.purple:
        return AppThemeColors.purple;
      case AppThemeType.toastmasters:
        return AppThemeColors.toastmasters;
    }
  }

  // Initialize and load saved theme preference
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      
      if (savedTheme != null) {
        if (savedTheme == 'purple') {
          _currentTheme = AppThemeType.purple;
        } else if (savedTheme == 'toastmasters') {
          _currentTheme = AppThemeType.toastmasters;
        }
        notifyListeners();
      }
    } catch (e) {
      // If there's an error loading preferences, use default
      print('Error loading theme preference: $e');
    }
    
    _isInitialized = true;
  }

  Future<void> setTheme(AppThemeType theme) async {
    if (_currentTheme != theme) {
      _currentTheme = theme;
      notifyListeners();
      
      // Save preference
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_themeKey, theme == AppThemeType.purple ? 'purple' : 'toastmasters');
      } catch (e) {
        print('Error saving theme preference: $e');
      }
    }
  }

  void toggleTheme() {
    final newTheme = _currentTheme == AppThemeType.purple
        ? AppThemeType.toastmasters
        : AppThemeType.purple;
    setTheme(newTheme);
  }
}

