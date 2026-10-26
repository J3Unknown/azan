import 'package:flutter/material.dart';

class ColorsManager {
  // Primary gold accent
  static const Color primaryGold = Color(0xFFCFB68E);
  static const Color primaryGoldLight = Color(0xFFE8D5B0);
  static const Color primaryGoldDark = Color(0xFFAA9060);

  // Dark theme
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color darkSurface = Color(0xFF2A2A28);
  static const Color darkCard = Color(0xFF353533);
  static const Color darkCardLight = Color(0xFF3E3E3C);
  static const Color darkDivider = Color(0xFF444442);

  // Text
  static const Color textPrimary = Color(0xFFEDE8E0);
  static const Color textSecondary = Color(0xFFB0AAA0);
  static const Color textMuted = Color(0xFF7A756B);

  // Status
  static const Color activeGreen = Color(0xFF6B9B7A);
  static const Color inactiveGrey = Color(0xFF5A5A58);

  // Glassmorphism
  static const Color glassBackground = Color(0x33FFFFFF);
  static const Color glassBorder = Color(0x22FFFFFF);

  // Legacy mappings
  static Color primaryColor = primaryGold;
  static Color darkThemeSecondaryColor = darkSurface;
  static Color darkThemeBackgroundColor = darkBackground;
  static Color lightThemeSecondaryColor = Color(0xffFAFBF5);
  static Color lightThemeBackgroundColor = Color(0xffF0F1E8);
  static Color grey = textMuted;
}
