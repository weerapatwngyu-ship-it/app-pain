import 'package:flutter/material.dart';

import '../../../shared/theme/app_theme.dart';
import '../data/alerts_repository.dart';
import '../domain/entities/alert.dart';
import '../../../core/i18n/app_locale.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.alertsRepository});

  final AlertsRepository alertsRepository;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  late Future<List<PatientAlert>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _alertsFuture = widget.alertsRepository.openAlerts();
  }

  Future<void> _acknowledge(PatientAlert alert) async {
    await widget.alertsRepository.acknowledge(alert.id);
    setState(() => _alertsFuture = widget.alertsRepository.openAlerts());
  }

  Color _severityColor(AlertSeverity severity) {
    switch (severity) {
      case AlertSeverity.critical:
        return AppColors.critical;
      case AlertSeverity.watch:
        return AppColors.warm;
      case AlertSeverity.normal:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(t('การแจ้งเตือน', 'Alerts'))),
      body: FutureBuilder<List<PatientAlert>>(
        future: _alertsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final alerts = snapshot.data ?? [];
          if (alerts.isEmpty) {
            return Center(child: Text(t('ไม่มีการแจ้งเตือนที่ค้างอยู่', 'No open alerts')));
          }
          return ListView.builder(
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              return ListTile(
                leading: Icon(Icons.warning_amber_rounded, color: _severityColor(alert.severity)),
                title: Text(alert.message ?? alert.severity.name),
                trailing: TextButton(
                  onPressed: () => _acknowledge(alert),
                  child: Text(t('รับทราบ', 'Acknowledge')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
