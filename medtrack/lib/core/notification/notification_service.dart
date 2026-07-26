import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Wraps on-device notifications used for dose reminders. Local
/// notifications are the primary channel (per the offline-first
/// strategy in the architecture doc) — push (FCM/APNs) is layered on
/// top for server-triggered alerts and is wired in a later phase.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const _doseChannel = AndroidNotificationDetails(
    'dose_reminders',
    'แจ้งเตือนกินยา',
    channelDescription: 'แจ้งเตือนตามตารางยาของผู้ป่วย',
    importance: Importance.max,
    priority: Priority.high,
  );

  Future<void> init() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      ),
    );
  }

  Future<void> scheduleDoseReminder({
    required int id,
    required String medicationName,
    required String dosage,
    required DateTime scheduledAt,
  }) async {
    await _plugin.zonedSchedule(
      id,
      'ถึงเวลากินยา: $medicationName',
      'ขนาดยา: $dosage',
      _toTZDateTime(scheduledAt),
      NotificationDetails(
        android: _doseChannel,
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  // Placeholder conversion — wire `timezone` package init in app bootstrap
  // and replace with `tz.TZDateTime.from(scheduledAt, tz.local)`.
  dynamic _toTZDateTime(DateTime dateTime) => dateTime;
}
