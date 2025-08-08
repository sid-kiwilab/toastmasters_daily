import 'package:flutter/material.dart';

class AppTheme {
  // Text Sizes
  static const double textSizeXs = 10.0;
  static const double textSizeSm = 12.0;
  static const double textSizeMd = 14.0;
  static const double textSizeLg = 16.0;
  static const double textSizeXl = 18.0;
  static const double textSize2xl = 20.0;
  static const double textSize3xl = 24.0;
  static const double textSize4xl = 28.0;
  static const double textSize5xl = 32.0;
  static const double textSize6xl = 36.0;

  // Font Family
  static const String fontFamily = 'OldschoolGrotesk';

  // Light Theme Colors (Grayscale)
  static const Color lightPrimary = Color(0xFF1A1A1A);
  static const Color lightSecondary = Color(0xFF404040);
  static const Color lightTertiary = Color(0xFF666666);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightError = Color(0xFFDC3545);
  static const Color lightSuccess = Color(0xFF28A745);
  static const Color lightWarning = Color(0xFFFFC107);
  static const Color lightInfo = Color(0xFF17A2B8);
  static const Color lightDivider = Color(0xFFE9ECEF);
  static const Color lightBorder = Color(0xFFDEE2E6);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightAppBar = Color(0xFFFFFFFF);
  static const Color lightBottomNav = Color(0xFFFFFFFF);
  static const Color lightOverlay = Color(0x80000000);

  // Dark Theme Colors (Grayscale)
  static const Color darkPrimary = Color(0xFFFFFFFF);
  static const Color darkSecondary = Color(0xFFE9ECEF);
  static const Color darkTertiary = Color(0xFFCED4DA);
  static const Color darkSurface = Color(0xFF212529);
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkError = Color(0xFFE74C3C);
  static const Color darkSuccess = Color(0xFF2ECC71);
  static const Color darkWarning = Color(0xFFF39C12);
  static const Color darkInfo = Color(0xFF3498DB);
  static const Color darkDivider = Color(0xFF495057);
  static const Color darkBorder = Color(0xFF6C757D);
  static const Color darkCard = Color(0xFF2D3748);
  static const Color darkAppBar = Color(0xFF1A1A1A);
  static const Color darkBottomNav = Color(0xFF1A1A1A);
  static const Color darkOverlay = Color(0x80000000);

