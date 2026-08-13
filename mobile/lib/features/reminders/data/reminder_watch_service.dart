import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/entities/medication_reminder.dart';

/// Hands the reminder list to the Android service that actually rings them.
///
/// The app used to schedule each reminder with the system and wait to be woken
/// when it came due. On the devices this app is used on that wake-up never
/// arrived — the in-app check screen showed alarms still registered long after
/// their time had passed, which means they were never delivered rather than
/// delivered and silenced. The app's process had been killed, and a killed
/// process cannot be woken by anything.
///
/// So the deciding moved to a foreground service, which keeps the process
/// alive and watches the clock itself. Dart no longer decides when a reminder
/// rings; it only keeps the service's copy of the list up to date.
class ReminderWatchService {
  static const _channel = MethodChannel('medigo/reminder_service');

  /// iOS has no equivalent and does not need one — it delivers scheduled
  /// notifications reliably, so the plugin's own scheduling still applies
  /// there.
  static bool get _supported => Platform.isAndroid;

  /// Replaces the service's copy of the reminders. Call after every change.
  static Future<void> sync(List<MedicationReminder> reminders) async {
    if (!_supported) return;
    final payload = jsonEncode([
      for (final reminder in reminders)
        {
          'id': reminder.id,
          'label': reminder.label,
          'hour': reminder.hour,
          'minute': reminder.minute,
          'days': (reminder.days.toList()..sort()),
          'enabled': reminder.enabled,
        }
    ]);
    await _invoke('sync', payload);
  }

  /// Starts the service without changing the list — for app launch, where the
  /// stored reminders are already what the service should be watching.
  static Future<void> start() => _invoke('start', null);

  /// Takes the "กินแล้ว" presses the service has collected and clears them.
  ///
  /// The button is answered while the app is not running — that is the whole
  /// point of it — so the confirmation is parked on the platform side until
  /// there is a Dart process to hand it to. Destructive by design: the caller
  /// records what it gets, and a mark handed over twice would log the dose
  /// twice.
  static Future<List<TakenMark>> drainTaken() async {
    if (!_supported) return const [];
    String? raw;
    try {
      raw = await _channel.invokeMethod<String>('drainTaken');
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      // Older build without the action buttons in it.
      return const [];
    }
    if (raw == null || raw.isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final entry in decoded)
          if (entry is Map)
            TakenMark(
              reminderId: (entry['id'] as num?)?.toInt() ?? 0,
              at: DateTime.fromMillisecondsSinceEpoch(
                  (entry['at'] as num?)?.toInt() ?? 0),
            ),
      ];
    } on FormatException {
      return const [];
    }
  }

  /// Rings once after [seconds], through the same code a real reminder uses.
  static Future<void> test({int seconds = 30}) =>
      _invoke('test', <String, Object?>{'seconds': seconds});

  static Future<void> _invoke(String method, Object? arguments) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on PlatformException {
      // A reminder that cannot be handed over is still stored and still shown.
      // Failing the save over it would lose the user's input for no gain.
    } on MissingPluginException {
      // Older build without the service in it.
    }
  }
}

/// A "กินแล้ว" press, as the platform recorded it.
class TakenMark {
  const TakenMark({required this.reminderId, required this.at});

  final int reminderId;
  final DateTime at;
}
