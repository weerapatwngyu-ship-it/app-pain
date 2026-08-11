package com.example.medtrack

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Brings the reminder service back after a restart.
 *
 * Android clears every scheduled alarm on reboot and does not start services
 * on its own, so without this a phone restarted overnight would go quiet until
 * the user next opened the app — the one failure they would not notice until
 * a dose had already been missed.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",
            // MIUI sends its own flavour of the boot broadcast on some builds.
            "com.htc.intent.action.QUICKBOOT_POWERON" -> {
                Reminders.armNext(context.applicationContext)
                ReminderService.start(context.applicationContext)
            }
        }
    }
}
