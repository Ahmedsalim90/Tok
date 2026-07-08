import 'package:flutter/material.dart';

// Brand colors — stay constant across both themes
const kNavy = Color(0xFF1B2432);
const kCoral = Color(0xFFE4633F);
const kAppBarBg = kNavy;
const kAppBarFg = Colors.white;

// Light mode palette
const kLightBackground = Color(0xFFF7F5F2);
const kLightSurface = Colors.white;
const kLightTextPrimary = kNavy;
const kLightTextSecondary = Color(0xFF8A8478);
const kLightFieldLine = Color(0xFFC9C2B8);

// Dark mode palette
const kDarkBackground = Color(0xFF121821);
const kDarkSurface = Color(0xFF1E2733);
const kDarkTextPrimary = Color(0xFFF1EFEC);
const kDarkTextSecondary = Color(0xFF9AA3AE);
const kDarkFieldLine = Color(0xFF33404E);

// Global switch controlling the app's theme. Any screen can read/set this.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class AppColors {
  final Color background;
  final Color surface;
  final Color textPrimary;
  final Color textSecondary;
  final Color fieldLine;

  const AppColors({
    required this.background,
    required this.surface,
    required this.textPrimary,
    required this.textSecondary,
    required this.fieldLine,
  });

  static AppColors of(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? const AppColors(
      background: kDarkBackground,
      surface: kDarkSurface,
      textPrimary: kDarkTextPrimary,
      textSecondary: kDarkTextSecondary,
      fieldLine: kDarkFieldLine,
    )
        : const AppColors(
      background: kLightBackground,
      surface: kLightSurface,
      textPrimary: kLightTextPrimary,
      textSecondary: kLightTextSecondary,
      fieldLine: kLightFieldLine,
    );
  }
}

final ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: kLightBackground,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kCoral,
    brightness: Brightness.light,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kAppBarBg,
    foregroundColor: kAppBarFg,
  ),
);

final ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: kDarkBackground,
  colorScheme: ColorScheme.fromSeed(
    seedColor: kCoral,
    brightness: Brightness.dark,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: kAppBarBg,
    foregroundColor: kAppBarFg,
  ),
);