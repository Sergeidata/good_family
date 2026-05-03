from jnius import autoclass
import time
import requests


def has_usage_stats_permission():
    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    Context = autoclass('android.content.Context')
    AppOpsManager = autoclass('android.app.AppOpsManager')

    context = PythonActivity.mActivity
    app_ops = context.getSystemService(Context.APP_OPS_SERVICE)

    mode = app_ops.checkOpNoThrow(
        "android:get_usage_stats",
        context.getApplicationInfo().uid,
        context.getPackageName()
    )

    return mode == AppOpsManager.MODE_ALLOWED


def request_usage_stats_permission():
    PythonActivity = autoclass('org.kivy.android.PythonActivity')
    Intent = autoclass('android.content.Intent')
    Settings = autoclass('android.provider.Settings')

    intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
    currentActivity = PythonActivity.mActivity
    currentActivity.startActivity(intent)


def get_usage_stats():
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

    return result[:50]

def send_stats_to_server(usage_data):
    url = "https://good-family.onrender.com/upload_stats"

    payload = {
        "family_id": "test1",
        "member": "child",
        "usage": usage_data
    }

    try:
        response = requests.post(url, json=payload)
        print("SERVER RESPONSE:", response.json())
        return response.json()
    except Exception as e:
        print("ERROR:", e)

def convert_to_dict(stats_list):
    usage_dict = {}
    for package, minutes in stats_list:
        usage_dict[package] = int(minutes)
    return usage_dict

def collect_and_send():
    stats = get_usage_stats()
    usage_dict = convert_to_dict(stats)
    return send_stats_to_server(usage_dict)