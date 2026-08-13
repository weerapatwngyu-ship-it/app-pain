import 'dart:convert';

import 'local_database.dart';

/// Turns a "ทานยาแล้ว" tapped on a notification into queued dose logs.
///
/// Used by the notification plugin's own reminders — the path iOS takes, and
/// the one older Android builds took. Android's foreground service records its
/// presses on the platform side instead, because the button there is answered
/// with no Dart process running at all.
///
/// Writing to the sync queue rather than to Supabase is the whole point: this
/// runs from a notification callback, where the network may be down and the
/// app may not even be open. MedicationRepositoryImpl.syncPending drains it,
/// and the home screen already reads the queue when deciding which doses are
/// ticked, so the dose shows as taken before it has reached the server.
///
/// [notificationId] is the id the reminder was scheduled under, which
/// ReminderRepository builds as `reminderId * 10 + weekday`.
Future<void> recordTakenFromNotification(int notificationId) async {
  final reminderId = notificationId ~/ 10;
  final db = await LocalDatabase.instance.database;

  final rows = await db.query(
    'medication_reminders',
    columns: ['schedule_ids'],
    where: 'id = ?',
    whereArgs: [reminderId],
    limit: 1,
  );
  if (rows.isEmpty) return;

  final raw = (rows.first['schedule_ids'] as String?) ?? '';
  if (raw.isEmpty) return;

  final at = DateTime.now();
  for (final scheduleId in raw.split(',')) {
    if (scheduleId.isEmpty) continue;
    await LocalDatabase.instance.enqueue(
      // Keyed by dose and minute rather than randomly: a notification that
      // manages to deliver the same press twice then replaces its own row
      // instead of logging the dose twice.
      'taken-$scheduleId-${at.millisecondsSinceEpoch ~/ 60000}',
      'dose_log',
      jsonEncode({
        'schedule_id': scheduleId,
        'scheduled_at': at.toIso8601String(),
        'actioned_at': at.toIso8601String(),
        'status': 'taken',
      }),
    );
  }
}
