import '../entities/dose_log.dart';
import '../medication_repository.dart';

/// Records a taken/skipped/snoozed dose. The repository implementation is
/// responsible for the offline-first write-local-then-sync behavior
/// described in docs/architecture.md §10.
class LogDoseUseCase {
  LogDoseUseCase(this._repository);

  final MedicationRepository _repository;

  Future<void> call(DoseLog log) => _repository.logDose(log);
}
