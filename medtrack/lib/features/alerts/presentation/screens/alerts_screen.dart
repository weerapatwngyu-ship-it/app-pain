import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../providers/alert_providers.dart';
import '../widgets/alert_severity_chip.dart';

class AlertsScreen extends ConsumerWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alertsAsync = ref.watch(openAlertsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('การแจ้งเตือน')),
      body: alertsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => EmptyState(
          icon: Icons.error_outline,
          title: 'โหลดการแจ้งเตือนไม่สำเร็จ',
          message: '$error',
        ),
        data: (alerts) {
          if (alerts.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'ไม่มีการแจ้งเตือนที่ค้างอยู่',
              message: 'เมื่อมีการพลาดยาหรืออาการผิดปกติ จะแสดงที่นี่',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: alerts.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return Card(
                child: ListTile(
                  title: Text(alert.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(DateFormat('d MMM yyyy, HH:mm', 'th').format(alert.createdAt)),
                  leading: AlertSeverityChip(severity: alert.severity),
                  trailing: TextButton(
                    onPressed: () => ref.read(acknowledgeAlertProvider(alert.id)),
                    child: const Text('รับทราบ'),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
