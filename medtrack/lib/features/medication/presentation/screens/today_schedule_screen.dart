import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/entities/dose_log.dart';
import '../providers/medication_providers.dart';
import '../widgets/dose_card.dart';

class TodayScheduleScreen extends ConsumerWidget {
  const TodayScheduleScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheduleAsync = ref.watch(todayScheduleProvider(patientId));

    return Scaffold(
      appBar: AppBar(title: const Text('ตารางยาวันนี้')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(todayScheduleProvider(patientId).future),
        child: scheduleAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => EmptyState(
            icon: Icons.wifi_off_rounded,
            title: 'โหลดตารางยาไม่สำเร็จ',
            message: '$error',
          ),
          data: (schedule) {
            if (schedule.isEmpty) {
              return const EmptyState(
                icon: Icons.medication_outlined,
                title: 'ไม่มีตารางยาวันนี้',
                message: 'เมื่อมีใบสั่งยาใหม่ ตารางจะแสดงที่นี่โดยอัตโนมัติ',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: schedule.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = schedule[index];
                return DoseCard(
                  schedule: item,
                  onTaken: () => ref.read(doseActionControllerProvider.notifier).confirm(
                        scheduleId: item.id,
                        scheduledAt: item.scheduledTime,
                        status: DoseStatus.taken,
                      ),
                  onSkipped: () => ref.read(doseActionControllerProvider.notifier).confirm(
                        scheduleId: item.id,
                        scheduledAt: item.scheduledTime,
                        status: DoseStatus.skipped,
                      ),
                );
              },
            );
          },
        ),
      ),
      backgroundColor: AppColors.background,
    );
  }
}
