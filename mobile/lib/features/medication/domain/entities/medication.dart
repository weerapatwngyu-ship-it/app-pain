/// A medication on a patient's list, with the times it is due.
class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.startDate,
    required this.times,
    this.endDate,
    this.enteredBySelf = true,
    this.stopReason,
  });

  final String id;
  final String name;

  /// Free text, e.g. "500 mg" or "1 เม็ด".
  final String dosage;

  /// Free text describing how often, e.g. "วันละ 3 ครั้ง".
  final String frequency;

  final DateTime startDate;
  final DateTime? endDate;

  /// `HH:mm` in ascending order.
  final List<String> times;

  /// False when a clinician entered it. Those are read-only to the patient —
  /// the backend refuses the write, so the UI should not offer it.
  final bool enteredBySelf;

  /// 'recovered' | 'other', or null while it is still running. Set when the
  /// medication was stopped, so the list can say why rather than only that it
  /// ended.
  final String? stopReason;

  /// Stopped because the patient got better. Shown as "หายแล้ว".
  bool get stoppedRecovered => !isActive && stopReason == 'recovered';

  bool get isActive {
    final end = endDate;
    if (end == null) return true;
    final today = DateTime.now();
    return !end.isBefore(DateTime(today.year, today.month, today.day));
  }

  factory Medication.fromRow(Map<String, dynamic> row) {
    final schedules = (row['dose_schedules'] as List?) ?? const [];
    final times = schedules
        .map((entry) => (entry as Map)['scheduled_time'].toString())
        // Postgres `time` comes back as HH:mm:ss; the seconds are always zero
        // here and only add noise on screen.
        .map((value) => value.length >= 5 ? value.substring(0, 5) : value)
        .toList()
      ..sort();

    return Medication(
      id: row['id'] as String,
      name: row['medication_name'] as String? ?? '',
      dosage: row['dosage'] as String? ?? '',
      frequency: row['frequency'] as String? ?? '',
      startDate: DateTime.parse(row['start_date'] as String),
      endDate: row['end_date'] == null
          ? null
          : DateTime.parse(row['end_date'] as String),
      times: times,
      enteredBySelf: (row['source'] as String? ?? 'clinician') == 'self',
      stopReason: row['stop_reason'] as String?,
    );
  }
}
