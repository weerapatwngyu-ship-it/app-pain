import 'dart:typed_data';
import 'dart:ui' show DartPluginRegistrant;

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../storage/dose_action_inbox.dart';

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

  /// Bumped to _v3 with the alarm behaviour below.
  ///
  /// Android creates a notification channel the first time an id is used and
  /// from then on treats its importance, sound and vibration as the user's to
  /// change, not the app's — anything set here is ignored for a channel that
  /// already exists. Changing how a reminder behaves therefore means a new id.
  ///
  /// Built per call rather than held as a constant so [_iconAvailable] can
  /// drop the custom icon after one has been rejected.
  AndroidNotificationDetails _channel() => AndroidNotificationDetails(
        'dose_reminders_v3',
        'เตือนกินยา',
        channelDescription: 'ปลุกเมื่อถึงเวลากินยา',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.alarm,

        // Null falls back to the icon given to initialize(). See
        // res/drawable/ic_notification.xml and res/raw/keep.xml.
        icon: _iconAvailable ? '@drawable/ic_notification' : null,

        playSound: true,
        enableVibration: true,
        enableLights: true,
        // Long pattern, but a pattern alone still runs once and stops. What
        // makes it repeat is the insistent flag below.
        vibrationPattern:
            Int64List.fromList(<int>[0, 800, 400, 800, 400, 800, 400]),

        // FLAG_INSISTENT (0x00000004). Android repeats the sound and
        // vibration until the notification is dismissed or opened — the
        // difference between one buzz from inside a bag and an alarm that
        // waits to be dealt with. The plugin exposes no option for it, so it
        // goes through as a raw flag.
        additionalFlags: Int32List.fromList(<int>[4]),

        // Deliberately no fullScreenIntent. It made a due dose take over the
        // whole screen like the clock app's alarm, which is more than a
        // medication reminder should do — this arrives in the tray and as a
        // banner, the way a notification normally does. The insistent flag
        // above still keeps it buzzing until it is answered, so nothing is
        // lost by not seizing the display.

        // Tapping it stops the ringing. Insistent without this would keep
        // going after the patient had already acknowledged it.
        autoCancel: true,

        audioAttributesUsage: AudioAttributesUsage.alarm,

        // Two ways to answer without hunting for the app. Both stop the
        // ringing: cancelNotification defaults to true, and an insistent
        // notification buzzes until it is cancelled. "กินแล้ว" also records
        // the dose — same wording as the native reminder's button, since to
        // the patient they are the same button.
        actions: const <AndroidNotificationAction>[
          AndroidNotificationAction(_takenActionId, 'กินแล้ว'),
          AndroidNotificationAction(_snoozeActionId, 'เลื่อน 10 นาที'),
        ],
      );

  /// Cleared the first time Android rejects the custom icon.
  ///
  /// A missing drawable makes every post throw, so the alarm goes completely
  /// silent over what is a cosmetic detail — that already happened once, when
  /// the release build's resource shrinker stripped the icon. Losing the
  /// silhouette is an acceptable trade; losing the reminder is not.
  bool _iconAvailable = true;

  /// Runs [action], and retries once without the custom icon if that is what
  /// Android objected to.
  Future<void> _withIconFallback(Future<void> Function() action) async {
    try {
      await action();
    } on PlatformException catch (error) {
      if (error.code != 'invalid_icon' || !_iconAvailable) rethrow;
      _iconAvailable = false;
      await action();
    }
  }

  static const _takenActionId = 'taken';
  static const _snoozeActionId = 'snooze';

  /// Every schedule uses AndroidScheduleMode.alarmClock, which maps to
  /// AlarmManager.setAlarmClock() — the same call the phone's clock app makes.
  ///
  /// exactAllowWhileIdle was the earlier choice and it is a weaker promise:
  /// Android and, far more aggressively, MIUI still defer or drop it to save
  /// battery, which is consistent with reminders that were accepted by the
  /// system and then never arrived. setAlarmClock is the one delivery
  /// guarantee the platform does not throttle, because users notice when an
  /// alarm clock fails. The visible cost is the alarm icon Android shows in
  /// the status bar while one is pending.

  /// How long "เลื่อน 10 นาที" pushes the alarm back.
  static const snoozeDuration = Duration(minutes: 10);

  /// iOS-only: how a scheduled date is read against the device clock.
  /// Required on every zonedSchedule call in this package version, so it is
  /// named here once rather than repeated as a bare literal.
  static const _dateInterpretation =
      UILocalNotificationDateInterpretation.absoluteTime;

  NotificationDetails get _details => NotificationDetails(
        android: _channel(),
        iOS: const DarwinNotificationDetails(),
      );

  Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_timeZone));

    // Back to the launcher icon here. AndroidInitializationSettings resolves
    // this name while the app is starting, and a name it cannot resolve
    // throws — which took down main() before runApp() and left the app stuck
    // on the splash screen. The silhouette icon is still used, but as the
    // per-notification `icon:` on the channel, where it is resolved at post
    // time and a failure costs at most one notification.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: _handleResponse,
      // Runs in a separate isolate when the app is not in the foreground,
      // which is the usual case for an alarm. It shares no state with the
      // app, so it rebuilds what it needs from scratch.
      onDidReceiveBackgroundNotificationResponse: notificationBackgroundHandler,
    );
    _initialized = true;
  }

  static void _handleResponse(NotificationResponse response) {
    // Fire and forget in both branches: nothing on screen is waiting on these,
    // and a throw out of a notification callback helps no one.
    if (response.actionId == _snoozeActionId) {
      instance.snooze(response.id ?? 0);
    } else if (response.actionId == _takenActionId) {
      recordTakenFromNotification(response.id ?? 0);
    }
  }

  /// Re-arms [id] one snooze away. Used by both isolates.
  Future<void> snooze(int id) async {
    await init();
    await _withIconFallback(() => _plugin.zonedSchedule(
        id,
        'ถึงเวลากินยา',
        'เลื่อนมาจากรอบก่อนหน้า',
        tz.TZDateTime.now(tz.local).add(snoozeDuration),
        _details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: _dateInterpretation,
        ));
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

  /// The alarms the OS is holding, in full.
  ///
  /// [status] only counts them; this is for the diagnostics screen, where the
  /// question is which specific alarm is or is not still pending.
  Future<List<PendingNotificationRequest>> pending() async {
    await init();
    return _plugin.pendingNotificationRequests();
  }

  /// Fires immediately, to separate "notifications are blocked" from
  /// "scheduling is broken" — two failures that look the same from the
  /// reminders list.
  Future<void> showTestNotification() async {
    await init();
    await _withIconFallback(() => _plugin.show(
          _testNotificationId,
          'ทดสอบการแจ้งเตือน',
          'ถ้าเห็นข้อความนี้ แปลว่าการแจ้งเตือนของแอปทำงานปกติ',
          _details,
        ));
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
    await _withIconFallback(() => _plugin.zonedSchedule(
        _testScheduledId,
        'ทดสอบการตั้งเวลา',
        'ตั้งไว้ $seconds วินาทีที่แล้ว — ถ้าเห็นข้อความนี้ การตั้งเวลาทำงานปกติ',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: _dateInterpretation,
        ));
  }

  static const _testScheduledId = 999001;

  Future<void> showDoseReminder({
    required int id,
    required String medicationName,
  }) async {
    await init();
    await _withIconFallback(
        () => _plugin.show(id, 'ถึงเวลากินยา', medicationName, _details));
  }

  /// Fires once, at the next occurrence of [hour]:[minute].
  Future<void> scheduleOnce({
    required int id,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();
    await _withIconFallback(() => _plugin.zonedSchedule(
        id,
        'ถึงเวลากินยา',
        body,
        _nextInstanceOf(hour, minute),
        _details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: _dateInterpretation,
        ));
  }

  /// Repeats every day at [hour]:[minute].
  Future<void> scheduleDaily({
    required int id,
    required String body,
    required int hour,
    required int minute,
  }) async {
    await init();
    await _withIconFallback(() => _plugin.zonedSchedule(
        id,
        'ถึงเวลากินยา',
        body,
        _nextInstanceOf(hour, minute),
        _details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: _dateInterpretation,
        matchDateTimeComponents: DateTimeComponents.time,
        ));
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
    await _withIconFallback(() => _plugin.zonedSchedule(
        id,
        'ถึงเวลากินยา',
        body,
        _nextInstanceOf(hour, minute, weekday: weekday),
        _details,
        androidScheduleMode: AndroidScheduleMode.alarmClock,
        uiLocalNotificationDateInterpretation: _dateInterpretation,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
        ));
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

/// Handles an action tapped while the app is not in the foreground.
///
/// Android runs this in its own isolate, so none of the app's singletons,
/// timezone setup or plugin registrations exist here — everything it needs is
/// re-created. It has to be a top-level function with the vm:entry-point
/// pragma, or the tree shaker drops it from a release build and the buttons
/// do nothing.
@pragma('vm:entry-point')
void notificationBackgroundHandler(NotificationResponse response) {
  // Without this the isolate has no plugin registrations, so the sqflite call
  // below has nothing to talk to and the dose is silently dropped.
  DartPluginRegistrant.ensureInitialized();

  if (response.actionId == NotificationService._snoozeActionId) {
    NotificationService.instance.snooze(response.id ?? 0);
  } else if (response.actionId == NotificationService._takenActionId) {
    // Cancelling the notification is what stops the ringing, and the action
    // does that by itself; this is the other half — recording that the dose
    // was actually taken, so answering the reminder answers it once and for
    // all rather than leaving it to be confirmed again in the app.
    recordTakenFromNotification(response.id ?? 0);
  }
}
