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
import android.os.Handler

class SyncService : Service() {

    private lateinit var alarmManager: AlarmManager 

    companion object {

        private const val CHANNEL_ID =
            "family_focus_sync_v2"

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

       fun syncNowStatic(context: Context) {
    val prefs = context.getSharedPreferences("family_focus", Context.MODE_PRIVATE)
    val userId = prefs.getString("user_id", null) ?: return

    val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

    val savedDate = prefs.getString("notification_date", "")
    if (savedDate != today) {
        prefs.edit()
            .putString("notification_date", today)
            .putBoolean("notified_2h", false)
            .putBoolean("notified_4h", false)
            .apply()
    }

    val usageMap = getUsageStatsTodayStatic(context)

    // Физический предел: сумма экранного времени не может превышать
    // длительность суток. Если превышает — на устройстве что-то не так
    // с usage stats (зависшие сессии, кривые прошивки). Обрезаем
    // пропорционально, чтобы не портить аналитику.
    val MAX_SECONDS_PER_DAY = 86_400L
    val rawTotal = usageMap.values.sum().toLong()
    val totalSeconds: Long
    var usageMapFixed = usageMap

    if (rawTotal > MAX_SECONDS_PER_DAY) {
        val ratio = MAX_SECONDS_PER_DAY.toDouble() / rawTotal.toDouble()

        android.util.Log.w(
            "SYNC_SERVICE",
            "Usage stats anomaly: ${rawTotal}s (%.1f h) > 24h, scaling by %.3f"
                .format(rawTotal / 3600.0, ratio)
        )

        usageMapFixed = usageMap.mapValues { (_, v) ->
            (v * ratio).toInt()
        }.toMap()
        totalSeconds = usageMapFixed.values.sum().toLong()
    } else {
        totalSeconds = rawTotal
    }

    android.util.Log.d("SYNC_SERVICE", "totalSeconds=$totalSeconds")

    if (totalSeconds > 7200 && !prefs.getBoolean("notified_2h", false)) {
        showUsageNotification(context, 2001, "2 часа в телефоне", "Не забывайте делать перерывы 🙂")
        prefs.edit().putBoolean("notified_2h", true).apply()
    }

    if (totalSeconds > 14400 && !prefs.getBoolean("notified_4h", false)) {
        showUsageNotification(context, 2002, "4 часа в телефоне!", "Пожалуй, хватит на сегодня 🤔")
        prefs.edit().putBoolean("notified_4h", true).apply()
    }

    val topApps = usageMapFixed.entries
        .sortedByDescending { it.value }
        .take(10)

    val appsArray = JSONArray()
    for (entry in topApps) {
        val obj = JSONObject()
        obj.put("app", entry.key)
        obj.put("minutes", entry.value / 60)
        appsArray.put(obj)
    }

    val bodyJson = JSONObject()
    bodyJson.put("user_id", userId)
    bodyJson.put("total_seconds", totalSeconds)
    bodyJson.put("top_apps", appsArray)
    bodyJson.put("date", today)

    val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .writeTimeout(10, TimeUnit.SECONDS)
        .build()

    val body = bodyJson.toString().toRequestBody("application/json".toMediaTypeOrNull())

    val request = Request.Builder()
        .url("http://89.108.66.36/upload")
        .post(body)
        .build()

    client.newCall(request).enqueue(object : Callback {
        override fun onFailure(call: Call, e: IOException) {
            android.util.Log.e("SYNC_SERVICE", "Upload failed: ${e.message}")
        }

        override fun onResponse(call: Call, response: Response) {
            android.util.Log.d("SYNC_SERVICE", "Upload success")

            val familyId = prefs.getString("family_id", null)

            

            // Проверяем задания и отправляем уведомления
            
            familyId?.let { checkTasksNotifications(context, it) }

            // Еженедельные события — по понедельникам
            if (familyId != null) {
                val calendar = Calendar.getInstance()
                val todayStr = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

                if (calendar.get(Calendar.DAY_OF_WEEK) == Calendar.MONDAY) {
                    val weekCheck = prefs.getString("achievement_check_week", null)
                    if (weekCheck != todayStr) {
                        checkWeeklyEvents(context, familyId)
                        prefs.edit().putString("achievement_check_week", todayStr).apply()
                    }
                }

                if (calendar.get(Calendar.DAY_OF_MONTH) == 1) {
                    val monthCheck = prefs.getString("achievement_check_month", null)
                    if (monthCheck != todayStr) {
                        checkWeeklyEvents(context, familyId)
                        prefs.edit().putString("achievement_check_month", todayStr).apply()
                    }
                }
            }

            response.close()
        }
    })
}


     private fun checkTasksNotifications(context: Context, familyId: String) {
    val prefs = context.getSharedPreferences("family_focus", Context.MODE_PRIVATE)
    val userName = prefs.getString("user_name", null) ?: ""
        
    val role = prefs.getString("role", null) ?: "child"
    val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())

    val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    val request = Request.Builder()
        .url("http://89.108.66.36/tasks?family_id=$familyId&user_name=$userName")
        .get()
        .build()

    client.newCall(request).enqueue(object : Callback {
        override fun onFailure(call: Call, e: IOException) {
            android.util.Log.e("SYNC_SERVICE", "Tasks check failed: ${e.message}")
        }

        override fun onResponse(call: Call, response: Response) {
            try {
                val body = response.body?.string() ?: return
                val json = JSONObject(body)
                val tasks = json.optJSONArray("tasks") ?: return

                var pendingCount = 0
                var reviewCount = 0
                var firstChildName = ""

                for (i in 0 until tasks.length()) {
                    val task = tasks.getJSONObject(i)
                    val status = task.optString("status", "")
                    when (status) {
                        "pending" -> pendingCount++
                        "done" -> {
                            reviewCount++
                            if (firstChildName.isEmpty()) {
                                firstChildName = task.optString("assigned_to", "")
                            }
                        }
                    }
                }
                    
                // Для ребёнка — новые задания
                if (role == "child" && pendingCount > 0) {
                    val lastPendingNotif = prefs.getString("last_pending_notification", "")
                    if (lastPendingNotif != today) {
                        Handler(context.mainLooper).post {
                            showSimpleNotification(
                                context,
                                "📝 Новые задания!",
                                "У вас $pendingCount активных заданий от родителей."
                            )
                        }
                        prefs.edit().putString("last_pending_notification", today).apply()
                    }
                }

                // Для родителя — задания на проверке
                if (role in listOf("parent", "admin_parent") && reviewCount > 0) {
                    val lastReviewCount = prefs.getInt("last_review_count", 0)
                    val message = if (firstChildName.isNotEmpty()) {
                        "⭐ $firstChildName выполнил(а) задание!"
                    } else {
                        "$reviewCount заданий ожидают проверки"
                    }

                    if (reviewCount > lastReviewCount) {
                        Handler(context.mainLooper).post {
                            showSimpleNotification(context, "✅ Задание выполнено", message)
                        }
                        prefs.edit().putInt("last_review_count", reviewCount).apply()
                    } else if (reviewCount < lastReviewCount) {
                        prefs.edit().putInt("last_review_count", reviewCount).apply()
                    }
}
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                response.close()
            }
        }
    })
}

