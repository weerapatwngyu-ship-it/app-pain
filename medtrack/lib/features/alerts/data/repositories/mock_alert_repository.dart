import '../../../../core/error/failure.dart';
import '../../domain/entities/alert.dart';
import '../../domain/repositories/alert_repository.dart';

/// Two sample open alerts (one watch, one critical) so the alerts
/// screen has something to show before a real backend is wired up.
class MockAlertRepository implements AlertRepository {
  final List<Alert> _alerts = [
    Alert(
      id: 'alert-1',
      patientId: 'demo-patient-1',
      title: 'พลาดยา Amlodipine เมื่อคืน',
      severity: AlertSeverity.watch,
      status: AlertStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 10)),
    ),
    Alert(
      id: 'alert-2',
      patientId: 'demo-patient-1',
      title: 'คะแนนความเจ็บปวดสูงต่อเนื่อง 3 วัน',
      severity: AlertSeverity.critical,
      status: AlertStatus.open,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
    ),
  ];

  @override
  Future<Result<List<Alert>>> getOpenAlerts() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Success(_alerts.where((a) => a.status == AlertStatus.open).toList());
  }

  @override
  Future<Result<Alert>> acknowledge(String alertId) async {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index == -1) {
      return const Error(ServerFailure('ไม่พบการแจ้งเตือนนี้'));
    }
    final updated = _alerts[index].copyWith(status: AlertStatus.acknowledged);
    _alerts[index] = updated;
    return Success(updated);
  }
}
