package com.example.family_focus

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Process
import android.provider.Settings
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar


class MainActivity : FlutterActivity() {

    private val USAGE_CHANNEL = "family_focus/usage_stats"
    private val SYNC_CHANNEL = "family_focus/sync_service"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // UsageStats channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, USAGE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasPermission" -> result.success(hasUsageStatsPermission())
                    "requestPermission" -> {
                        requestUsagePermission()
                        result.success(true)
                    }
                    "getUsageStats" -> {
                        try {
                            val period = call.argument<String>("period") ?: "today"
                            val excludedPrefixes = call.argument<List<String>>("excluded_prefixes") ?: emptyList()
                            val excludedPackages = call.argument<List<String>>("excluded_packages") ?: emptyList()
                            val stats = getUsageStats(period, excludedPrefixes, excludedPackages)
                            result.success(stats)
                        } catch (e: Exception) {
                            result.error("USAGE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }

        // SyncService channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SYNC_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startSyncService" -> {
                        val userId = call.argument<String>("userId")
                        val familyId =
                            call.argument<String>(
                                "familyId"
                            )

                        val role = call.argument<String>("role")
                        if (role != null) {
                            val prefs = getSharedPreferences("family_focus", Context.MODE_PRIVATE)
                            prefs.edit().putString("role", role).apply()    
                        }
                        if (userId == null) {
                            result.error("NO_USER_ID", "userId is null", null)
                            return@setMethodCallHandler
                        }
                        val prefs = getSharedPreferences("family_focus", Context.MODE_PRIVATE)
                        prefs.edit().putString("user_id", userId).apply()

                        val userName = call.argument<String>("userName")
                        if (userName != null) {
                            prefs.edit().putString("user_name", userName).apply()
                        }

                        if (familyId != null) {

                            prefs.edit()
                                .putString(
                                    "family_id",
                                    familyId
                                )
                                .apply()
                        }
                        val intent = Intent(this, SyncService::class.java)
                        if (Build.VERSION.SDK_INT >= 26) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }
                    "stopSyncService" -> {
                        val intent = Intent(this, SyncService::class.java)
                        stopService(intent)
                        result.success(true)
                    }

                    "share" -> {
                        val text = call.argument<String>("text") ?: ""
                        val intent = Intent(Intent.ACTION_SEND)
                        intent.type = "text/plain"
                        intent.putExtra(Intent.EXTRA_TEXT, text)
                        startActivity(Intent.createChooser(intent, "Поделиться"))
                        result.success(true)
                    }

                    "getDeviceId" -> {
                        val androidId = Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID)
                        result.success(androidId)
                    }


                    "requestNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1)
                        }
                        result.success(true)
                    }

                    "checkNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33) {
                            result.success(checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED)
                        } else {
                            result.success(true)
                        }
                    }

                    "checkBatteryPermission" -> {
                        val powerManager = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(powerManager.isIgnoringBatteryOptimizations(packageName))
                    }

                    "openNotificationSettings" -> {
                        val intent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                        intent.putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        startActivity(intent)
                        result.success(true)
                    }

                    "openBatterySettings" -> {
                        val intent = Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    }



                    "checkAutostartPermission" -> {
                        val packageName = context.packageName
                        val isAutoStartEnabled = try {
                            val intent = Intent()
                            intent.component = android.content.ComponentName(
                                "com.iqoo.secure",
                                "com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity"
                            )
                            intent.putExtra("package_name", packageName)
                            true
                        } catch (e: Exception) {
                            false
                        }
                        result.success(isAutoStartEnabled)
                    }

                    "openAutostartSettings" -> {
                        try {
                            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                            intent.data = android.net.Uri.parse("package:$packageName")
                            startActivity(intent)
                        } catch (e: Exception) {
                            val intent = Intent(Settings.ACTION_SETTINGS)
                            startActivity(intent)
                        }
                        result.success(true)
                    }


                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageStatsPermission(): Boolean {
        return try {
            val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
            val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                appOps.unsafeCheckOpNoThrow("android:get_usage_stats", Process.myUid(), packageName)
            } else {
                appOps.checkOpNoThrow("android:get_usage_stats", Process.myUid(), packageName)
            }
            mode == AppOpsManager.MODE_ALLOWED
        } catch (e: Exception) { false }
    }

    private fun requestUsagePermission() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    private fun getUsageStats(period: String, excludedPrefixes: List<String>, excludedPackages: List<String>): HashMap<String, Int> {
        val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        val endTime = System.currentTimeMillis()

        when (period) {
            "today" -> {
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                calendar.set(Calendar.MILLISECOND, 0)
            }
            "yesterday" -> {
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                calendar.add(Calendar.DAY_OF_YEAR, -1)
            }
            "week" -> {
                calendar.setTimeInMillis(endTime)
                calendar.set(Calendar.HOUR_OF_DAY, 0)
                calendar.set(Calendar.MINUTE, 0)
                calendar.set(Calendar.SECOND, 0)
                calendar.set(Calendar.MILLISECOND, 0)
                calendar.add(Calendar.DAY_OF_YEAR, -7)
            }
        }

        val startTime = calendar.timeInMillis
        val realEndTime = if (period == "yesterday") {
            val endCal = Calendar.getInstance()
            endCal.set(Calendar.HOUR_OF_DAY, 0)
            endCal.set(Calendar.MINUTE, 0)
            endCal.set(Calendar.SECOND, 0)
            endCal.set(Calendar.MILLISECOND, 0)
            endCal.timeInMillis
        } else { endTime }

        val events = usageStatsManager.queryEvents(startTime, realEndTime)
        val packageTotals = HashMap<String, Int>()
        val activePackages = HashMap<String, Long>()
        val event = UsageEvents.Event()

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val packageName = event.packageName ?: continue
            if (excludedPackages.contains(packageName)) continue
            var excluded = false
            for (prefix in excludedPrefixes) {
                if (packageName.startsWith(prefix)) { excluded = true; break }
            }
            if (excluded) continue

            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> activePackages[packageName] = event.timeStamp
                UsageEvents.Event.MOVE_TO_BACKGROUND, UsageEvents.Event.ACTIVITY_STOPPED -> {
                    if (activePackages.containsKey(packageName)) {
                        val startTs = activePackages.remove(packageName) ?: continue
                        val duration = ((event.timeStamp - startTs) / 1000).toInt()
                        if (duration > 0) packageTotals[packageName] = (packageTotals[packageName] ?: 0) + duration
                    }
                }
            }
        }

        for (entry in activePackages.entries) {
            val duration = ((realEndTime - entry.value) / 1000).toInt()
            if (duration > 0) packageTotals[entry.key] = (packageTotals[entry.key] ?: 0) + duration
        }

        val filtered = HashMap<String, Int>()
        for (entry in packageTotals.entries) {
            if (entry.value >= 60) filtered[entry.key] = entry.value
        }
        return filtered
    }
}