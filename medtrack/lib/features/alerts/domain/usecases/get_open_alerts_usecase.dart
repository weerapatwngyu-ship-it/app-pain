import '../../../../core/error/failure.dart';
import '../entities/alert.dart';
import '../repositories/alert_repository.dart';

class GetOpenAlertsUseCase {
  const GetOpenAlertsUseCase(this._repository);

  final AlertRepository _repository;

  Future<Result<List<Alert>>> call() => _repository.getOpenAlerts();
}
