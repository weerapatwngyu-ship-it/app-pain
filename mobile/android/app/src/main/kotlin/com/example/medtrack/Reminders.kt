package com.example.medtrack

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * One reminder, mirroring MedicationReminder on the Dart side.
 *
 * [days] uses DateTime.weekday numbering — Monday is 1, Sunday is 7 — and
 * empty means it rings once rather than repeating.
 */
data class Reminder(
    val id: Int,
    val label: String,
    val hour: Int,
    val minute: Int,
    val days: Set<Int>,
    val enabled: Boolean,
) {
    val isOneOff: Boolean get() = days.isEmpty()

    /** Minutes past midnight, for comparing against the current time. */
    val minuteOfDay: Int get() = hour * 60 + minute

    fun ringsOn(isoWeekday: Int): Boolean = isOneOff || days.contains(isoWeekday)
}

/**
 * Everything about deciding when a reminder is due and ringing it.
 *
 * Why this lives in Kotlin rather than Dart: the app's Dart-side scheduling
 * handed the time to the system and asked to be woken, and on this phone the
 * system simply never did — the alarm stayed registered and unfired, which the
 * in-app check screen showed directly. Nothing the Dart code can pass changes
 * that decision.
 *
 * So the app stops asking to be woken and stays awake instead: a foreground
 * service keeps the process alive, and the checks below run inside it. The
 * service is also what makes AlarmManager usable again — an alarm can only be
 * delivered to a process that still exists.
 */
object Reminders {

    private const val PREFS = "medigo_reminders"
    private const val KEY_PAYLOAD = "payload"
    private const val KEY_FIRED_PREFIX = "fired_"

    /**
     * "กินแล้ว" presses live in their own file, not in [PREFS].
     *
     * [sync] wipes that one whenever the reminder list changes, and a dose the
     * patient has confirmed must not be lost because the doctor happened to
     * change the schedule before the app was next opened.
     */
    private const val ACTIONS_PREFS = "medigo_dose_actions"
    private const val KEY_TAKEN = "taken"

    /** Channel ids are versioned because Android freezes a channel's sound and
     *  vibration at creation and silently ignores every later change. A
     *  settings change here means a new id, never an edit. */
    private const val CHANNEL_ALARM = "medigo_dose_alarm_v1"
    private const val CHANNEL_WATCH = "medigo_watch_v1"

    const val WATCH_NOTIFICATION_ID = 1_000_001

    /** How late a due reminder may still ring. Covers a tick that ran behind,
     *  without letting a reminder missed hours ago go off out of nowhere. */
    private const val GRACE_MINUTES = 5

    private fun prefs(context: Context): SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ---------------------------------------------------------------- storage

    /**
     * Replaces the stored reminders with what Dart just saved.
     *
     * Fired markers are cleared only when the payload actually changed. The
     * reminders screen re-syncs every time it opens, and clearing on every
     * sync would let a reminder that already rang this morning ring again the
     * moment the user looked at the screen.
     */
    fun sync(context: Context, payload: String) {
        val store = prefs(context)
        if (store.getString(KEY_PAYLOAD, null) == payload) return
        store.edit()
            .clear()
            .putString(KEY_PAYLOAD, payload)
            .apply()
    }

    fun load(context: Context): List<Reminder> {
        val payload = prefs(context).getString(KEY_PAYLOAD, null) ?: return emptyList()
        return try {
            val array = JSONArray(payload)
            (0 until array.length()).mapNotNull { index ->
                val item = array.optJSONObject(index) ?: return@mapNotNull null
                val rawDays = item.optJSONArray("days") ?: JSONArray()
                Reminder(
                    id = item.optInt("id"),
                    label = item.optString("label"),
                    hour = item.optInt("hour"),
                    minute = item.optInt("minute"),
                    days = (0 until rawDays.length()).map { rawDays.getInt(it) }.toSet(),
                    enabled = item.optBoolean("enabled", true),
                )
            }
        } catch (error: Exception) {
            emptyList()
        }
    }

    // ------------------------------------------------------------ due + firing

    /** java.util.Calendar counts from Sunday; DateTime.weekday from Monday. */
    private fun isoWeekday(calendar: Calendar): Int =
        when (val day = calendar.get(Calendar.DAY_OF_WEEK)) {
            Calendar.SUNDAY -> 7
            else -> day - 1
        }

    private fun slotKey(calendar: Calendar, reminder: Reminder): String {
        val date = "%04d%02d%02d".format(
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )
        // A one-off is keyed without the date, so that once it has rung it
        // stays rung rather than coming back tomorrow at the same time.
        return if (reminder.isOneOff) "once" else "$date-${reminder.minuteOfDay}"
    }

    /**
     * Rings anything that has come due and has not rung for this slot yet.
     * Safe to call as often as you like — the fired markers make it idempotent.
     */
    fun fireDue(context: Context, now: Calendar = Calendar.getInstance()) {
        val store = prefs(context)
        val nowMinute = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val today = isoWeekday(now)

        for (reminder in load(context)) {
            if (!reminder.enabled) continue
            if (!reminder.ringsOn(today)) continue

            val late = nowMinute - reminder.minuteOfDay
            if (late < 0 || late > GRACE_MINUTES) continue

            val key = KEY_FIRED_PREFIX + reminder.id
            val slot = slotKey(now, reminder)
            if (store.getString(key, null) == slot) continue

            store.edit().putString(key, slot).apply()
            ring(context, reminder)
        }
    }

