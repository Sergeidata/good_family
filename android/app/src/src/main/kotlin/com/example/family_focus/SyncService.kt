package com.example.family_focus

import android.app.*
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import okhttp3.*
import org.json.JSONArray
import org.json.JSONObject
import java.io.IOException
import java.text.SimpleDateFormat
import java.util.*
import java.util.concurrent.TimeUnit
import okhttp3.MediaType.Companion.toMediaTypeOrNull
import okhttp3.RequestBody.Companion.toRequestBody
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.net.Uri
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat

class SyncService : Service() {

    private lateinit var alarmManager: AlarmManager 

    companion object {

        private const val CHANNEL_ID =
            "family_focus_sync"

        private const val NOTIFICATION_ID = 1001

        private const val ALARM_INTERVAL =
            15 * 60 * 1000L

        fun scheduleNextAlarmStatic(
            context: Context
        ) {

            val alarmManager =
                context.getSystemService(
                    Context.ALARM_SERVICE
                ) as AlarmManager

            val intent = Intent(
                context,
                SyncReceiver::class.java
            )

            val pendingIntent =
                PendingIntent.getBroadcast(
                    context,
                    0,
                    intent,
                    PendingIntent.FLAG_UPDATE_CURRENT or
                            PendingIntent.FLAG_IMMUTABLE
                )

            val triggerAt =
                System.currentTimeMillis() +
                        ALARM_INTERVAL

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {

                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent
                )

            } else {

                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    triggerAt,
                    pendingIntent
                )
            }

