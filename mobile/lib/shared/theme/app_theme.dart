import 'package:flutter/material.dart';

import 'app_palette.dart';

/// Kept as an alias so older screens that reference [AppColors] keep
/// compiling. New code should name [AppPalette] directly.
class AppColors {
  AppColors._();

  static const accent = AppPalette.primary;
  static const accentSoft = AppPalette.soft;
  static const warm = AppPalette.warning;
  static const critical = AppPalette.danger;
  static const background = AppPalette.tint;
  static const surface = AppPalette.surface;
  static const text = AppPalette.text;
  static const textMuted = AppPalette.textMuted;
}

class AppTheme {
  AppTheme._();

  /// Corner radius used everywhere something is a card, a field, or a button.
  /// One value rather than the 8/12/14/16/20 that were in use, because
  /// mismatched radii are most of what makes a screen look unconsidered.
  static const radius = 14.0;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppPalette.primary,
      onPrimary: Colors.white,
      surface: AppPalette.surface,
      onSurface: AppPalette.text,
      error: AppPalette.danger,
    );

    final base = ThemeData(useMaterial3: true, colorScheme: scheme);

    return base.copyWith(
      scaffoldBackgroundColor: AppPalette.tint,

      // Headings carry the dark blue; body text stays softer. Setting it here
      // means a screen gets the hierarchy without naming a colour at all.
      textTheme: base.textTheme
          .apply(bodyColor: AppPalette.text, displayColor: AppPalette.heading)
          .copyWith(
            titleLarge: base.textTheme.titleLarge?.copyWith(
              color: AppPalette.heading,
              fontWeight: FontWeight.w700,
            ),
            titleMedium: base.textTheme.titleMedium?.copyWith(
              color: AppPalette.heading,
              fontWeight: FontWeight.w700,
            ),
          ),

      appBarTheme: const AppBarTheme(
        backgroundColor: AppPalette.surface,
        foregroundColor: AppPalette.heading,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppPalette.heading,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),

      cardTheme: CardThemeData(
        color: AppPalette.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 2),
          side: const BorderSide(color: AppPalette.border),
        ),
      ),

      // Filled, borderless fields — the outline reappears only on focus, so a
      // form reads as a set of soft blocks rather than a stack of boxes.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.field,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: AppPalette.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppPalette.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppPalette.danger),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppPalette.primaryDisabled,
          disabledForegroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppPalette.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppPalette.primary,
          side: const BorderSide(color: AppPalette.softBorder),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppPalette.primary),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: AppPalette.soft,
        selectedColor: AppPalette.primary,
        checkmarkColor: Colors.white,
        labelStyle: const TextStyle(
          color: AppPalette.heading,
          fontWeight: FontWeight.w600,
        ),
        secondaryLabelStyle: const TextStyle(color: Colors.white),
        side: const BorderSide(color: AppPalette.softBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppPalette.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 2),
        ),
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        selectedItemColor: AppPalette.primary,
        unselectedItemColor: AppPalette.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppPalette.surface,
        indicatorColor: AppPalette.soft,
        elevation: 8,
      ),

      dividerTheme: const DividerThemeData(
        color: AppPalette.border,
        thickness: 1,
        space: 1,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppPalette.heading,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
        ),
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius + 4),
        ),
        titleTextStyle: const TextStyle(
          color: AppPalette.heading,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: const TextStyle(color: AppPalette.text, height: 1.5),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppPalette.primary),
    );
  }
}
