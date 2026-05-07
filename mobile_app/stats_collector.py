from jnius import autoclass
from android import mActivity
import time

Context = autoclass('android.content.Context')
UsageStatsManager = autoclass('android.app.usage.UsageStatsManager')
Calendar = autoclass('java.util.Calendar')


def get_screen_time_today():
    try:
        activity = mActivity
        context = activity.getApplicationContext()

        usm = context.getSystemService(Context.USAGE_STATS_SERVICE)

        # Время сейчас
        end_time = int(time.time() * 1000)

        # Начало дня
        calendar = Calendar.getInstance()
        calendar.set(Calendar.HOUR_OF_DAY, 0)
        calendar.set(Calendar.MINUTE, 0)
        calendar.set(Calendar.SECOND, 0)
        start_time = calendar.getTimeInMillis()

        stats = usm.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            start_time,
            end_time
        )

        total_time = 0

        if stats:
            for i in range(stats.size()):
                usage = stats.get(i)
                total_time += usage.getTotalTimeInForeground()

        # миллисекунды → секунды
        return total_time / 1000

    except Exception as e:
        print("ERROR GETTING STATS:", e)
        return 0