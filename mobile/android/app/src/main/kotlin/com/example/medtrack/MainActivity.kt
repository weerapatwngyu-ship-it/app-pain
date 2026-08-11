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
                    // Create it without making the user finish the clock app's
                    // own form. Clock apps may ignore this and show their UI
                    // anyway, which is harmless.
                    putExtra(AlarmClock.EXTRA_SKIP_UI, true)
                    if (days.isNotEmpty()) {
                        putExtra(AlarmClock.EXTRA_DAYS, ArrayList(days))
                    }
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }

                // On some MIUI builds the implicit intent resolves to nothing
                // even though a clock app is installed and visible in
                // <queries> — the launcher entry and the SET_ALARM
                // intent-filter can belong to different exported activities
                // in the same app. So: first try the implicit intent as
                // normal, and if the OS can't resolve it, fall back to
                // addressing known clock-app package names directly. An
                // explicit package intent doesn't depend on package-visibility
                // resolution at all, so it can succeed even when the query
                // above finds nothing.
                val resolved = packageManager.queryIntentActivities(
                    buildIntent(),
                    PackageManager.MATCH_DEFAULT_ONLY,
                )
                val triedPackages = mutableListOf<String>()
                var launched = false
                var lastError: String? = null

                if (resolved.isNotEmpty()) {
                    try {
                        startActivity(buildIntent())
                        launched = true
                    } catch (error: Exception) {
                        lastError = "${error.javaClass.simpleName}: ${error.message}"
                    }
                }

                if (!launched) {
                    val fallbackPackages = listOf(
                        "com.android.deskclock",
                        "com.google.android.deskclock",
                        "com.miui.deskclock",
                        "com.android.alarmclock",
                    )
                    for (packageName in fallbackPackages) {
                        triedPackages += packageName
                        try {
                            startActivity(buildIntent().apply { setPackage(packageName) })
                            launched = true
                            break
                        } catch (error: Exception) {
                            lastError = "${error.javaClass.simpleName}: ${error.message}"
                        }
                    }
                }

                result.success(
                    mapOf(
                        "launched" to launched,
                        "resolvedCount" to resolved.size,
                        "triedPackages" to triedPackages,
                        "lastError" to lastError,
                    )
                )
            }
    }

    private companion object {
        const val CHANNEL = "medigo/system_alarm"
    }
}
