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
/// What the native side found and did while trying to hand a reminder to a
/// clock app. Kept detailed (not just a bool) because the handoff has failed
/// silently before, and a plain true/false gives nothing to diagnose from.
class SystemAlarmResult {
  const SystemAlarmResult({
    required this.launched,
    required this.resolvedCount,
    required this.triedPackages,
    this.lastError,
  });

  /// Whether some activity actually started.
  final bool launched;

  /// How many activities the OS found for the implicit SET_ALARM intent
  /// before any package-specific fallback was tried. Zero here, alongside
  /// [launched] also false, means the phone genuinely has no app that
  /// declares it can handle SET_ALARM the standard way.
  final int resolvedCount;

  /// Package names tried directly after implicit resolution found nothing
  /// (or failed to launch).
  final List<String> triedPackages;

  final String? lastError;
}

class SystemAlarm {
  static const _channel = MethodChannel('medigo/system_alarm');

  static Future<SystemAlarmResult> create(MedicationReminder reminder) async {
    final label = reminder.label.trim().isEmpty
        ? 'ถึงเวลากินยา'
        : 'กินยา: ${reminder.label.trim()}';

    final result = await _channel.invokeMapMethod<String, Object?>('setAlarm', {
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

    if (result == null) {
      return const SystemAlarmResult(
        launched: false,
        resolvedCount: 0,
        triedPackages: [],
      );
    }
    return SystemAlarmResult(
      launched: result['launched'] as bool? ?? false,
      resolvedCount: result['resolvedCount'] as int? ?? 0,
      triedPackages: (result['triedPackages'] as List?)?.cast<String>() ?? const [],
      lastError: result['lastError'] as String?,
    );
  }
}
