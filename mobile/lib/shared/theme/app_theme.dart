import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const accent = Color(0xFF0B5D52);
  static const accentSoft = Color(0xFFDCEBE6);
  static const warm = Color(0xFFC67C2E);
  static const critical = Color(0xFFA63D3D);
  static const background = Color(0xFFF3F5F2);
  static const surface = Color(0xFFFFFFFF);
  static const text = Color(0xFF16211D);
  static const textMuted = Color(0xFF5B6B63);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        elevation: 0,
      ),
    );
  }
}
