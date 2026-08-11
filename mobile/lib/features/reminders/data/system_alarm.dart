import 'package:flutter/services.dart';

import '../domain/entities/medication_reminder.dart';

/// Creates the reminder as an alarm in the phone's own clock app.
///
/// This exists because the app's own scheduled notifications cannot be relied
/// on: the device decides whether to wake the app when an alarm is due, and on
/// MIUI it frequently decides not to, silently. The clock app is a system app
/// and is not subject to that, so handing the time over is the one route that
/// is certain to ring.
///
/// What it costs: the alarm then belongs to the clock app. Editing or deleting
/// the reminder here will not change it there — Android offers no way to
/// modify an alarm another app owns. So this is offered as an explicit action
/// rather than done automatically on save.
class SystemAlarm {
  static const _channel = MethodChannel('medigo/system_alarm');

  /// Returns false when no clock app accepted it.
  static Future<bool> create(MedicationReminder reminder) async {
    final label = reminder.label.trim().isEmpty
        ? 'ถึงเวลากินยา'
        : 'กินยา: ${reminder.label.trim()}';

    final result = await _channel.invokeMethod<bool>('setAlarm', {
      'hour': reminder.hour,
      'minute': reminder.minute,
      'label': label,
      // The clock app wants java.util.Calendar day numbers, where Sunday is 1
      // and Saturday is 7. MedicationReminder.days follows DateTime.weekday,
      // where Monday is 1 and Sunday is 7.
      'days': (reminder.days.toList()..sort())
          .map((weekday) => (weekday % 7) + 1)
          .toList(),
    });
    return result ?? false;
  }
}