            android.util.Log.d(
                "SYNC_SERVICE",
                "Next alarm scheduled"
            )
        }

        fun syncNowStatic(
            context: Context
        ) {

            val prefs =
                context.getSharedPreferences(
                    "family_focus",
                    Context.MODE_PRIVATE
                )

            val userId =
                prefs.getString(
                    "user_id",
                    null
                ) ?: return

            val today =
                SimpleDateFormat(
                    "yyyy-MM-dd",
                    Locale.getDefault()
                ).format(Date())

            val savedDate =
                prefs.getString(
                    "notification_date",
                    ""
                )

            if (savedDate != today) {

                prefs.edit()
                    .putString(
                        "notification_date",
                        today
                    )
                    .putBoolean(
                        "notified_2h",
                        false
                    )
                    .putBoolean(
                        "notified_4h",
                        false
                    )
                    .apply()
            }

            val usageMap =
                getUsageStatsTodayStatic(
                    context
                )

            val totalSeconds =
                usageMap.values.sum()


            android.util.Log.d("SYNC_SERVICE", "totalSeconds=$totalSeconds, notified_2h=${prefs.getBoolean("notified_2h", false)}, notified_4h=${prefs.getBoolean("notified_4h", false)}")

            if (
                totalSeconds > 7200 &&
                !prefs.getBoolean(
                    "notified_2h",
                    false
                )
            ) {

                showUsageNotification(
                    context,
                    2001,
                    "2 часа в телефоне",
                    "Не забывайте делать перерывы 🙂"
                )

                prefs.edit()
                    .putBoolean(
                        "notified_2h",
                        true
                    )
                    .apply()
            }

            if (
                totalSeconds > 14400 &&
                !prefs.getBoolean(
                    "notified_4h",
                    false
                )
            ) {

                showUsageNotification(
                    context,
                    2002,
                    "4 часа в телефоне!",
                    "Пожалуй, хватит на сегодня 🤔"
                )

                prefs.edit()
                    .putBoolean(
                        "notified_4h",
                        true
                    )
                    .apply()
            }

            val topApps =
                usageMap.entries
                    .sortedByDescending {
                        it.value
                    }
                    .take(10)

            val appsArray =
                JSONArray()

            for (entry in topApps) {

                val obj = JSONObject()

                obj.put(
                    "app",
                    entry.key
                )

                obj.put(
                    "minutes",
                    entry.value / 60
                )

                appsArray.put(obj)
            }

            val bodyJson =
                JSONObject()

            bodyJson.put(
                "user_id",
                userId
            )

            bodyJson.put(
                "total_seconds",
                totalSeconds
            )

            bodyJson.put(
                "top_apps",
                appsArray
            )

            bodyJson.put(
                "date",
                today
            )

            val client =
                OkHttpClient.Builder()
                    .connectTimeout(
                        10,
                        TimeUnit.SECONDS
                    )
                    .readTimeout(
                        10,
                        TimeUnit.SECONDS
                    )
                    .writeTimeout(
                        10,
                        TimeUnit.SECONDS
                    )
                    .build()

            val body =
                bodyJson.toString()
                    .toRequestBody(
                        "application/json"
                            .toMediaTypeOrNull()
                    )

            val request =
                Request.Builder()
                    .url("http://159.194.219.146:8000/upload")
                    
                    .post(body)
                    .build()

            client.newCall(request)
                .enqueue(
                    object : Callback {

                        override fun onFailure(
                            call: Call,
                            e: IOException
                        ) {

                            android.util.Log.e(
                                "SYNC_SERVICE",
                                "Upload failed: ${e.message}"
                            )
                        }

                      override fun onResponse(
                        call: Call,
                        response: Response
                    ) {
                        android.util.Log.d("SYNC_SERVICE", "Upload success")
                        
                        val familyId = prefs.getString("family_id", null)
                        
                        if (familyId != null) {
                            val calendar = Calendar.getInstance()
                            val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
                            
                            // Недельные — по понедельникам
                            if (calendar.get(Calendar.DAY_OF_WEEK) == Calendar.MONDAY) {
                                val weekCheck = prefs.getString("achievement_check_week", null)
                                if (weekCheck != today) {
                                    checkWeeklyEvents(context, familyId)
                                    prefs.edit().putString("achievement_check_week", today).apply()
                                }
                            }
                            
                            // Месячные — 1-го числа
                            if (calendar.get(Calendar.DAY_OF_MONTH) == 1) {
                                val monthCheck = prefs.getString("achievement_check_month", null)
                                if (monthCheck != today) {
                                    checkWeeklyEvents(context, familyId)
                                    prefs.edit().putString("achievement_check_month", today).apply()
                                }
                            }
                        }
                        
                        response.close()
                    }
                    }
                )
        }

        private fun checkWeeklyEvents(
            context: Context,
            familyId: String
        ) {

            val prefs =
                context.getSharedPreferences(
                    "family_focus",
                    Context.MODE_PRIVATE
                )

            val today =
                SimpleDateFormat(
                    "yyyy-MM-dd",
                    Locale.getDefault()
                ).format(Date())

            val lastNotificationDay =
                prefs.getString(
                    "events_notification_date",
                    null
                )

            if (lastNotificationDay == today) {
                return
            }

            val client =
                OkHttpClient.Builder()
                    .connectTimeout(
                        10,
                        TimeUnit.SECONDS
                    )
                    .readTimeout(
                        10,
                        TimeUnit.SECONDS
                    )
                    .build()

            val request =
                Request.Builder()
                    .url("http://159.194.219.146:8000/weekly_events?family_id=$familyId")
                    
                    .get()
                    .build()

            client.newCall(request)
                .enqueue(
                    object : Callback {

                        override fun onFailure(
                            call: Call,
                            e: IOException
                        ) {
                            e.printStackTrace()
                        }

                        override fun onResponse(
                            call: Call,
                            response: Response
                        ) {

                            try {

                                val body =
                                    response.body
                                        ?.string()
                                        ?: return

                                val json =
                                    JSONObject(body)

                                if (
                                    json.optString(
                                        "status"
                                    ) != "ok"
                                ) {
                                    return
                                }

                                val achievements =
                                    json.optJSONArray(
                                        "achievements"
                                    )

                                val gardenLevel =
                                    json.optInt(
                                        "garden_level",
                                        1
                                    )

                                val lastAchievementDate =
                                    prefs.getString(
                                        "last_achievement_date",
                                        null
                                    )

                                var newestAchievementDate:
                                        String? = null

                                var newestAchievementName:
                                        String? = null

                                if (
                                    achievements != null &&
                                    achievements.length() > 0
                                ) {

                                    val first =
                                        achievements.getJSONObject(
                                            0
                                        )

                                    newestAchievementDate =
                                        first.optString(
                                            "earned_date"
                                        )

                                    newestAchievementName =
                                        achievementTitle(
                                            first.optString(
                                                "achievement_key"
                                            )
                                        )
                                }

                                var notificationShown =
                                    false

                                if (
                                    newestAchievementDate != null &&
                                    newestAchievementDate !=
                                    lastAchievementDate
                                ) {

                                    showSimpleNotification(
                                        context,
                                        "Новые достижения!",
                                        "Кто-то заработал ачивку «$newestAchievementName»"
                                    )

                                    prefs.edit()
                                        .putString(
                                            "last_achievement_date",
                                            newestAchievementDate
                                        )
                                        .apply()

                                    notificationShown = true
                                }

                                val savedGardenLevel =
                                    prefs.getInt(
                                        "last_garden_level",
                                        1
                                    )

                                if (
                                    gardenLevel >
                                    savedGardenLevel
                                ) {

                                    showSimpleNotification(
                                        context,
                                        "Сад вырос!",
                                        "Уровень $gardenLevel: ${
                                            gardenLevelName(
                                                gardenLevel
                                            )
                                        }"
                                    )

                                    prefs.edit()
                                        .putInt(
                                            "last_garden_level",
                                            gardenLevel
                                        )
                                        .apply()

                                    notificationShown = true
                                }

                                if (
                                    notificationShown
                                ) {

                                    prefs.edit()
                                        .putString(
                                            "events_notification_date",
                                            today
                                        )
                                        .apply()
                                }

                            } catch (
                                e: Exception
                            ) {

                                e.printStackTrace()
                            } finally {

                                response.close()
                            }
                        }
                    }
                )
        }
        

        private fun showSimpleNotification(
            context: Context,
            title: String,
            message: String
        ) {

            val notification =
                NotificationCompat.Builder(
                    context,
                    CHANNEL_ID
                )
                    .setSmallIcon(
                        android.R.drawable.ic_dialog_info
                    )
                    .setContentTitle(
                        title
                    )
                    .setContentText(
                        message
                    )
                    .setPriority(
                        NotificationCompat.PRIORITY_DEFAULT
                    )
                    .setAutoCancel(true)
                    .build()

            NotificationManagerCompat
                .from(context)
                .notify(
                    (System.currentTimeMillis() % 100000).toInt(),
                    notification
                )
        }

        private fun achievementTitle(
            key: String
        ): String {

            return when (key) {

                "3" ->
                    "3 дня минимум телефона"

                "5" ->
                    "5 дней минимум телефона"

                "7" ->
                    "7 дней минимум телефона"

                "10" ->
                    "10 дней минимум телефона"

                "20" ->
                    "20 дней минимум телефона"

                "25" ->
                    "25 дней минимум телефона"

                "month" ->
                    "Весь месяц минимум телефона"

                else ->
                    "Новое достижение"
            }
        }
        
        private fun gardenLevelName(
            level: Int
        ): String {

            return when (level) {

                1 -> "Росток"
                2 -> "Первые листья"
                3 -> "Куст"
                4 -> "Молодое дерево"
                5 -> "Первые плоды"

                else -> "Новый уровень"
            }
        }


        private fun showAchievementNotification(
            context: Context,
            achievementName: String
        ) {

            val notification =
                NotificationCompat.Builder(
                    context,
                    CHANNEL_ID
                )
                    .setSmallIcon(
                        android.R.drawable.ic_dialog_info
                    )
                    .setContentTitle(
                        "Новые достижения!"
                    )
                    .setContentText(
                        "Кто-то заработал ачивку «$achievementName»"
                    )
                    .setAutoCancel(true)
                    .build()

            NotificationManagerCompat
                .from(context)
                .notify(
                    3001,
                    notification
                )
        }

        private fun showGardenNotification(
    context: Context,
    level: Int
) {

    val levelName =
        when (level) {
            1 -> "Росток"
            2 -> "Первые листья"
            3 -> "Куст"
            4 -> "Молодое дерево"
            5 -> "Первые плоды"
            else -> "Новый уровень"
        }

    val notification =
        NotificationCompat.Builder(
            context,
            CHANNEL_ID
        )
            .setSmallIcon(
                android.R.drawable.ic_dialog_info
            )
            .setContentTitle(
                "Сад вырос!"
            )
            .setContentText(
                "Уровень $level: $levelName"
            )
            .setAutoCancel(true)
            .build()

    NotificationManagerCompat
        .from(context)
        .notify(
            3002,
            notification
        )
}


        private fun showUsageNotification(
            context: Context,
            notificationId: Int,
            title: String,
            text: String
        ) {

            val notification =
                NotificationCompat.Builder(
                    context,
                    CHANNEL_ID
                )
                    .setSmallIcon(
                        android.R.drawable.ic_dialog_info
                    )
                    .setContentTitle(
                        title
                    )
                    .setContentText(
                        text
                    )
                    .setPriority(
                        NotificationCompat.PRIORITY_HIGH
                    )

                    .setDefaults(NotificationCompat.DEFAULT_ALL) 
                    .setAutoCancel(true)
                    .build()

            val manager =
                context.getSystemService(
                    Context.NOTIFICATION_SERVICE
                ) as NotificationManager

            manager.notify(
                notificationId,
                notification
            )
        }

        fun getUsageStatsTodayStatic(
            context: Context
        ): Map<String, Int> {

            val usageStatsManager =
                context.getSystemService(
                    Context.USAGE_STATS_SERVICE
                ) as UsageStatsManager

            val calendar =
                Calendar.getInstance()

            calendar.set(
                Calendar.HOUR_OF_DAY,
                0
            )

            calendar.set(
                Calendar.MINUTE,
                0
            )

            calendar.set(
                Calendar.SECOND,
                0
            )

            calendar.set(
                Calendar.MILLISECOND,
                0
            )

            val startTime =
                calendar.timeInMillis

            val endTime =
                System.currentTimeMillis()

            val events =
                usageStatsManager.queryEvents(
                    startTime,
                    endTime
                )

            val result =
                mutableMapOf<String, Int>()

            val activePackages =
                mutableMapOf<String, Long>()

            val excludedPrefixes = listOf(
                "com.android.",
                "com.samsung.",
                "com.sec.",
                "com.sony.",
                "com.oppo.",
                "com.xiaomi.",
                "com.mi.",
                "com.coloros.",
                "com.huawei.",
                "com.bbk."
            )

            val excludedPackages = listOf(
                "com.android.systemui",
                "com.huawei.android.launcher",
                "com.sec.android.app.launcher",
                "com.miui.home",
                "com.oppo.launcher"
            )

            val event =
                UsageEvents.Event()

            while (events.hasNextEvent()) {

                events.getNextEvent(event)

                val packageName =
                    event.packageName ?: continue

                if (
                    excludedPackages.contains(
                        packageName
                    )
                ) {
                    continue
                }

                var excluded = false

                for (prefix in excludedPrefixes) {

                    if (
                        packageName.startsWith(
                            prefix
                        )
                    ) {
                        excluded = true
                        break
                    }
                }

                if (excluded) {
                    continue
                }

                val eventType =
                    event.eventType

                val timestamp =
                    event.timeStamp

                if (
                    eventType ==
                    UsageEvents.Event.MOVE_TO_FOREGROUND
                ) {

                    activePackages[
                        packageName
                    ] = timestamp

                } else if (
                    eventType ==
                    UsageEvents.Event.MOVE_TO_BACKGROUND
                ) {

                    if (
                        activePackages.containsKey(
                            packageName
                        )
                    ) {

                        val startTs =
                            activePackages.remove(
                                packageName
                            ) ?: continue

                        val durationSeconds =
                            (
                                (
                                    timestamp -
                                            startTs
                                    ) / 1000
                                ).toInt()

                        if (
                            durationSeconds >= 60
                        ) {

                            result[packageName] =
                                result.getOrDefault(
                                    packageName,
                                    0
                                ) + durationSeconds
                        }
                    }
                }
            }

            for (
                entry in activePackages.entries
            ) {

                val durationSeconds =
                    (
                        (
                            endTime -
                                    entry.value
                            ) / 1000
                        ).toInt()

                if (
                    durationSeconds >= 60
                ) {

                    result[entry.key] =
                        result.getOrDefault(
                            entry.key,
                            0
                        ) + durationSeconds
                }
            }

            return result
        }
    }

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

        if (Build.VERSION.SDK_INT >= 31) {
            if (!alarmManager.canScheduleExactAlarms()) {
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                intent.data = android.net.Uri.parse("package:$packageName")
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
        }

        scheduleNextAlarmStatic(this)
    }

    override fun onStartCommand(
        intent: Intent?,
        flags: Int,
        startId: Int
    ): Int {

        scheduleNextAlarmStatic(this)

        syncNowStatic(this)

        return START_STICKY
    }

    override fun onDestroy() {

        super.onDestroy()

        scheduleNextAlarmStatic(this)
    }

    override fun onBind(
        intent: Intent?
    ): IBinder? {

        return null
    }

    private fun buildNotification():
            Notification {

        return NotificationCompat.Builder(
            this,
            CHANNEL_ID
        )
            .setContentTitle(
                "Good Family"
            )
            .setContentText(
                "Good Family работает в фоне"
            )
            .setSmallIcon(
                android.R.drawable.ic_dialog_info
            )
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {

        if (
            Build.VERSION.SDK_INT >=
            Build.VERSION_CODES.O
        ) {

            val channel =
                NotificationChannel(
                    CHANNEL_ID,
                    "Good Family Sync",
                    NotificationManager.IMPORTANCE_LOW
                )

            val manager =
                getSystemService(
                    NotificationManager::class.java
                )

            manager.createNotificationChannel(
                channel
            )
        }
    }
}