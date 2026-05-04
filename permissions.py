from jnius import autoclass
import time


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

    activity = PythonActivity.mActivity
    activity.startActivity(intent)