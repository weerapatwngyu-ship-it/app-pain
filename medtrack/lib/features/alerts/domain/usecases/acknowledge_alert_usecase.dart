import '../../../../core/error/failure.dart';
import '../entities/alert.dart';
import '../repositories/alert_repository.dart';

class AcknowledgeAlertUseCase {
  const AcknowledgeAlertUseCase(this._repository);

  final AlertRepository _repository;

  Future<Result<Alert>> call(String alertId) => _repository.acknowledge(alertId);
}
