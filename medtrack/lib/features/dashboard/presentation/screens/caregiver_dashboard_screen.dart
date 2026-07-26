import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../alerts/presentation/providers/alert_providers.dart';
import '../../../symptom_tracking/presentation/providers/symptom_providers.dart';
import '../../../symptom_tracking/presentation/widgets/symptom_trend_chart.dart';
import '../widgets/summary_stat_card.dart';

/// Care Dashboard module — one screen for a caregiver or provider to see
/// a linked patient's adherence, symptom trend, and open alerts at a
/// glance, per §05 of the architecture doc.
class CaregiverDashboardScreen extends ConsumerWidget {
  const CaregiverDashboardScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final trendArgs = (
      patientId: patientId,
      from: now.subtract(const Duration(days: 14)),
      to: now,
    );
    final trendAsync = ref.watch(symptomTrendProvider(trendArgs));
    final alertsAsync = ref.watch(openAlertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('ภาพรวมผู้ป่วย')),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: SummaryStatCard(
                  label: 'แจ้งเตือนค้างอยู่',
                  value: alertsAsync.maybeWhen(
                    data: (alerts) => '${alerts.length}',
                    orElse: () => '—',
                  ),
                  accent: AppColors.critical,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SummaryStatCard(
                  label: 'บันทึกอาการ (14 วัน)',
                  value: trendAsync.maybeWhen(
                    data: (logs) => '${logs.length} ครั้ง',
                    orElse: () => '—',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('แนวโน้มระดับความเจ็บปวด', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: trendAsync.when(
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (error, _) => Text('โหลดข้อมูลไม่สำเร็จ: $error'),
                data: (logs) => SymptomTrendChart(logs: logs),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
