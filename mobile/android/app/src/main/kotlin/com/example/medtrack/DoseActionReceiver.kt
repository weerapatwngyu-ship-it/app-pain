package com.example.medtrack

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat

/**
 * Handles the two buttons on a dose reminder.
 *
 * The point of having them at all is that a patient answers a reminder from
 * the tray, on a phone that is otherwise not being used — so neither button
 * may depend on the app being alive. "กินแล้ว" parks the confirmation for Dart
 * to record when it next runs, and "เลื่อน 10 นาที" re-arms the alarm through
 * the same path a scheduled reminder takes.
 */
class DoseActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val app = context.applicationContext
        val id = intent?.getIntExtra(Reminders.EXTRA_REMINDER_ID, -1) ?: -1
        if (id < 0) return

        // Cancelling stops the ringing: the notification is posted with
        // FLAG_INSISTENT, which keeps sound and vibration going until it is
        // gone. Done first, before any work that could fail.
        NotificationManagerCompat.from(app).cancel(id)

        when (intent?.action) {
            Reminders.ACTION_TAKEN -> Reminders.recordTaken(app, id)
            Reminders.ACTION_SNOOZE -> Reminders.snooze(app, id)
        }
    }
}
