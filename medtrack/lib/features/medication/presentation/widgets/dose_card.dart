import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../domain/entities/dose_schedule.dart';

class DoseCard extends StatelessWidget {
  const DoseCard({
    super.key,
    required this.schedule,
    required this.onTaken,
    required this.onSkipped,
  });

  final DoseSchedule schedule;
  final VoidCallback onTaken;
  final VoidCallback onSkipped;

  @override
  Widget build(BuildContext context) {
    final timeLabel = schedule.isPrn
        ? 'ตามอาการ (PRN)'
        : DateFormat.Hm('th').format(schedule.scheduledTime);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                timeLabel.length > 5 ? timeLabel.substring(0, 5) : timeLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.medicationName,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    schedule.dosage,
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onSkipped,
              icon: const Icon(Icons.close),
              color: AppColors.critical,
              tooltip: 'ข้ามมื้อนี้',
            ),
            IconButton.filled(
              onPressed: onTaken,
              icon: const Icon(Icons.check),
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              tooltip: 'กินยาแล้ว',
            ),
          ],
        ),
      ),
    );
  }
}
