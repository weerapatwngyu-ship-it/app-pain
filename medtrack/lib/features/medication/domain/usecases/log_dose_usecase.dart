import '../../../../core/error/failure.dart';
import '../entities/dose_log.dart';
import '../repositories/medication_repository.dart';

class LogDoseUseCase {
  const LogDoseUseCase(this._repository);

  final MedicationRepository _repository;

  Future<Result<DoseLog>> call({
    required String scheduleId,
    required DateTime scheduledAt,
    required DoseStatus status,
  }) {
    return _repository.logDose(
      scheduleId: scheduleId,
      scheduledAt: scheduledAt,
      status: status,
    );
  }
}
