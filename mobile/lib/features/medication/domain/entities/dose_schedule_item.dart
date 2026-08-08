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
