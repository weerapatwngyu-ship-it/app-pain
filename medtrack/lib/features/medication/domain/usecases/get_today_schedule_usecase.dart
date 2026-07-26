import '../../../../core/error/failure.dart';
import '../entities/dose_schedule.dart';
import '../repositories/medication_repository.dart';

class GetTodayScheduleUseCase {
  const GetTodayScheduleUseCase(this._repository);

  final MedicationRepository _repository;

  Future<Result<List<DoseSchedule>>> call(String patientId) {
    return _repository.getTodaySchedule(patientId);
  }
}
