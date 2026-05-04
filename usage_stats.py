from jnius import autoclass
import time
from api import send_usage


def get_usage_stats():
    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    Context = autoclass('android.content.Context')
    UsageStatsManager = autoclass('android.app.usage.UsageStatsManager')

    context = PythonActivity.mActivity
    usm = context.getSystemService(Context.USAGE_STATS_SERVICE)

    end = int(time.time() * 1000)
    start = end - 1000 * 60 * 60 * 24

    stats = usm.queryUsageStats(
        UsageStatsManager.INTERVAL_DAILY,
        start,
        end
    )

    result = {}

    if stats:
        for s in stats:
            minutes = s.getTotalTimeInForeground() / 1000 / 60
            if minutes > 0:
                result[s.getPackageName()] = int(minutes)

    return result


def collect_and_send():
    raw = get_usage_stats()

    usage = [
        {"app": pkg, "minutes": mins}
        for pkg, mins in raw
    ]

    return send_usage(usage)