import 'entities/dose_log.dart';
import 'entities/dose_schedule_item.dart';

abstract class MedicationRepository {
  Future<List<DoseScheduleItem>> todaySchedule(String patientId);

  Future<void> logDose(DoseLog log);
}