        private fun checkWeeklyEvents(context: Context, familyId: String) {
    val prefs = context.getSharedPreferences("family_focus", Context.MODE_PRIVATE)
    val today = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault()).format(Date())
    val lastNotificationDay = prefs.getString("events_notification_date", null)

    if (lastNotificationDay == today) return

    val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(10, TimeUnit.SECONDS)
        .build()

    val request = Request.Builder()
        .url("http://89.108.66.36/weekly_events?family_id=$familyId")
        .get()
        .build()

    client.newCall(request).enqueue(object : Callback {
        override fun onFailure(call: Call, e: IOException) {}

        override fun onResponse(call: Call, response: Response) {
            
            try {
                val body = response.body?.string() ?: return
                val json = JSONObject(body)

                if (json.optString("status") != "ok") return

                val gardenLevel = json.optInt("garden_level", 1)
                val lastLevelup = json.optString("last_levelup", "")
                val savedLevelupDate = prefs.getString("last_garden_levelup_date", null)

                var notificationShown = false

                if (lastLevelup.isNotEmpty() && lastLevelup != savedLevelupDate) {
                    Handler(context.mainLooper).post {
                        showSimpleNotification(context, "Сад вырос!", "Уровень $gardenLevel: ${gardenLevelName(gardenLevel)}")
                    }
                    prefs.edit().putString("last_garden_levelup_date", lastLevelup).apply()
                    notificationShown = true
                }

                if (notificationShown) {
                    prefs.edit().putString("events_notification_date", today).apply()
                }
            } catch (e: Exception) {
                e.printStackTrace()
            } finally {
                response.close()
            }
        }
    })
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
                        R.mipmap.ic_launcher
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
        
        private fun gardenLevelName(level: Int): String {
    return when (level) {
        1 -> "Росток"
        2 -> "Первый лист"
        3 -> "Первые листочки"
        4 -> "Крепкий росток"
        5 -> "Первые веточки"
        6 -> "Маленький кустик"
        7 -> "Куст"
        8 -> "Первый цветок"
        9 -> "Распускающийся куст"
        10 -> "2 куста и бабочка"
        11 -> "Первое дерево"
        12 -> "Первые плоды"
        13 -> "Еще одно цветущее дерево"
        14 -> "Первая клумба!"
        else -> "Последний уровень"
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
                        R.mipmap.ic_launcher
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
                R.mipmap.ic_launcher
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
                        R.mipmap.ic_launcher
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

                        val rawDuration =
                            (
                                (
                                    timestamp -
                                            startTs
                                    ) / 1000
                                ).toInt()

                        // Защита от «зависших» сессий: если приложение
                        // не прислало MOVE_TO_BACKGROUND вовремя
                        // (убит процесс, перезагрузка), разница может
                        // достигать многих часов. Ограничиваем одну
                        // сессию 3 часами.
                        val MAX_SINGLE_SESSION_SECONDS = 3 * 60 * 60

                        if (rawDuration > MAX_SINGLE_SESSION_SECONDS) {
                            android.util.Log.w(
                                "SYNC_SERVICE",
                                "Session anomaly: $packageName ${rawDuration}s, capped"
                            )
                        }

                        val durationSeconds =
                            rawDuration.coerceIn(0, MAX_SINGLE_SESSION_SECONDS)

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
                        .coerceIn(0, 3 * 60 * 60)

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
                R.mipmap.ic_launcher
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