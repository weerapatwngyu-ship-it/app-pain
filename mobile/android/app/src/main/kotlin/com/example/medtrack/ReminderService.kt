package com.example.medtrack

import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper

/**
 * Keeps MediGo's process alive so its medication reminders can ring.
 *
 * The app used to schedule each reminder with the system and wait to be woken.
 * On this device that never happened: the in-app check screen showed alarms
 * still registered and unfired long after their time had passed, so the
 * reminder was not being suppressed on the way out — the app was simply never
 * being started to send it. A process that has been killed cannot be woken,
 * and no permission an app can hold overrides the vendor's decision to kill it.
 *
 * A foreground service is the documented way to say the process must stay
 * running. The cost is the permanent notification in the tray, which is the
 * price of the guarantee, and the same trade every alarm clock app makes.
 *
 * With the process alive, two things ring a reminder, and either is enough:
 * this service's own tick, and the exact alarm armed in [Reminders.armNext].
 */
class ReminderService : Service() {

    private val handler = Handler(Looper.getMainLooper())

    /** Frequent enough that a reminder rings within its minute, cheap enough
     *  to be invisible on battery — it reads a few values and returns. */
    private val tick = object : Runnable {
        override fun run() {
            Reminders.fireDue(applicationContext)
            Reminders.armNext(applicationContext)
            handler.postDelayed(this, TICK_MILLIS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        Reminders.ensureChannels(this)
        goToForeground()
        handler.post(tick)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        goToForeground()
        // A sync may have just changed what is due, so re-check immediately
        // rather than waiting out the rest of the current tick.
        handler.removeCallbacks(tick)
        handler.post(tick)
        // START_STICKY: if the system does kill us for memory, it brings the
        // service back. That is the whole point of running as one.
        return START_STICKY
    }

    private fun goToForeground() {
        val notification = Reminders.watchNotification(this)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(
                Reminders.WATCH_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE,
            )
        } else {
            startForeground(Reminders.WATCH_NOTIFICATION_ID, notification)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        // Arm the alarm on the way out, so a reminder can still ring if the
        // service is killed and not restarted.
        Reminders.armNext(applicationContext)
        super.onDestroy()
    }

    /** Swiping the app away is not a request to stop reminding. */
    override fun onTaskRemoved(rootIntent: Intent?) {
        Reminders.armNext(applicationContext)
        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        private const val TICK_MILLIS = 20_000L

        fun start(context: Context) {
            val intent = Intent(context, ReminderService::class.java)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (error: Exception) {
                // From Android 12 a foreground service cannot always be started
                // from the background, and the throw is fatal to whatever is
                // calling — including the alarm receiver, whose job is to ring
                // a reminder. Restarting the service is the lesser half of what
                // that receiver does, so losing it must not cost the ring.
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, ReminderService::class.java))
        }
    }
}
