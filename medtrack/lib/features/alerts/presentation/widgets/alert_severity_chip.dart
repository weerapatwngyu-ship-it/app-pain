import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/alert.dart';

class AlertSeverityChip extends StatelessWidget {
  const AlertSeverityChip({super.key, required this.severity});

  final AlertSeverity severity;

  ({Color bg, Color fg, String label}) get _style => switch (severity) {
        AlertSeverity.normal =>
          (bg: AppColors.primarySoft, fg: AppColors.primary, label: 'ปกติ'),
        AlertSeverity.watch =>
          (bg: AppColors.warmSoft, fg: AppColors.warm, label: 'ควรเฝ้าระวัง'),
        AlertSeverity.critical =>
          (bg: AppColors.criticalSoft, fg: AppColors.critical, label: 'ฉุกเฉิน'),
      };

  @override
  Widget build(BuildContext context) {
    final style = _style;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        style.label,
        style: TextStyle(color: style.fg, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}
