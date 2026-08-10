import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// What the OS currently allows, and what it is actually holding for us.
///
/// Worth surfacing rather than assuming: the app asks for permission and, if
/// refused, still saves reminders and schedules alarms that silently never
/// arrive. Without this the screen looks identical whether it works or not.
class NotificationStatus {
  const NotificationStatus({
    required this.notificationsEnabled,
    required this.scheduledCount,
  });

  /// null when the platform cannot report it.
  final bool? notificationsEnabled;

  /// Alarms the OS is holding for this app. Reminders on screen but zero
  /// here means scheduling failed, which is a different fault from the OS
  /// muting a notification that did fire.
  final int scheduledCount;
}

/// Local notifications are the primary reminder channel (docs/architecture.md
/// §10) so dose reminders keep firing without depending on push connectivity.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Hardcoded rather than read from the device.
  ///
  /// zonedSchedule needs a named zone, and resolving the device's own name
  /// means another plugin (flutter_timezone). This app is Thailand-only, so
  /// the trade is: someone who travels abroad keeps getting reminded on
  /// Bangkok time. For a medication schedule set by a Thai doctor that is
  /// arguably the right behaviour anyway.
  static const _timeZone = 'Asia/Bangkok';

  /// Note the "_v2": Android creates a notification channel the first time an
  /// id is used and then treats its importance, sound and vibration as the
  /// user's to change, not the app's. Anything set here is ignored for a
  /// channel that already exists — which is why reminders arrived silently
  /// after the first build created the channel. Bumping the id is the only
  /// way to hand the OS a channel with these settings.
  ///
  /// If these ever change again, bump the suffix again.
  static final _doseReminderChannel = AndroidNotificationDetails(
    'dose_reminders_v2',
    'เตือนกินยา',
    channelDescription: 'แจ้งเตือนเมื่อถึงเวลากินยา',
    importance: Importance.max,
    priority: Priority.high,
    category: AndroidNotificationCategory.alarm,
    // Spelled out rather than left to the defaults, so the channel is created
    // with them and a later reading of this code does not have to guess.
    playSound: true,
    enableVibration: true,
    vibrationPattern: Int64List.fromList(<int>[0, 500, 250, 500, 250, 500]),
    // Routes the sound to the alarm stream. A dose reminder that loses to a
    // lowered notification volume, or to a Do Not Disturb rule that still
    // lets alarms through, is not doing its job.
    audioAttributesUsage: AudioAttributesUsage.alarm,
    enableLights: true,
  );

  /// iOS-only: how a scheduled date is read against the device clock.
  /// Required on every zonedSchedule call in this package version, so it is
  /// named here once rather than repeated as a bare literal.
  static const _dateInterpretation =
      UILocalNotificationDateInterpretation.absoluteTime;

  // Not const: the channel carries a vibration pattern, which is a runtime
  // list.
  static final _details = NotificationDetails(
    android: _doseReminderChannel,
    iOS: const DarwinNotificationDetails(),
  );

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_timeZone));

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  /// Asks for the two things Android 13+ needs before a timed reminder can
  /// actually fire: permission to post notifications at all, and permission
  /// to schedule an exact alarm. Called when the user first opens the
  /// reminders screen rather than at launch, so the prompt arrives with some
  /// context instead of on a cold start.
  Future<void> requestPermissions() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<NotificationStatus> status() async {
    await init();
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final enabled = await android?.areNotificationsEnabled();
    final pending = await _plugin.pendingNotificationRequests();
    return NotificationStatus(
      notificationsEnabled: enabled,
      scheduledCount: pending.length,
    );
  }

  /// Fires immediately, to separate "notifications are blocked" from
  /// "scheduling is broken" — two failures that look the same from the
  /// reminders list.
  Future<void> showTestNotification() async {
    await init();
    await _plugin.show(
      _testNotificationId,
      'ทดสอบการแจ้งเตือน',
      'ถ้าเห็นข้อความนี้ แปลว่าการแจ้งเตือนของแอปทำงานปกติ',
      _details,
    );
  }

  /// Well above the ids reminders use (reminderId * 10 + weekday), so a test
  /// cannot collide with a real alarm.
  static const _testNotificationId = 999000;

  /// Schedules a notification [seconds] from now through the same path a real
  /// reminder takes.
  ///
  /// showTestNotification() posts directly and proves only that notifications
  /// are allowed. This goes through AlarmManager, so if it arrives the whole
  /// scheduling pipeline works and a reminder that still fails is being
  /// stopped by the OS between the alarm and the app — which on MIUI means
  /// the app was killed and not allowed to restart.
  Future<void> scheduleTestIn({int seconds = 15}) async {
    await init();
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    await _plugin.zonedSchedule(
      _testScheduledId,
      'ทดสอบการตั้งเวลา',
      'ตั้งไว้ $seconds วินาทีที่แล้ว — ถ้าเห็นข้อความนี้ การตั้งเวลาทำงานปกติ',
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: _dateInterpretation,
    );
  }

  static const _testScheduledId = 999001;

  Future<void> showDoseReminder({
    required int id,
    required String medicationName,
  }) async {
    await init();
    await _plugin.show(id, 'ถึงเวลากินยา', medicationName, _details);
  }

  /// Fires once, at the next occurrence of [hour]:[minute].
  Future<void> scheduleOnce({
    required int id,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id,
      'ถึงเวลากินยา',
      body,
      _nextInstanceOf(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: _dateInterpretation,
    );
  }

  /// Repeats every day at [hour]:[minute].
  Future<void> scheduleDaily({
    required int id,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id,
      'ถึงเวลากินยา',
      body,
      _nextInstanceOf(hour, minute),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: _dateInterpretation,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  /// Repeats weekly on [weekday] (1 = Monday … 7 = Sunday, matching
  /// DateTime.weekday).
  Future<void> scheduleWeekly({
    required int id,
    required String body,
    required int hour,
    required int minute,
    required int weekday,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id,
      'ถึงเวลากินยา',
      body,
      _nextInstanceOf(hour, minute, weekday: weekday),
      _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: _dateInterpretation,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  Future<void> cancel(int id) => _plugin.cancel(id);

  /// The next time today's clock reads [hour]:[minute] — tomorrow if that
  /// moment has already passed, or the next [weekday] when one is given.
  tz.TZDateTime _nextInstanceOf(int hour, int minute, {int? weekday}) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (weekday != null) {
      // Both conditions matter: the right weekday, and still in the future.
      // A reminder set for 08:00 Monday while it is 09:00 Monday belongs to
      // next Monday, not this one.
      while (scheduled.weekday != weekday || !scheduled.isAfter(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
    } else if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
