import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../features/auth/presentation/onboarding/onboarding_theme.dart';

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
      // One coloured band across the top of every screen that has an app bar.
      // They had drifted into a mix of white and teal, so a screen's header
      // looked like a header or like nothing depending on which one you
      // reached. Status bar icons are forced light, since they sit on the
      // teal and would otherwise be dark-on-dark on most phones.
      appBarTheme: const AppBarTheme(
        backgroundColor: OnboardingColors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
    );
  }
}
