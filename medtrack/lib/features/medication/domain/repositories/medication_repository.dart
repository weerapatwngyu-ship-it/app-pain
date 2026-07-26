import '../../../../core/error/failure.dart';
import '../entities/dose_log.dart';
import '../entities/dose_schedule.dart';

abstract interface class MedicationRepository {
  /// Today's dose schedule for [patientId]. Reads local cache first and
  /// refreshes from the API when reachable — see [MedicationRepositoryImpl].
  Future<Result<List<DoseSchedule>>> getTodaySchedule(String patientId);

  /// Records a dose action. Always written to the local queue first so
  /// it succeeds offline; sync happens in the background.
  Future<Result<DoseLog>> logDose({
    required String scheduleId,
    required DateTime scheduledAt,
    required DoseStatus status,
  });

  Future<Result<double>> getAdherenceRate({
    required String patientId,
    required DateTime from,
    required DateTime to,
  });
}