    /** Epoch millis of the soonest reminder still to come, or null if none. */
    fun nextDueAt(context: Context, from: Calendar = Calendar.getInstance()): Long? {
        val store = prefs(context)
        var soonest: Long? = null

        for (reminder in load(context)) {
            if (!reminder.enabled) continue
            if (reminder.isOneOff &&
                store.getString(KEY_FIRED_PREFIX + reminder.id, null) == "once"
            ) {
                continue
            }

            val next = (from.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, reminder.hour)
                set(Calendar.MINUTE, reminder.minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            if (!next.after(from)) next.add(Calendar.DAY_OF_YEAR, 1)
            // A repeating reminder skips forward to a day it actually runs on.
            // Bounded rather than a bare while, so a malformed day set cannot
            // spin here forever.
            var guard = 0
            while (!reminder.ringsOn(isoWeekday(next)) && guard < 8) {
                next.add(Calendar.DAY_OF_YEAR, 1)
                guard++
            }
            if (!reminder.ringsOn(isoWeekday(next))) continue

            val millis = next.timeInMillis
            val current = soonest
            if (current == null || millis < current) soonest = millis
        }
        return soonest
    }

    /**
     * Asks the system to wake us at the next due time.
     *
     * setAlarmClock is used rather than a plain exact alarm because it is the
     * one kind Doze and battery saving are not allowed to defer — it is what
     * the phone's own clock app uses. It is a backstop here rather than the
     * mechanism: the service's own ticking is what actually rings the reminder
     * when the phone is awake.
     */
    fun armNext(context: Context) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = nextDueAt(context) ?: return

        val intent = PendingIntent.getBroadcast(
            context,
            0,
            Intent(context, AlarmReceiver::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        try {
            val exactAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                alarms.canScheduleExactAlarms()
            if (exactAllowed) {
                alarms.setAlarmClock(AlarmManager.AlarmClockInfo(at, intent), intent)
            } else {
                alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
            }
        } catch (error: SecurityException) {
            // Exact-alarm access was revoked between the check and the call.
            // An inexact alarm still helps; the service tick is the real path.
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
        }
    }

    // ------------------------------------------------------------------- test

    /**
     * Rings a one-off notification in [seconds], on the same channel and by
     * the same code as a real reminder.
     *
     * Worth having as a real path rather than an immediate notification: the
     * question that kept going unanswered was whether a reminder set for later
     * arrives at all, and only a delayed one answers it.
     */
    fun scheduleSelfTest(context: Context, seconds: Int) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = System.currentTimeMillis() + seconds * 1_000L
        val intent = PendingIntent.getBroadcast(
            context,
            TEST_REQUEST_CODE,
            Intent(context, AlarmReceiver::class.java).setAction(ACTION_TEST),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            alarms.setAlarmClock(AlarmManager.AlarmClockInfo(at, intent), intent)
        } catch (error: SecurityException) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
        }
    }

    /** Rings the test notification. Called when the test alarm comes back. */
    fun ringTest(context: Context) {
        ring(
            context,
            Reminder(
                id = TEST_NOTIFICATION_ID,
                label = "ทดสอบระบบเตือน — ถ้าเห็นข้อความนี้แปลว่าใช้งานได้",
                hour = 0,
                minute = 0,
                days = emptySet(),
                enabled = true,
            ),
        )
    }

    const val ACTION_TEST = "com.example.medtrack.RING_TEST"
    private const val TEST_REQUEST_CODE = 909
    private const val TEST_NOTIFICATION_ID = 999_002

    // -------------------------------------------------------- answering a dose

    const val ACTION_TAKEN = "com.example.medtrack.DOSE_TAKEN"
    const val ACTION_SNOOZE = "com.example.medtrack.DOSE_SNOOZE"
    const val ACTION_SNOOZE_RING = "com.example.medtrack.DOSE_SNOOZE_RING"
    const val EXTRA_REMINDER_ID = "reminder_id"

    /** How far "เลื่อน 10 นาที" pushes the alarm back. */
    private const val SNOOZE_MINUTES = 10

    /** Keeps the two action PendingIntents of one reminder apart. Larger than
     *  any reminder id in use — the generated ones sit at 800000 + minute of
     *  day, so they stop at 801439. */
    private const val SNOOZE_REQUEST_OFFSET = 2_000_000

    private fun actionPrefs(context: Context): SharedPreferences =
        context.getSharedPreferences(ACTIONS_PREFS, Context.MODE_PRIVATE)

