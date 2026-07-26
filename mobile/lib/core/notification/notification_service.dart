import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local notifications are the primary reminder channel (docs/architecture.md
/// §10) so dose reminders keep firing without depending on push connectivity.
///
/// Exact-time scheduling additionally needs the `timezone` package
/// initialized with the device's local zone before `zonedSchedule` can be
/// used — left as a follow-up once the mobile toolchain is set up.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _doseReminderChannel = AndroidNotificationDetails(
    'dose_reminders',
    'Dose Reminders',
    importance: Importance.high,
    priority: Priority.high,
  );

  Future<void> init() async {
    if (_initialized) return;
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  Future<void> showDoseReminder({
    required int id,
    required String medicationName,
  }) async {
    await _plugin.show(
      id,
      'ถึงเวลากินยา',
      medicationName,
      const NotificationDetails(
        android: _doseReminderChannel,
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
