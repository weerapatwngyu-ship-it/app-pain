import 'dart:io';

import 'package:sqflite/sqflite.dart' show ConflictAlgorithm;

import '../../../core/notification/notification_service.dart';
import '../../../core/storage/local_database.dart';
import '../../medication/domain/entities/dose_schedule_item.dart';
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

  // ------------------------------------------------------- doctor's schedule

  /// Base for the ids of prescription reminders.
  ///
  /// Their id is derived from the time rather than handed out by SQLite, so
  /// that re-syncing the same schedule produces the same row every time. The
  /// Android service remembers which id has already rung today, and an id that
  /// changed on each sync would let this morning's dose ring again the moment
  /// the schedule was refreshed. Far above any autoincremented id, and below
  /// the 999xxx block the self-test notifications use.
  static const _prescriptionIdBase = 800000;

  static int _prescriptionId(int hour, int minute) =>
      _prescriptionIdBase + hour * 60 + minute;

  /// Rebuilds the reminders that mirror the doctor's dose schedule.
  ///
  /// The patient no longer enters their own medication — the doctor prescribes
  /// it — so making them retype every time as an alarm would be asking them to
  /// copy out a schedule they were already given, and any typo in the copy is
  /// a dose at the wrong hour. These rows are generated instead, and are
  /// rebuilt from [items] on every call so a stopped medication stops ringing.
  ///
  /// Doses that fall at the same time become one reminder, not several: three
  /// insistent alarms going off together at 08:00 is not three times the
  /// reminder, it is noise, and the patient answers them all with one action
  /// anyway.
  ///
  /// Reminders the patient typed themselves are left alone.
  Future<void> syncFromSchedule(List<DoseScheduleItem> items) async {
    final db = await LocalDatabase.instance.database;

    // Grouped by time-of-day, in the order they come due.
    final byMinute = <int, List<DoseScheduleItem>>{};
    for (final item in items) {
      // A PRN ("เมื่อมีอาการ") dose is taken when it is needed, not on the
      // clock, so ringing for it would be telling the patient to take
      // something the prescription says to decide about themselves.
      if (item.isPrn) continue;
      final time = _parseTime(item.scheduledTime);
      if (time == null) continue;
      byMinute.putIfAbsent(time.$1 * 60 + time.$2, () => []).add(item);
    }

    final existing = await db.query(
      'medication_reminders',
      where: 'source = ?',
      whereArgs: [ReminderSource.prescription.name],
    );
    final existingById = {
      for (final row in existing)
        row['id'] as int: MedicationReminder.fromRow(row),
    };

    final wanted = <int, MedicationReminder>{};
    for (final entry in byMinute.entries) {
      final hour = entry.key ~/ 60;
      final minute = entry.key % 60;
      final id = _prescriptionId(hour, minute);
      wanted[id] = MedicationReminder(
        id: id,
        label: _label(entry.value),
        hour: hour,
        minute: minute,
        // Every day: the schedule query already drops a prescription that has
        // not started or has ended, so "which days" is answered by whether the
        // dose is in [items] at all.
        days: const {1, 2, 3, 4, 5, 6, 7},
        // A patient who switched this off keeps it off. The doctor decides
        // what to take and when; whether the phone makes a noise about it at
        // 06:00 is the patient's to decide.
        enabled: existingById[id]?.enabled ?? true,
        source: ReminderSource.prescription,
        scheduleIds: [for (final item in entry.value) item.scheduleId],
      );
    }

    for (final id in existingById.keys) {
      if (!wanted.containsKey(id)) {
        await db.delete('medication_reminders', where: 'id = ?', whereArgs: [id]);
        await _cancelAll(id);
      }
    }
    for (final reminder in wanted.values) {
      // insert-or-replace rather than update: the row may be new, and the id
      // is ours to set either way.
      await db.insert(
        'medication_reminders',
        reminder.toRow(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await _reschedule(reminder);
    }

    await _syncWatchService();
  }

  /// "ยาความดัน 1 เม็ด" — or the names joined, when several fall together.
  static String _label(List<DoseScheduleItem> items) {
    if (items.length == 1) {
      final item = items.first;
      return [item.medicationName, item.dosage]
          .where((part) => part.trim().isNotEmpty)
          .join(' ');
    }
    return items.map((item) => item.medicationName).join(' · ');
  }

  /// 'HH:mm' or 'HH:mm:ss' as Postgres returns it.
  static (int, int)? _parseTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return (hour, minute);
  }

  /// Doses answered with "กินแล้ว" from the notification itself, taken out of
  /// the platform's hands and translated back into schedule ids.
  ///
  /// Each mark names a reminder and the moment it was answered; a reminder
  /// covering three medications yields three doses, since one tap at 08:00
  /// answers for everything due then. Draining is destructive on the platform
  /// side, so whatever this returns must be recorded by the caller.
  Future<List<TakenDose>> drainTakenDoses() async {
    final marks = await ReminderWatchService.drainTaken();
    if (marks.isEmpty) return const [];

    final byId = {for (final reminder in await all()) reminder.id: reminder};
    final doses = <TakenDose>[];
    for (final mark in marks) {
      final reminder = byId[mark.reminderId];
      if (reminder == null) continue;
      for (final scheduleId in reminder.scheduleIds) {
        doses.add(TakenDose(scheduleId: scheduleId, at: mark.at));
      }
    }
    return doses;
  }

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
  Future<void> _syncWatchService() async {
    await ReminderWatchService.sync(await all());
  }

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

/// One dose the patient confirmed from the notification, before it has been
/// turned into a dose log.
class TakenDose {
  const TakenDose({required this.scheduleId, required this.at});

  final String scheduleId;

  /// When the patient pressed the button, not when the app got around to
  /// reading it — the two can be hours apart if the phone was never opened.
  final DateTime at;
}
