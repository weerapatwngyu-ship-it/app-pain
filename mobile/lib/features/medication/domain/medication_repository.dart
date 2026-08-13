import 'entities/dose_log.dart';
import 'entities/dose_schedule_item.dart';

abstract class MedicationRepository {
  Future<List<DoseScheduleItem>> todaySchedule(String patientId);

  Future<void> logDose(DoseLog log);

  /// Which of [scheduleIds] already have a log recorded today.
  ///
  /// Without this the screen only knew what had been ticked since it opened,
  /// so closing the app appeared to erase the morning's doses and invited the
  /// patient to take them twice.
  Future<Set<String>> loggedToday(List<String> scheduleIds);

  /// Pushes doses that were recorded while offline to the backend.
  ///
  /// Part of the contract rather than an implementation detail: a dose the
  /// patient confirmed from a notification is written to the local queue by
  /// whatever was awake at the time, and stays there — invisible to the
  /// doctor — until something calls this.
  Future<void> syncPending();
}
