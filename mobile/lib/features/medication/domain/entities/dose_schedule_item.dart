class DoseScheduleItem {
  const DoseScheduleItem({
    required this.scheduleId,
    required this.medicationName,
    required this.dosage,
    required this.scheduledTime,
    required this.isPrn,
  });

  final String scheduleId;
  final String medicationName;
  final String dosage;
  final String scheduledTime;
  final bool isPrn;

  /// Minutes past midnight, or null if `scheduled_time` was not parseable.
  /// Null for a PRN dose is meaningless anyway — it has no due time.
  int? get minuteOfDay {
    final parts = scheduledTime.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return hour * 60 + minute;
  }

  /// When today's instance of this dose was due.
  ///
  /// A dose log has to record the slot it answers, not the moment the button
  /// was pressed — otherwise a dose taken four hours late is indistinguishable
  /// from one taken on time, and a slot nobody answered cannot be named at all.
  DateTime? dueAt(DateTime day) {
    final minutes = minuteOfDay;
    if (minutes == null) return null;
    return DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);
  }

  /// True once the due time has passed by more than [grace].
  ///
  /// The grace window exists so a dose does not turn red the minute its time
  /// ticks over — someone who takes their 08:00 tablet at 08:20 is not a
  /// patient falling behind.
  bool isOverdue(DateTime now, {Duration grace = const Duration(hours: 1)}) {
    if (isPrn) return false;
    final due = dueAt(now);
    if (due == null) return false;
    return now.isAfter(due.add(grace));
  }

  /// Row from `dose_schedules` with its `prescriptions` relation embedded.
  factory DoseScheduleItem.fromRow(Map<String, dynamic> row) {
    final prescription = row['prescriptions'] as Map<String, dynamic>? ?? const {};
    return DoseScheduleItem(
      scheduleId: row['id'] as String,
      medicationName: prescription['medication_name'] as String? ?? '',
      dosage: prescription['dosage'] as String? ?? '',
      scheduledTime: row['scheduled_time'] as String,
      isPrn: row['is_prn'] as bool? ?? false,
    );
  }
}
