import '../../../../core/error/failure.dart';
import '../../domain/entities/dose_log.dart';
import '../../domain/entities/dose_schedule.dart';
import '../../domain/repositories/medication_repository.dart';

/// In-memory sample schedule so the today's-dose screen has something
/// to show before a real backend is wired up.
class MockMedicationRepository implements MedicationRepository {
  final List<DoseSchedule> _schedule = _buildDemoSchedule();
  final List<DoseLog> _logs = [];

  static List<DoseSchedule> _buildDemoSchedule() {
    final now = DateTime.now();
    DateTime at(int hour, int minute) =>
        DateTime(now.year, now.month, now.day, hour, minute);

    return [
      DoseSchedule(
        id: 'sch-1',
        prescriptionId: 'rx-1',
        medicationName: 'Paracetamol 500 mg',
        dosage: '1 เม็ด หลังอาหารเช้า',
        scheduledTime: at(8, 0),
      ),
      DoseSchedule(
        id: 'sch-2',
        prescriptionId: 'rx-2',
        medicationName: 'Amlodipine 5 mg',
        dosage: '1 เม็ด ก่อนนอน',
        scheduledTime: at(20, 0),
      ),
      DoseSchedule(
        id: 'sch-3',
        prescriptionId: 'rx-3',
        medicationName: 'Ibuprofen 400 mg',
        dosage: '1 เม็ด เมื่อมีอาการปวด',
        scheduledTime: now,
        isPrn: true,
      ),
    ];
  }

  @override
  Future<Result<List<DoseSchedule>>> getTodaySchedule(String patientId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return Success(List.unmodifiable(_schedule));
  }

  @override
  Future<Result<DoseLog>> logDose({
    required String scheduleId,
    required DateTime scheduledAt,
    required DoseStatus status,
  }) async {
    final log = DoseLog(
      id: 'log-${_logs.length + 1}',
      scheduleId: scheduleId,
      scheduledAt: scheduledAt,
      status: status,
      actionedAt: DateTime.now(),
    );
    _logs.add(log);
    return Success(log);
  }

  @override
  Future<Result<double>> getAdherenceRate({
    required String patientId,
    required DateTime from,
    required DateTime to,
  }) async {
    return const Success(0.86);
  }
}
