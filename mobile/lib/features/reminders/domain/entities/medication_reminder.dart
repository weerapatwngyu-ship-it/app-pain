/// One "กินยาตอนนี้" alarm, modelled on the phone's own clock app.
///
/// Stored on the device rather than in Supabase on purpose: the notification
/// that fires is a local one, so a reminder that lived only on the server
/// would go silent the moment the phone lost signal — which is exactly when a
/// medication reminder matters most.
class MedicationReminder {
  const MedicationReminder({
    required this.id,
    required this.label,
    required this.hour,
    required this.minute,
    required this.days,
    required this.enabled,
  });

  final int id;
  final String label;
  final int hour;
  final int minute;

  /// Weekdays this repeats on, 1 = Monday … 7 = Sunday (matching
  /// DateTime.weekday). Empty means it fires once and then stops.
  final Set<int> days;

  final bool enabled;

  bool get isOneOff => days.isEmpty;
  bool get isEveryDay => days.length == 7;

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get repeatLabel {
    if (isOneOff) return 'ดังครั้งเดียว';
    if (isEveryDay) return 'ทุกวัน';
    const names = {1: 'จ.', 2: 'อ.', 3: 'พ.', 4: 'พฤ.', 5: 'ศ.', 6: 'ส.', 7: 'อา.'};
    final sorted = days.toList()..sort();
    if (sorted.length == 5 && sorted.every((d) => d <= 5)) return 'จ. ถึง ศ.';
    return sorted.map((d) => names[d]).join(' ');
  }

  MedicationReminder copyWith({
    int? id,
    String? label,
    int? hour,
    int? minute,
    Set<int>? days,
    bool? enabled,
  }) {
    return MedicationReminder(
      id: id ?? this.id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      days: days ?? this.days,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, Object?> toRow() => {
        if (id != 0) 'id': id,
        'label': label,
        'hour': hour,
        'minute': minute,
        'days': (days.toList()..sort()).join(','),
        'enabled': enabled ? 1 : 0,
      };

  factory MedicationReminder.fromRow(Map<String, Object?> row) {
    final raw = (row['days'] as String?) ?? '';
    return MedicationReminder(
      id: row['id'] as int,
      label: (row['label'] as String?) ?? '',
      hour: row['hour'] as int,
      minute: row['minute'] as int,
      days: raw.isEmpty
          ? <int>{}
          : raw.split(',').map(int.parse).toSet(),
      enabled: (row['enabled'] as int? ?? 1) == 1,
    );
  }
}
