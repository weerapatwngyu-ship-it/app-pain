package com.example.medtrack

import android.content.Intent
import android.content.pm.PackageManager
import android.provider.AlarmClock
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hands a reminder to the phone's own clock app.
 *
 * The app's own scheduled notifications are at the mercy of the device: on
 * MIUI they can be dropped without a word, and no permission the app can hold
 * changes that. An alarm created in the system clock app is not — it is the
 * one thing on the phone that is guaranteed to ring, because the vendor's own
 * alarm is the thing users notice failing.
 *
 * The trade is ownership: once handed over, the alarm belongs to the clock
 * app. Deleting the reminder here does not remove it there.
 */
class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, REMINDER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // Hands the current reminder list over to the service, which
                    // owns the ringing from here on. Called after every save,
                    // delete or toggle, so the two never drift apart.
                    "sync" -> {
                        Reminders.sync(applicationContext, call.arguments as? String ?: "[]")
                        ReminderService.start(applicationContext)
                        Reminders.armNext(applicationContext)
                        result.success(true)
                    }
                    "start" -> {
                        ReminderService.start(applicationContext)
                        result.success(true)
                    }
                    "stop" -> {
                        ReminderService.stop(applicationContext)
                        result.success(true)
                    }
                    // Rings in [seconds], to prove the path end to end without
                    // waiting out a real reminder time.
                    "test" -> {
                        val seconds = call.argument<Int>("seconds") ?: 30
                        Reminders.scheduleSelfTest(applicationContext, seconds)
                        ReminderService.start(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method != "setAlarm") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val hour = call.argument<Int>("hour") ?: 0
                val minute = call.argument<Int>("minute") ?: 0
                val label = call.argument<String>("label") ?: "ถึงเวลากินยา"
                val days = call.argument<List<Int>>("days") ?: emptyList()

                fun buildIntent() = Intent(AlarmClock.ACTION_SET_ALARM).apply {
                    putExtra(AlarmClock.EXTRA_HOUR, hour)
                    putExtra(AlarmClock.EXTRA_MINUTES, minute)
                    putExtra(AlarmClock.EXTRA_MESSAGE, label)
                    putExtra(AlarmClock.EXTRA_VIBRATE, true)
                    // Deliberately let the clock app show its own screen. The
                    // silent version of this (EXTRA_SKIP_UI) gives no sign of
                    // whether anything was created, and on this phone nothing
                    // was. Opening the clock with the time filled in means the
                    // user sees the alarm land, and can tell at a glance when
                    // it did not.
                    putExtra(AlarmClock.EXTRA_SKIP_UI, false)
                    if (days.isNotEmpty()) {
                        putExtra(AlarmClock.EXTRA_DAYS, ArrayList(days))
                    }
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                // Ask the OS which activities can actually take this, and
                // address one of them by exact component. Launching the
                // implicit intent alone is not enough: it has been seen to
                // fail on MIUI even while this same query reports a handler,
                // and guessing at clock-app package names is worse still,
                // since vendors do not agree on them. The names the query
                // returns are the real ones on this specific phone.
                val resolved = packageManager.queryIntentActivities(
                    buildIntent(),
                    PackageManager.MATCH_DEFAULT_ONLY,
                )
                val attempts = mutableListOf<String>()
                var launched = false

                for (candidate in resolved) {
                    val activity = candidate.activityInfo ?: continue
                    try {
                        startActivity(
                            buildIntent().apply {
                                setClassName(activity.packageName, activity.name)
                            }
                        )
                        launched = true
                        break
                    } catch (error: Exception) {
                        attempts += "${activity.packageName}/${activity.name}" +
                            " -> ${error.javaClass.simpleName}: ${error.message}"
                    }
                }

                // Last resort: let the OS pick, in case the component-level
                // start was refused but the plain implicit one is allowed.
                if (!launched) {
                    try {
                        startActivity(buildIntent())
                        launched = true
                    } catch (error: Exception) {
                        attempts += "implicit -> ${error.javaClass.simpleName}: ${error.message}"
                    }
                }

                result.success(
                    mapOf(
                        "launched" to launched,
                        "resolvedCount" to resolved.size,
                        "attempts" to attempts,
                    )
                )
            }
    }

    private companion object {
        const val CHANNEL = "medigo/system_alarm"
        const val REMINDER_CHANNEL = "medigo/reminder_service"
    }
}
