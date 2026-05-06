try:
    from jnius import autoclass
    ANDROID = True
except:
    ANDROID = False

import time
from api import send_usage


# =====================
# GET USAGE
# =====================

def get_usage_stats():
    if not ANDROID:
        print("MOCK USAGE (DESKTOP MODE)")
        return [
            ("com.instagram.android", 25),
            ("com.whatsapp", 10),
            ("org.telegram.messenger", 15),
        ]

    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    Context = autoclass('android.content.Context')
    UsageStatsManager = autoclass('android.app.usage.UsageStatsManager')

    context = PythonActivity.mActivity
    usm = context.getSystemService(Context.USAGE_STATS_SERVICE)

    end_time = int(time.time() * 1000)
    start_time = end_time - 1000 * 60 * 60 * 24  # 24 часа

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

    return result[:30]


# =====================
# MAIN PIPELINE
# =====================

def collect_and_send():
    stats = get_usage_stats()

    total_minutes = 0

    for item in stats:
        if isinstance(item, tuple) and len(item) == 2:
            _, minutes = item
            total_minutes += float(minutes)

    print("TOTAL SCREEN TIME:", total_minutes)

    return send_usage({
        "screen_time": total_minutes
    })


# =====================
# CLEAN NAMES
# =====================

def clean_app_name(package):
    mapping = {
        "com.instagram.android": "Instagram",
        "com.whatsapp": "WhatsApp",
        "org.telegram.messenger": "Telegram",
        "com.google.android.youtube": "YouTube",
    }

    return mapping.get(package, package.split(".")[-1])


# =====================
# CATEGORIES
# =====================

def categorize(app):
    social = ["Instagram", "Telegram", "WhatsApp"]
    video = ["YouTube"]

    if app in social:
        return "Соцсети"
    if app in video:
        return "Видео"

    return "Другое"