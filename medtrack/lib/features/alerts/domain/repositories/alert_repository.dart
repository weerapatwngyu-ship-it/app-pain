import '../../../../core/error/failure.dart';
import '../entities/alert.dart';

abstract interface class AlertRepository {
  Future<Result<List<Alert>>> getOpenAlerts();

  Future<Result<Alert>> acknowledge(String alertId);
}
