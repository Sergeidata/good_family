from jnius import autoclass
import time
from api import send_usage


def get_usage_stats():
    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    Context = autoclass('android.content.Context')
    UsageStatsManager = autoclass('android.app.usage.UsageStatsManager')

    context = PythonActivity.mActivity
    usm = context.getSystemService(Context.USAGE_STATS_SERVICE)

    end_time = int(time.time() * 1000)
    start_time = end_time - 1000 * 60 * 60 * 24  # последние 24 часа

    stats = usm.queryUsageStats(
        UsageStatsManager.INTERVAL_DAILY,
        start_time,
        end_time
    )

    result = []

    if stats:
        for s in stats:
            minutes = s.getTotalTimeInForeground() / 1000 / 60
            if minutes > 0:
                result.append({
                    "app": s.getPackageName(),
                    "minutes": round(minutes, 2)
                })

    # сортировка
    result.sort(key=lambda x: x["minutes"], reverse=True)

    return result[:30]  # топ 30


def collect_and_send():
    usage_list = get_usage_stats()

    print("USAGE DATA:", usage_list)

    # отправка на сервер
    response = send_usage(usage_list)

    print("SERVER RESPONSE:", response)

    return response