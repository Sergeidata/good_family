try:
    from jnius import autoclass
    ANDROID = True
except:
    ANDROID = False

import time
from api import send_usage



def get_usage_stats():
    if not ANDROID:
        print("MOCK USAGE (DESKTOP MODE)")

        return [
            ("com.youtube", 25),
            ("com.whatsapp", 10),
            ("com.telegram", 15),
        ]

    # ====== ANDROID PART ======
    import time

    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    Context = autoclass('android.content.Context')
    UsageStatsManager = autoclass('android.app.usage.UsageStatsManager')

    context = PythonActivity.mActivity
    usm = context.getSystemService(Context.USAGE_STATS_SERVICE)

    end_time = int(time.time() * 1000)
    start_time = end_time - 1000 * 60 * 60 * 24

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
                result.append((s.getPackageName(), minutes))

    result.sort(key=lambda x: x[1], reverse=True)

    return result[:50]




def collect_and_send():
    stats = get_usage_stats()

    usage_list = []

    for item in stats:
        # защита от неправильного формата
        if isinstance(item, tuple) and len(item) == 2:
            package, minutes = item

            try:
                usage_list.append({
                    "app": str(package),
                    "minutes": float(minutes)
                })
            except Exception as e:
                print("SKIP BAD ITEM:", item, e)

    print("FINAL USAGE:", usage_list)

    return send_usage(usage_list)