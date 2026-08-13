package com.example.medtrack

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Rings whatever is due when the exact alarm goes off.
 *
 * This is the backstop for the times [ReminderService]'s own tick cannot run —
 * a handler does not fire while the device is in deep sleep, and an alarm
 * armed with setAlarmClock is the one thing allowed to wake it. Ringing is
 * idempotent, so it does not matter which of the two gets there first.
 */
class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val app = context.applicationContext
        // Ringing comes first and is never skipped. Everything after it is
        // upkeep, and upkeep failing must not cost the reminder itself.
        when (intent?.action) {
            Reminders.ACTION_TEST -> Reminders.ringTest(app)
            // A dose the patient pushed back by ten minutes, come round again.
            // Rung by id rather than by time, since its slot has long passed
            // and fireDue would rightly ignore it.
            Reminders.ACTION_SNOOZE_RING -> Reminders.ringById(
                app,
                intent?.getIntExtra(Reminders.EXTRA_REMINDER_ID, -1) ?: -1,
            )
            else -> Reminders.fireDue(app)
        }
        try {
            Reminders.armNext(app)
        } catch (error: Exception) {
            // Nothing to re-arm, or exact alarms revoked since. The service
            // tick still covers a phone that is awake.
        }
        // If we were woken while the service was down, bring it back up so the
        // next reminder does not depend on this path alone.
        ReminderService.start(app)
    }
}
