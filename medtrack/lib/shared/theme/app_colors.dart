import 'package:flutter/material.dart';

/// Palette shared with the architecture document: clinical teal as the
/// primary accent, warm amber for reminders/attention, brick red for
/// critical alerts.
class AppColors {
  const AppColors._();

  static const Color primary = Color(0xFF0B5D52);
  static const Color primarySoft = Color(0xFFDCEBE6);

  static const Color warm = Color(0xFFC67C2E);
  static const Color warmSoft = Color(0xFFF4E4CC);

  static const Color critical = Color(0xFFA63D3D);
  static const Color criticalSoft = Color(0xFFF3DEDD);

  static const Color background = Color(0xFFF3F5F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceDim = Color(0xFFEAEDE8);

  static const Color textPrimary = Color(0xFF16211D);
  static const Color textMuted = Color(0xFF5B6B63);
  static const Color border = Color(0x1F16211D);
}
