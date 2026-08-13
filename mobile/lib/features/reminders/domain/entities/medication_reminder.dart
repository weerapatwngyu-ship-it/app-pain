/// Where a reminder came from.
enum ReminderSource {
  /// Typed by the patient on the reminders screen.
  self,

  /// Mirrored from a doctor's dose schedule. The patient does not own the
  /// time — the prescription does — so these are rebuilt on every sync and
  /// cannot be edited or deleted here.
  prescription;

  static ReminderSource parse(String? raw) =>
      raw == 'prescription' ? ReminderSource.prescription : ReminderSource.self;
}

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
    this.source = ReminderSource.self,
    this.scheduleIds = const [],
  });

  final int id;
  final String label;
  final int hour;
  final int minute;

  final ReminderSource source;

  /// The dose_schedules rows this reminder rings for, empty for a self-made
  /// one. Several medications can fall on the same time, so answering
  /// "กินแล้ว" once records a dose against every id here.
  final List<String> scheduleIds;

  bool get fromDoctor => source == ReminderSource.prescription;

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

  /// When this will next go off.
  ///
  /// Deliberately mirrors NotificationService._nextInstanceOf: that one works
  /// in the pinned Asia/Bangkok zone and this one in device-local time, which
  /// agree for a phone in Thailand. They have to stay in step — a countdown
  /// that disagrees with the alarm is worse than no countdown, so change both
  /// together.
  DateTime nextOccurrence([DateTime? from]) {
    final now = from ?? DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);

    if (isOneOff || isEveryDay) {
      if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
      return next;
    }
    while (!days.contains(next.weekday) || !next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    return next;
  }

  /// "อีก 2 ชั่วโมง 15 นาที" — the phone's own clock app says this when an
  /// alarm is set, and without it a time entered for the current minute looks
  /// broken rather than scheduled for tomorrow.
  String countdownLabel([DateTime? from]) {
    final now = from ?? DateTime.now();
    final left = nextOccurrence(now).difference(now);
    // Not `days` — that is the weekday set on this class, and shadowing it
    // here would read as if the countdown depended on it.
    final daysLeft = left.inDays;
    final hours = left.inHours % 24;
    final minutes = left.inMinutes % 60;

    if (daysLeft > 0) return 'จะเตือนในอีก $daysLeft วัน $hours ชั่วโมง';
    if (hours > 0) return 'จะเตือนในอีก $hours ชั่วโมง $minutes นาที';
    if (minutes > 0) return 'จะเตือนในอีก $minutes นาที';
    return 'จะเตือนในไม่ถึง 1 นาที';
  }

  MedicationReminder copyWith({
    int? id,
    String? label,
    int? hour,
    int? minute,
    Set<int>? days,
    bool? enabled,
    ReminderSource? source,
    List<String>? scheduleIds,
  }) {
    return MedicationReminder(
      id: id ?? this.id,
      label: label ?? this.label,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      days: days ?? this.days,
      enabled: enabled ?? this.enabled,
      source: source ?? this.source,
      scheduleIds: scheduleIds ?? this.scheduleIds,
    );
  }

  Map<String, Object?> toRow() => {
        if (id != 0) 'id': id,
        'label': label,
        'hour': hour,
        'minute': minute,
        'days': (days.toList()..sort()).join(','),
        'enabled': enabled ? 1 : 0,
        'source': source.name,
        'schedule_ids': scheduleIds.join(','),
      };

  factory MedicationReminder.fromRow(Map<String, Object?> row) {
    final raw = (row['days'] as String?) ?? '';
    final schedules = (row['schedule_ids'] as String?) ?? '';
    return MedicationReminder(
      id: row['id'] as int,
      label: (row['label'] as String?) ?? '',
      hour: row['hour'] as int,
      minute: row['minute'] as int,
      days: raw.isEmpty
          ? <int>{}
          : raw.split(',').map(int.parse).toSet(),
      enabled: (row['enabled'] as int? ?? 1) == 1,
      source: ReminderSource.parse(row['source'] as String?),
      scheduleIds: schedules.isEmpty ? const [] : schedules.split(','),
    );
  }
}