    /**
     * Remembers that the patient pressed "กินแล้ว", for Dart to turn into a
     * dose log next time it runs.
     *
     * Recorded here rather than written straight to the record because there
     * is no app to write it: the button is answered from the tray, usually
     * with the process not running and often with no network. Parking it means
     * a dose confirmed at 08:00 and an app opened at 20:00 still record the
     * 08:00 answer, with the time it was actually given.
     */
    fun recordTaken(context: Context, reminderId: Int, at: Long = System.currentTimeMillis()) {
        val store = actionPrefs(context)
        val marks = try {
            JSONArray(store.getString(KEY_TAKEN, "[]"))
        } catch (error: Exception) {
            JSONArray()
        }
        marks.put(
            JSONObject().apply {
                put("id", reminderId)
                put("at", at)
            }
        )
        // commit, not apply: this runs in a receiver that may be torn down the
        // moment it returns, and an asynchronous write can lose the race.
        store.edit().putString(KEY_TAKEN, marks.toString()).commit()
    }

    /** Hands the collected presses to Dart and forgets them. */
    fun drainTaken(context: Context): String {
        val store = actionPrefs(context)
        val marks = store.getString(KEY_TAKEN, "[]") ?: "[]"
        store.edit().remove(KEY_TAKEN).commit()
        return marks
    }

    /** Rings [reminderId] again in ten minutes. */
    fun snooze(context: Context, reminderId: Int) {
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = System.currentTimeMillis() + SNOOZE_MINUTES * 60_000L
        val intent = PendingIntent.getBroadcast(
            context,
            reminderId,
            Intent(context, AlarmReceiver::class.java)
                .setAction(ACTION_SNOOZE_RING)
                .putExtra(EXTRA_REMINDER_ID, reminderId),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        try {
            alarms.setAlarmClock(AlarmManager.AlarmClockInfo(at, intent), intent)
        } catch (error: SecurityException) {
            alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, intent)
        }
    }

    /** Rings one stored reminder by id — used when a snooze comes back. */
    fun ringById(context: Context, reminderId: Int) {
        val reminder = load(context).firstOrNull { it.id == reminderId } ?: return
        ring(context, reminder)
    }

    // ------------------------------------------------------------ notification

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java)

        val alarm = NotificationChannel(
            CHANNEL_ALARM,
            "เตือนกินยา",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "ดังเมื่อถึงเวลากินยา"
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 800, 400, 800, 400, 800)
            enableLights(true)
            setBypassDnd(true)
            // The alarm stream, so this is heard even when notification volume
            // is down — the same routing the clock app uses.
            setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build(),
            )
        }
        manager.createNotificationChannel(alarm)

        val watch = NotificationChannel(
            CHANNEL_WATCH,
            "การเฝ้าเวลากินยา",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "แจ้งว่าแอปกำลังเฝ้าเวลาอยู่ ไม่มีเสียง"
            setShowBadge(false)
        }
        manager.createNotificationChannel(watch)
    }

    /** The quiet, permanent notification that keeps the process alive. */
    fun watchNotification(context: Context): Notification {
        ensureChannels(context)
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(context, CHANNEL_WATCH)
            .setContentTitle("MediGo กำลังเฝ้าเวลากินยา")
            .setContentText("แตะเพื่อเปิดแอป")
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setShowWhen(false)
            .setContentIntent(open)
            .build()
    }

    private fun ring(context: Context, reminder: Reminder) {
        ensureChannels(context)

        val open = PendingIntent.getActivity(
            context,
            reminder.id,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Two ways to answer without opening the app. Both cancel the
        // notification, which is what stops an insistent alarm — and the first
        // is also how the dose gets into the record, so the patient is not
        // asked to confirm the same dose twice in two places.
        val taken = PendingIntent.getBroadcast(
            context,
            reminder.id,
            Intent(context, DoseActionReceiver::class.java)
                .setAction(ACTION_TAKEN)
                .putExtra(EXTRA_REMINDER_ID, reminder.id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val snooze = PendingIntent.getBroadcast(
            context,
            // Offset so the two actions of one reminder do not share a
            // PendingIntent — same request code and component would make the
            // second overwrite the first.
            reminder.id + SNOOZE_REQUEST_OFFSET,
            Intent(context, DoseActionReceiver::class.java)
                .setAction(ACTION_SNOOZE)
                .putExtra(EXTRA_REMINDER_ID, reminder.id),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val body = reminder.label.trim().ifEmpty { "ถึงเวลากินยาแล้ว" }
        val notification = NotificationCompat.Builder(context, CHANNEL_ALARM)
            .setContentTitle("ถึงเวลากินยา")
            .setContentText(body)
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(true)
            .setContentIntent(open)
            .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
            .setVibrate(longArrayOf(0, 800, 400, 800, 400, 800))
            .addAction(0, "กินแล้ว", taken)
            .addAction(0, "เลื่อน 10 นาที", snooze)
            .build()

        // Keeps sound and vibration repeating until the notification is dealt
        // with, instead of one buzz that is easy to sleep through. There is no
        // builder method for this flag.
        notification.flags = notification.flags or Notification.FLAG_INSISTENT

        try {
            NotificationManagerCompat.from(context)
                .notify(reminder.id, notification)
        } catch (error: SecurityException) {
            // POST_NOTIFICATIONS not granted. Nothing to do here — the app
            // asks for it on the reminders screen.
        }
    }
}