  // Light Theme
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.light(
        primary: lightPrimary,
        secondary: lightSecondary,
        tertiary: lightTertiary,
        surface: lightSurface,
        background: lightBackground,
        error: lightError,
        onPrimary: lightSurface,
        onSecondary: lightSurface,
        onTertiary: lightSurface,
        onSurface: lightPrimary,
        onBackground: lightPrimary,
        onError: lightSurface,
      ),
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: lightAppBar,
        foregroundColor: lightPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: lightPrimary,
          fontSize: textSizeLg,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: lightPrimary,
          foregroundColor: lightSurface,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: textSizeMd,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: lightPrimary,
          side: const BorderSide(color: lightBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: textSizeMd,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: lightPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: textSizeMd,
            fontWeight: FontWeight.w500,
            fontFamily: fontFamily,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: lightError),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(color: lightSecondary, fontFamily: fontFamily),
        hintStyle: const TextStyle(color: lightTertiary, fontFamily: fontFamily),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightBottomNav,
        selectedItemColor: lightPrimary,
        unselectedItemColor: lightTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: textSize6xl,
          fontWeight: FontWeight.bold,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        displayMedium: TextStyle(
          fontSize: textSize5xl,
          fontWeight: FontWeight.bold,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        displaySmall: TextStyle(
          fontSize: textSize4xl,
          fontWeight: FontWeight.bold,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        headlineLarge: TextStyle(
          fontSize: textSize3xl,
          fontWeight: FontWeight.w600,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        headlineMedium: TextStyle(
          fontSize: textSize2xl,
          fontWeight: FontWeight.w600,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        headlineSmall: TextStyle(
          fontSize: textSizeXl,
          fontWeight: FontWeight.w600,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        titleLarge: TextStyle(
          fontSize: textSizeLg,
          fontWeight: FontWeight.w600,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        titleMedium: TextStyle(
          fontSize: textSizeMd,
          fontWeight: FontWeight.w500,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        titleSmall: TextStyle(
          fontSize: textSizeSm,
          fontWeight: FontWeight.w500,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        bodyLarge: TextStyle(
          fontSize: textSizeLg,
          fontWeight: FontWeight.normal,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        bodyMedium: TextStyle(
          fontSize: textSizeMd,
          fontWeight: FontWeight.normal,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        bodySmall: TextStyle(
          fontSize: textSizeSm,
          fontWeight: FontWeight.normal,
          color: lightSecondary,
          fontFamily: fontFamily,
        ),
        labelLarge: TextStyle(
          fontSize: textSizeMd,
          fontWeight: FontWeight.w500,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        labelMedium: TextStyle(
          fontSize: textSizeSm,
          fontWeight: FontWeight.w500,
          color: lightPrimary,
          fontFamily: fontFamily,
        ),
        labelSmall: TextStyle(
          fontSize: textSizeXs,
          fontWeight: FontWeight.w500,
          color: lightSecondary,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  // Dark Theme
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: fontFamily,
      colorScheme: const ColorScheme.dark(
        primary: darkPrimary,
        secondary: darkSecondary,
        tertiary: darkTertiary,
        surface: darkSurface,
        background: darkBackground,
        error: darkError,
        onPrimary: darkBackground,
        onSecondary: darkBackground,
        onTertiary: darkBackground,
        onSurface: darkPrimary,
        onBackground: darkPrimary,
        onError: darkBackground,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkAppBar,
        foregroundColor: darkPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: darkPrimary,
          fontSize: textSizeLg,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkCard,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkPrimary,
          foregroundColor: darkBackground,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: textSizeMd,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: darkPrimary,
          side: const BorderSide(color: darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: textSizeMd,
            fontWeight: FontWeight.w600,
            fontFamily: fontFamily,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: darkPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: textSizeMd,
            fontWeight: FontWeight.w500,
            fontFamily: fontFamily,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: darkError),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        labelStyle: const TextStyle(color: darkSecondary, fontFamily: fontFamily),
        hintStyle: const TextStyle(color: darkTertiary, fontFamily: fontFamily),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkBottomNav,
        selectedItemColor: darkPrimary,
        unselectedItemColor: darkTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: textSize6xl,
          fontWeight: FontWeight.bold,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        displayMedium: TextStyle(
          fontSize: textSize5xl,
          fontWeight: FontWeight.bold,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        displaySmall: TextStyle(
          fontSize: textSize4xl,
          fontWeight: FontWeight.bold,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        headlineLarge: TextStyle(
          fontSize: textSize3xl,
          fontWeight: FontWeight.w600,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        headlineMedium: TextStyle(
          fontSize: textSize2xl,
          fontWeight: FontWeight.w600,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        headlineSmall: TextStyle(
          fontSize: textSizeXl,
          fontWeight: FontWeight.w600,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        titleLarge: TextStyle(
          fontSize: textSizeLg,
          fontWeight: FontWeight.w600,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        titleMedium: TextStyle(
          fontSize: textSizeMd,
          fontWeight: FontWeight.w500,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        titleSmall: TextStyle(
          fontSize: textSizeSm,
          fontWeight: FontWeight.w500,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        bodyLarge: TextStyle(
          fontSize: textSizeLg,
          fontWeight: FontWeight.normal,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        bodyMedium: TextStyle(
          fontSize: textSizeMd,
          fontWeight: FontWeight.normal,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        bodySmall: TextStyle(
          fontSize: textSizeSm,
          fontWeight: FontWeight.normal,
          color: darkSecondary,
          fontFamily: fontFamily,
        ),
        labelLarge: TextStyle(
          fontSize: textSizeMd,
          fontWeight: FontWeight.w500,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        labelMedium: TextStyle(
          fontSize: textSizeSm,
          fontWeight: FontWeight.w500,
          color: darkPrimary,
          fontFamily: fontFamily,
        ),
        labelSmall: TextStyle(
          fontSize: textSizeXs,
          fontWeight: FontWeight.w500,
          color: darkSecondary,
          fontFamily: fontFamily,
        ),
      ),
    );
  }

  // Helper methods to get colors based on current theme
  static Color getPrimaryColor(bool isDark) => isDark ? darkPrimary : lightPrimary;
  static Color getSecondaryColor(bool isDark) => isDark ? darkSecondary : lightSecondary;
  static Color getBackgroundColor(bool isDark) => isDark ? darkBackground : lightBackground;
  static Color getSurfaceColor(bool isDark) => isDark ? darkSurface : lightSurface;
  static Color getErrorColor(bool isDark) => isDark ? darkError : lightError;
  static Color getSuccessColor(bool isDark) => isDark ? darkSuccess : lightSuccess;
  static Color getWarningColor(bool isDark) => isDark ? darkWarning : lightWarning;
  static Color getInfoColor(bool isDark) => isDark ? darkInfo : lightInfo;
}
