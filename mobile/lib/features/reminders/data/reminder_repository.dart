import 'dart:io';

import '../../../core/notification/notification_service.dart';
import '../../../core/storage/local_database.dart';
import '../domain/entities/medication_reminder.dart';
import 'reminder_watch_service.dart';

/// Stores reminders and keeps the scheduled notifications in step with them.
///
/// Every write goes through here rather than letting the UI touch the
/// notification plugin directly: a row that says 08:00 daily while no alarm is
/// actually scheduled looks completely fine on screen and simply never fires.
class ReminderRepository {
  final _notifications = NotificationService.instance;

  /// A reminder that repeats needs one scheduled notification per weekday,
  /// so each row reserves a block of ids: `id * 10` for the one-off/daily
  /// case and `id * 10 + weekday` for the weekly ones.
  static const _idsPerReminder = 10;

  int _notificationId(int reminderId, [int weekday = 0]) =>
      reminderId * _idsPerReminder + weekday;

  Future<List<MedicationReminder>> all() async {
    final db = await LocalDatabase.instance.database;
    final rows = await db.query(
      'medication_reminders',
      orderBy: 'hour, minute',
    );
    return rows.map(MedicationReminder.fromRow).toList();
  }

  Future<MedicationReminder> save(MedicationReminder reminder) async {
    final db = await LocalDatabase.instance.database;

    final MedicationReminder saved;
    if (reminder.id == 0) {
      final id = await db.insert('medication_reminders', reminder.toRow());
      saved = reminder.copyWith(id: id);
    } else {
      await db.update(
        'medication_reminders',
        reminder.toRow(),
        where: 'id = ?',
        whereArgs: [reminder.id],
      );
      saved = reminder;
    }

    await _reschedule(saved);
    await _syncWatchService();
    return saved;
  }

  Future<void> delete(int id) async {
    final db = await LocalDatabase.instance.database;
    await db.delete('medication_reminders', where: 'id = ?', whereArgs: [id]);
    await _cancelAll(id);
    await _syncWatchService();
  }

  Future<MedicationReminder> setEnabled(
    MedicationReminder reminder,
    bool enabled,
  ) =>
      save(reminder.copyWith(enabled: enabled));

  /// Re-applies every alarm the device should be holding.
  ///
  /// Android drops all scheduled alarms when the device reboots, and there is
  /// no reboot receiver wired up here, so the reminders would quietly stop
  /// until the row was edited. Calling this each time the screen opens is the
  /// cheap way to heal that.
  Future<void> rescheduleAll() async {
    for (final reminder in await all()) {
      await _reschedule(reminder);
    }
    await _syncWatchService();
  }

  /// Keeps the Android service's copy of the reminders current.
  Future<void> _syncWatchService() => ReminderWatchService.sync(await all());

  Future<void> _reschedule(MedicationReminder reminder) async {
    // Always cancel, on every platform. Builds before the service existed
    // scheduled these, and leaving them registered would ring a second time
    // next to whatever the service does.
    await _cancelAll(reminder.id);

    // On Android the foreground service owns the ringing outright. Scheduling
    // here as well would mean two alarms for one reminder on any device where
    // the plugin path does work — and where it does not, which is the case
    // this was all built for, it adds nothing.
    if (Platform.isAndroid) return;

    if (!reminder.enabled) return;

    final body = reminder.label.trim().isEmpty ? 'ถึงเวลากินยาแล้ว' : reminder.label;

    if (reminder.isOneOff) {
      await _notifications.scheduleOnce(
        id: _notificationId(reminder.id),
        body: body,
        hour: reminder.hour,
        minute: reminder.minute,
      );
      return;
    }

    if (reminder.isEveryDay) {
      await _notifications.scheduleDaily(
        id: _notificationId(reminder.id),
        body: body,
        hour: reminder.hour,
        minute: reminder.minute,
      );
      return;
    }

    for (final weekday in reminder.days) {
      await _notifications.scheduleWeekly(
        id: _notificationId(reminder.id, weekday),
        body: body,
        hour: reminder.hour,
        minute: reminder.minute,
        weekday: weekday,
      );
    }
  }

  /// Clears the whole id block, since the reminder may have been daily before
  /// this edit and weekly after it.
  Future<void> _cancelAll(int reminderId) async {
    for (var offset = 0; offset < _idsPerReminder; offset++) {
      await _notifications.cancel(_notificationId(reminderId, offset));
    }
  }
}
