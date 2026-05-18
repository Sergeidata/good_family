import json
import os
from datetime import datetime, timedelta

from kivy.app import App
from kivy.clock import Clock
from kivy.uix.screenmanager import ScreenManager, Screen
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.scrollview import ScrollView

from jnius import autoclass, cast
from kivy.uix.spinner import Spinner


# ---------------------------------
# Helpers
# ---------------------------------
def format_time(seconds):
    h = seconds // 3600
    m = (seconds % 3600) // 60
    s = seconds % 60

    return f"{h:02d}:{m:02d}:{s:02d}"


def format_hours_minutes(seconds):
    hours = seconds // 3600
    minutes = (seconds % 3600) // 60

    return f"{hours}ч {minutes}мин"


def extract_app_name(package):

    package = package.lower()

    mappings = {
        "instagram": "Instagram",
        "youtube": "YouTube",
        "tiktok": "TikTok",
        "whatsapp": "WhatsApp",
        "telegram": "Telegram",
        "facebook": "Facebook",
        "twitter": "Twitter",
        "x": "X",
        "chrome": "Chrome",
        "spotify": "Spotify",
        "netflix": "Netflix",
        "discord": "Discord",
        "snapchat": "Snapchat",
        "reddit": "Reddit",
        "linkedin": "LinkedIn"
    }

    for key, value in mappings.items():
        if key in package:
            return value

    last_part = package.split(".")[-1]

    return last_part.replace("_", " ").title()


# ---------------------------------
# Android Device State
# ---------------------------------
class DeviceState:
    _power_manager = None

    @staticmethod
    def init():
        if DeviceState._power_manager is None:
            PythonActivity = autoclass('org.kivy.android.PythonActivity')
            Context = autoclass('android.content.Context')

            activity = PythonActivity.mActivity
            context = activity.getApplicationContext()

            DeviceState._power_manager = context.getSystemService(
                Context.POWER_SERVICE
            )

    @staticmethod
    def is_screen_on():
        DeviceState.init()
        return DeviceState._power_manager.isInteractive()


# ---------------------------------
# Usage Stats Helper
# ---------------------------------
class UsageStatsHelper:

    @staticmethod
    def get_context():
        PythonActivity = autoclass(
            'org.kivy.android.PythonActivity'
        )

        activity = PythonActivity.mActivity

        return activity.getApplicationContext()

    @staticmethod
    def has_permission():
        try:
            Context = autoclass(
                'android.content.Context'
            )

            AppOpsManager = autoclass(
                'android.app.AppOpsManager'
            )

            Process = autoclass(
                'android.os.Process'
            )

            context = UsageStatsHelper.get_context()

            app_ops = cast(
                'android.app.AppOpsManager',
                context.getSystemService(
                    Context.APP_OPS_SERVICE
                )
            )

            mode = app_ops.checkOpNoThrow(
                "android:get_usage_stats",
                Process.myUid(),
                context.getPackageName()
            )

            return mode == AppOpsManager.MODE_ALLOWED

        except Exception as e:
            print(f"USAGE PERMISSION ERROR: {e}")
            return False

    @staticmethod
    def request_permission():
        try:
            PythonActivity = autoclass(
                'org.kivy.android.PythonActivity'
            )

            Intent = autoclass(
                'android.content.Intent'
            )

            Settings = autoclass(
                'android.provider.Settings'
            )

            Uri = autoclass(
                'android.net.Uri'
            )

            activity = PythonActivity.mActivity

            intent = Intent(
                Settings.ACTION_USAGE_ACCESS_SETTINGS
            )

            intent.setData(
                Uri.parse(
                    "package:" + activity.getPackageName()
                )
            )

            activity.startActivity(intent)

        except Exception as e:
            print(f"REQUEST PERMISSION ERROR: {e}")

    
    @staticmethod
    def get_screen_time_today():

        try:
            Context = autoclass(
                'android.content.Context'
            )

            UsageStatsManager = autoclass(
                'android.app.usage.UsageStatsManager'
            )

            UsageEvents = autoclass(
                'android.app.usage.UsageEvents'
            )

            System = autoclass(
                'java.lang.System'
            )

            Calendar = autoclass(
                'java.util.Calendar'
            )

            context = UsageStatsHelper.get_context()

            usage_stats_manager = cast(
                'android.app.usage.UsageStatsManager',
                context.getSystemService(
                    Context.USAGE_STATS_SERVICE
                )
            )

            calendar = Calendar.getInstance()

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

            start_time = calendar.getTimeInMillis()

            end_time = System.currentTimeMillis()

            events = usage_stats_manager.queryEvents(
                start_time,
                end_time
            )

            Event = autoclass(
                'android.app.usage.UsageEvents$Event'
            )

            excluded_prefixes = [
                "com.android.",
                "com.google.android.",
                "com.samsung.",
                "com.sec.",
                "com.sony.",
                "com.oppo.",
                "com.xiaomi.",
                "com.mi.",
                "com.coloros.",
                "com.huawei.",
                "com.bbk."
            ]

            excluded_packages = [
                "com.android.systemui",
                "com.huawei.android.launcher",
                "com.sec.android.app.launcher",
                "com.miui.home",
                "com.oppo.launcher",
            ]

            package_totals = {}

            active_packages = {}

            event = Event()

            while events.hasNextEvent():

                events.getNextEvent(event)

                package_name = event.getPackageName()

                if not package_name:
                    continue

                if package_name in excluded_packages:
                    continue

                excluded = False

                for prefix in excluded_prefixes:
                    if package_name.startswith(prefix):
                        excluded = True
                        break

                if excluded:
                    continue

                event_type = event.getEventType()

                timestamp = event.getTimeStamp()

                if (
                    event_type ==
                    Event.MOVE_TO_FOREGROUND
                ):

                    active_packages[
                        package_name
                    ] = timestamp

                elif (
                    event_type ==
                    Event.MOVE_TO_BACKGROUND
                ):

                    if package_name in active_packages:

                        start_ts = active_packages.pop(
                            package_name
                        )

                        duration_seconds = int(
                            (timestamp - start_ts) / 1000
                        )

                        if duration_seconds > 0:

                            package_totals[
                                package_name
                            ] = (
                                package_totals.get(
                                    package_name,
                                    0
                                ) + duration_seconds
                            )

            for package_name, start_ts in (
                active_packages.items()
            ):

                duration_seconds = int(
                    (end_time - start_ts) / 1000
                )

                if duration_seconds > 0:

                    package_totals[
                        package_name
                    ] = (
                        package_totals.get(
                            package_name,
                            0
                        ) + duration_seconds
                    )

            filtered_totals = {}

            total_seconds = 0

            for package_name, seconds in (
                package_totals.items()
            ):

                if seconds < 60:
                    continue

                filtered_totals[
                    package_name
                ] = seconds

                total_seconds += seconds

            top10_list = sorted(
                filtered_totals.items(),
                key=lambda x: x[1],
                reverse=True
            )[:10]

            print(
                f"DEBUG: total={total_seconds}s, "
                f"unique_packages={len(filtered_totals)}, "
                f"sum_of_packages={sum(filtered_totals.values())}s"
            )

            return (
                total_seconds,
                top10_list,
                filtered_totals
            )

        except Exception as e:

            print(
                f"USAGE STATS ERROR: {e}"
            )

            return (
                0,
                [],
                {}
            )
        
    
    @staticmethod
    def get_screen_time_yesterday():

        try:
            Context = autoclass(
                'android.content.Context'
            )

            UsageEvents = autoclass(
                'android.app.usage.UsageEvents$Event'
            )

            System = autoclass(
                'java.lang.System'
            )

            Calendar = autoclass(
                'java.util.Calendar'
            )

            context = UsageStatsHelper.get_context()

            usage_stats_manager = cast(
                'android.app.usage.UsageStatsManager',
                context.getSystemService(
                    Context.USAGE_STATS_SERVICE
                )
            )

            calendar = Calendar.getInstance()

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

            end_time = calendar.getTimeInMillis()

            calendar.add(
                Calendar.DAY_OF_YEAR,
                -1
            )

            start_time = calendar.getTimeInMillis()

            events = usage_stats_manager.queryEvents(
                start_time,
                end_time
            )

            excluded_prefixes = [
                "com.android.",
                "com.google.android.",
                "com.samsung.",
                "com.sec.",
                "com.sony.",
                "com.oppo.",
                "com.xiaomi.",
                "com.mi.",
                "com.coloros.",
                "com.huawei.",
                "com.bbk."
            ]

            excluded_packages = [
                "com.android.systemui",
                "com.huawei.android.launcher",
                "com.sec.android.app.launcher",
                "com.miui.home",
                "com.oppo.launcher",
            ]

            package_totals = {}
            active_sessions = {}

            event = UsageEvents()

            while events.hasNextEvent():

                events.getNextEvent(event)

                package_name = event.getPackageName()

                if not package_name:
                    continue

                excluded = False

                if package_name in excluded_packages:
                    continue

                for prefix in excluded_prefixes:
                    if package_name.startswith(prefix):
                        excluded = True
                        break

                if excluded:
                    continue

                event_type = event.getEventType()
                timestamp = event.getTimeStamp()

                if event_type == UsageEvents.MOVE_TO_FOREGROUND:

                    active_sessions[
                        package_name
                    ] = timestamp

                elif event_type in [
                    UsageEvents.MOVE_TO_BACKGROUND,
                    UsageEvents.ACTIVITY_STOPPED
                ]:

                    if package_name in active_sessions:

                        start_ts = active_sessions.pop(
                            package_name
                        )

                        duration_seconds = int(
                            (timestamp - start_ts) / 1000
                        )

                        if duration_seconds > 0:

                            package_totals[
                                package_name
                            ] = (
                                package_totals.get(
                                    package_name,
                                    0
                                ) + duration_seconds
                            )

            total_seconds = 0

            filtered_totals = {}

            for package_name, seconds in package_totals.items():

                if seconds < 60:
                    continue

                filtered_totals[
                    package_name
                ] = seconds

                total_seconds += seconds

            top10_list = sorted(
                filtered_totals.items(),
                key=lambda x: x[1],
                reverse=True
            )[:10]

            return (
                total_seconds,
                top10_list,
                filtered_totals
            )

        except Exception as e:

            print(
                f"YESTERDAY USAGE ERROR: {e}"
            )

            return (
                0,
                [],
                {}
            )


    @staticmethod
    def get_screen_time_week():

        try:
            Context = autoclass(
                'android.content.Context'
            )

            UsageEvents = autoclass(
                'android.app.usage.UsageEvents$Event'
            )

            System = autoclass(
                'java.lang.System'
            )

            Calendar = autoclass(
                'java.util.Calendar'
            )

            context = UsageStatsHelper.get_context()

            usage_stats_manager = cast(
                'android.app.usage.UsageStatsManager',
                context.getSystemService(
                    Context.USAGE_STATS_SERVICE
                )
            )

            calendar = Calendar.getInstance()

            end_time = System.currentTimeMillis()

            calendar.setTimeInMillis(
                end_time
            )

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

            calendar.add(
                Calendar.DAY_OF_YEAR,
                -7
            )

            start_time = calendar.getTimeInMillis()

            events = usage_stats_manager.queryEvents(
                start_time,
                end_time
            )

            excluded_prefixes = [
                "com.android.",
                "com.google.android.",
                "com.samsung.",
                "com.sec.",
                "com.sony.",
                "com.oppo.",
                "com.xiaomi.",
                "com.mi.",
                "com.coloros.",
                "com.huawei.",
                "com.bbk."
            ]

            excluded_packages = [
                "com.android.systemui",
                "com.huawei.android.launcher",
                "com.sec.android.app.launcher",
                "com.miui.home",
                "com.oppo.launcher",
            ]

            package_totals = {}
            active_sessions = {}

            event = UsageEvents()

            while events.hasNextEvent():

                events.getNextEvent(event)

                package_name = event.getPackageName()

                if not package_name:
                    continue

                excluded = False

                if package_name in excluded_packages:
                    continue

                for prefix in excluded_prefixes:
                    if package_name.startswith(prefix):
                        excluded = True
                        break

                if excluded:
                    continue

                event_type = event.getEventType()
                timestamp = event.getTimeStamp()

                if event_type == UsageEvents.MOVE_TO_FOREGROUND:

                    active_sessions[
                        package_name
                    ] = timestamp

                elif event_type in [
                    UsageEvents.MOVE_TO_BACKGROUND,
                    UsageEvents.ACTIVITY_STOPPED
                ]:

                    if package_name in active_sessions:

                        start_ts = active_sessions.pop(
                            package_name
                        )

                        duration_seconds = int(
                            (timestamp - start_ts) / 1000
                        )

                        if duration_seconds > 0:

                            package_totals[
                                package_name
                            ] = (
                                package_totals.get(
                                    package_name,
                                    0
                                ) + duration_seconds
                            )

            for package_name, start_ts in active_sessions.items():

                duration_seconds = int(
                    (end_time - start_ts) / 1000
                )

                if duration_seconds > 0:

                    package_totals[
                        package_name
                    ] = (
                        package_totals.get(
                            package_name,
                            0
                        ) + duration_seconds
                    )

            total_seconds = 0

            filtered_totals = {}

            for package_name, seconds in package_totals.items():

                if seconds < 60:
                    continue

                filtered_totals[
                    package_name
                ] = seconds

                total_seconds += seconds

            top10_list = sorted(
                filtered_totals.items(),
                key=lambda x: x[1],
                reverse=True
            )[:10]

            return (
                total_seconds,
                top10_list,
                filtered_totals
            )

        except Exception as e:

            print(
                f"WEEK USAGE ERROR: {e}"
            )

            return (
                0,
                [],
                {}
            )


# ---------------------------------
# Session Storage
# ---------------------------------
class SessionStorage:

    @staticmethod
    def get_file_path():
        app = App.get_running_app()
        return os.path.join(app.user_data_dir, "screen_sessions.json")

    @staticmethod
    def load_sessions():
        path = SessionStorage.get_file_path()

        if not os.path.exists(path):
            return []

        try:
            with open(path, "r") as f:
                return json.load(f)
        except Exception:
            return []

    @staticmethod
    def save_sessions(sessions):
        path = SessionStorage.get_file_path()

        with open(path, "w") as f:
            json.dump(sessions, f, indent=4)

    @staticmethod
    def add_session(session):
        sessions = SessionStorage.load_sessions()
        sessions.append(session)
        SessionStorage.save_sessions(sessions)


# ---------------------------------
# Main Screen
# ---------------------------------
class MainScreen(Screen):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self._screen_seconds_today = 0
        self._screen_on = False
        self._session_start = None
        self._last_autosave = 0
        

        self.using_usage_stats = (
            UsageStatsHelper.has_permission()
        )

        self.build_ui()

        self.load_today_total()

        self._last_usage_stats_total = (
            self._screen_seconds_today
        )

        if self.using_usage_stats:

            Clock.schedule_interval(
                self.update_usage_stats,
                30
            )

            print(
                "DEBUG: update_usage_stats scheduled"
            )

        else:

            Clock.schedule_interval(
                self.update_screen_state,
                1
            )

    def build_ui(self):
        layout = BoxLayout(
            orientation="vertical",
            spacing=20,
            padding=20
        )

        
        self.main_counter = Label(
            text="Сегодня вы провели в телефоне:\n0 часов 0 минут",
            font_size=36,
            halign="center",
            size_hint=(1, 0.3)
        )
        self.main_counter.bind(size=self.main_counter.setter("text_size"))

        self.motivation_label = Label(
            text="Так держать! Старайтесь не проводить\nбольше 2 часов в телефоне",
            font_size=36,
            bold=True,
            color=(0.2, 0.7, 0.2, 1),  # зелёный
            halign="center",
            size_hint=(1, 0.2)
        )
        self.motivation_label.bind(size=self.motivation_label.setter("text_size"))

        self.permission_button = Button(
            text="Дать разрешение",
            size_hint=(1, 0.15)
        )
        self.permission_button.bind(on_press=self.request_usage_permission)

        if self.using_usage_stats:
            self.permission_button.opacity = 0
            self.permission_button.disabled = True

        stats_button = Button(
            text="Статистика",
            size_hint=(1, 0.2)
        )
        stats_button.bind(on_press=self.open_stats)

        group_button = Button(
            text="Рейтинг группы",
            size_hint=(1, 0.15)
        )
        group_button.bind(on_press=lambda x: setattr(self.manager, "current", "group"))

        layout.add_widget(self.main_counter)
        layout.add_widget(self.motivation_label)
        layout.add_widget(self.permission_button)
        layout.add_widget(stats_button)
        layout.add_widget(group_button)

        self.add_widget(layout)
        self.update_time_label()

    def request_usage_permission(self, instance):
        UsageStatsHelper.request_permission()

        Clock.schedule_once(
            self.check_permission_after_return,
            2
        )

    def check_permission_after_return(self, dt):

        try:

            if not self.manager:
                return

            if self.manager.current != "main":
                return

            if UsageStatsHelper.has_permission():

                old_total = self._screen_seconds_today

                self.using_usage_stats = True

                self.permission_button.opacity = 0
                self.permission_button.disabled = True

                Clock.unschedule(
                    self.update_screen_state
                )

                usage_total, _, _ = (
                    UsageStatsHelper.get_screen_time_today()
                )

                # перенос накопленного времени
                if usage_total < old_total:
                    usage_total = old_total

                self._last_usage_stats_total = old_total
                self._screen_seconds_today = usage_total

                Clock.schedule_interval(
                    self.update_usage_stats,
                    30
                )

                print(
                    "DEBUG: update_usage_stats scheduled"
                )

                self.update_time_label()

        except Exception as e:

            print(
                f"CHECK_PERMISSION_ERROR: {e}"
            )

    def update_usage_stats(self, dt):

        print("UPDATE_USAGE_STATS CALLED")

        old_total = self._screen_seconds_today

        result = UsageStatsHelper.get_screen_time_today()

        if not result:
            return

        new_total, top10_list, package_totals = result

        self._top5_apps = top10_list

        print(
            f"USAGE DEBUG: total={new_total}s "
            f"top5={top10_list[:5]}"
        )

        sorted_all = sorted(
            [
                (pkg, sec)
                for pkg, sec in package_totals.items()
                if sec > 30
            ],
            key=lambda x: x[1],
            reverse=True
        )

        print(f"ALL APPS: {sorted_all}")

        if new_total > old_total:

            diff_seconds = (
                new_total - old_total
            )

            now = datetime.now()

            start_time = (
                now - timedelta(
                    seconds=diff_seconds
                )
            )

            session = {
                "date": now.strftime("%Y-%m-%d"),
                "start": start_time.strftime("%H:%M:%S"),
                "end": now.strftime("%H:%M:%S"),
                "duration_seconds": diff_seconds
            }

            SessionStorage.add_session(session)

        self._screen_seconds_today = new_total

        self.update_time_label()

    def open_stats(self, instance):
        if self._screen_on and self._session_start is not None:
            self.save_current_session()
            self._session_start = datetime.now()

        stats_screen = self.manager.get_screen("stats")
        stats_screen.refresh_stats()
        self.manager.current = "stats"

    def update_screen_state(self, dt):
        try:
            is_on = DeviceState.is_screen_on()

            # Screen turned ON
            if is_on and not self._screen_on:
                self._screen_on = True
                self._session_start = datetime.now()
                self._last_autosave = 0

            # Screen still ON
            if is_on:
                self._screen_seconds_today += 1
                self._last_autosave += 1

                self.update_time_label()

                # autosave every 30 seconds
                if self._last_autosave >= 30:
                    self.save_current_session()

                    self._session_start = datetime.now()
                    self._last_autosave = 0

            # Screen turned OFF
            if not is_on and self._screen_on:
                self._screen_on = False
                self.save_current_session()

            if not is_on:
                self._last_autosave = 0

        except Exception as e:
            self.time_label.text = str(e)

    def save_current_session(self):
        if self._session_start is None:
            return

        end_time = datetime.now()

        duration_seconds = int(
            (end_time - self._session_start).total_seconds()
        )

        if duration_seconds <= 0:
            return

        session = {
            "date": self._session_start.strftime("%Y-%m-%d"),
            "start": self._session_start.strftime("%H:%M:%S"),
            "end": end_time.strftime("%H:%M:%S"),
            "duration_seconds": duration_seconds
        }

        SessionStorage.add_session(session)

        print(
            f"DEBUG: saving session, "
            f"seconds={duration_seconds}, "
            f"file={SessionStorage.get_file_path()}"
        )

        self._session_start = None

    def load_today_total(self):
        sessions = SessionStorage.load_sessions()

        today = datetime.now().strftime("%Y-%m-%d")

        total_seconds = 0

        for session in sessions:
            if session.get("date") == today:
                total_seconds += session.get(
                    "duration_seconds",
                    0
                )

        self._screen_seconds_today = total_seconds

        self.update_time_label()

   

    def update_time_label(self):
        hours = self._screen_seconds_today // 3600
        minutes = (self._screen_seconds_today % 3600) // 60
        
        self.main_counter.text = (
            f"Сегодня вы провели в телефоне:\n"
            f"{hours} часов {minutes} минут"
        )
        
        if self._screen_seconds_today > 7200:
            self.motivation_label.text = "Отложи телефон — погуляй!"
            self.motivation_label.color = (1, 0.6, 0.2, 1)  # оранжевый
        else:
            self.motivation_label.text = (
                "Так держать! Старайтесь не проводить\n"
                "больше 2 часов в телефоне"
            )
            self.motivation_label.color = (0.2, 0.7, 0.2, 1)  # зелёный

    
    


# ---------------------------------
# Stats Screen
# ---------------------------------
class StatsScreen(Screen):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.build_ui()

    def build_ui(self):

        root = BoxLayout(
            orientation="vertical",
            spacing=10,
            padding=10
        )

        tabs_layout = BoxLayout(
            orientation="horizontal",
            size_hint=(1, 0.1),
            spacing=10
        )

        self.btn_week = Button(
            text="Дни недели"
        )

        self.btn_apps = Button(
            text="Топ-10"
        )

        self.btn_week.bind(
            on_press=lambda x: self.show_week()
        )

        self.btn_apps.bind(
            on_press=lambda x: self.show_apps()
        )

        tabs_layout.add_widget(self.btn_week)
        tabs_layout.add_widget(self.btn_apps)

        self.content_area = BoxLayout(
            orientation="vertical",
            size_hint=(1, 0.78)
        )

        back_button = Button(
            text="Назад",
            size_hint=(1, 0.12)
        )

        back_button.bind(on_press=self.go_back)

        root.add_widget(tabs_layout)
        root.add_widget(self.content_area)
        root.add_widget(back_button)

        self.add_widget(root)

        self.show_week()

    def show_week(self):

        self.content_area.clear_widgets()

        self.scroll = ScrollView(
            size_hint=(1, 1)
        )

        self.stats_layout = BoxLayout(
            orientation="vertical",
            size_hint_y=None,
            spacing=10,
            padding=10
        )

        self.stats_layout.bind(
            minimum_height=self.stats_layout.setter(
                'height'
            )
        )

        self.scroll.add_widget(
            self.stats_layout
        )

        self.content_area.add_widget(
            self.scroll
        )

        self.refresh_week()

    def show_apps(self):

        self.content_area.clear_widgets()

        root = BoxLayout(
            orientation="vertical",
            spacing=10,
            padding=10
        )

        self.apps_spinner = Spinner(
            text="Сегодня",
            values=(
                "Сегодня",
                "Вчера",
                "7 дней"
            ),
            size_hint=(1, None),
            height=80
        )

        self.apps_spinner.bind(
            text=lambda instance, value:
            self.refresh_apps(value)
        )

        self.apps_scroll = ScrollView()

        self.apps_layout = BoxLayout(
            orientation="vertical",
            size_hint_y=None,
            spacing=10,
            padding=10
        )

        self.apps_layout.bind(
            minimum_height=self.apps_layout.setter(
                'height'
            )
        )

        self.apps_scroll.add_widget(
            self.apps_layout
        )

        root.add_widget(self.apps_spinner)
        root.add_widget(self.apps_scroll)

        self.content_area.add_widget(root)

        self.refresh_apps("Сегодня")

    
    def refresh_apps(self, period):

        self.apps_layout.clear_widgets()

        if period == "Сегодня":

            total_seconds, top_list, _ = (
                UsageStatsHelper.get_screen_time_today()
            )

        elif period == "Вчера":

            total_seconds, top_list, _ = (
                UsageStatsHelper.get_screen_time_yesterday()
            )

        else:

            total_seconds, top_list, _ = (
                UsageStatsHelper.get_screen_time_week()
            )

        top10 = top_list[:10]

        if not top10:

            empty_label = Label(
                text="Нет данных",
                size_hint_y=None,
                height=60,
                font_size=36
            )

            self.apps_layout.add_widget(
                empty_label
            )

            return

        for index, (package, seconds) in enumerate(top10):

            app_name = extract_app_name(
                package
            )

            minutes = seconds // 60

            text = (
                f"{index + 1}. "
                f"{app_name} — "
                f"{minutes} мин"
            )

            label = Label(
                text=text,
                size_hint_y=None,
                height=100,
                font_size=36
            )

            self.apps_layout.add_widget(
                label
            )

    def refresh_week(self):

        self.stats_layout.clear_widgets()

        sessions = SessionStorage.load_sessions()

        today = datetime.now()

        monday = (
            today - timedelta(
                days=today.weekday()
            )
        )

        totals = {}

        weekdays_labels = [
            "Пн",
            "Вт",
            "Ср",
            "Чт",
            "Пт",
            "Сб",
            "Вс"
        ]

        for i in range(7):

            day = monday + timedelta(days=i)

            key = day.strftime(
                "%Y-%m-%d"
            )

            totals[key] = 0

        for session in sessions:

            date = session.get("date")

            if date in totals:

                totals[date] += session.get(
                    "duration_seconds",
                    0
                )

        week_seconds = sum(
            totals.values()
        )

        average_seconds = int(
            week_seconds / 7
        )

        #отступ
        self.stats_layout.add_widget(Label(size_hint_y=None, height=30))

        average_label = Label(
            text=(
                "Среднее за 7 дней: "
                f"{format_hours_minutes(average_seconds)}"
            ),
            size_hint_y=None,
            height=70,
            font_size=40
        )

        self.stats_layout.add_widget(
            average_label
        )

        #отступ
        self.stats_layout.add_widget(Label(size_hint_y=None, height=40))

        sorted_days = sorted(
            totals.keys()
        )

        for date in sorted_days:

            total_seconds = totals[date]

            day_obj = datetime.strptime(
                date,
                "%Y-%m-%d"
            )

            weekday = weekdays_labels[
                day_obj.weekday()
            ]

            date_short = day_obj.strftime(
                "%d.%m"
            )

            text = (
                f"{weekday} {date_short}   "
                f"{format_hours_minutes(total_seconds)}"
            )

            label = Label(
                text=text,
                size_hint_y=None,
                height=60,
                font_size=36
            )

            self.stats_layout.add_widget(
                label
            )

    def refresh_stats(self):
        self.show_week()

    def go_back(self, instance):
        self.manager.current = "main"


# ---------------------------------
# GROUP SCREEN
# ---------------------------------

class GroupScreen(Screen):

    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self.build_ui()

    def build_ui(self):

        root = BoxLayout(
            orientation="vertical",
            spacing=10,
            padding=10
        )

        self.period_spinner = Spinner(
            text="Сегодня",
            values=(
                "Сегодня",
                "Вчера",
                "Неделя"
            ),
            size_hint=(1, 0.12)
        )

        self.period_spinner.bind(
            text=lambda instance, value:
            self.refresh_group(value)
        )

        self.scroll = ScrollView(
            size_hint=(1, 0.76)
        )

        self.group_layout = BoxLayout(
            orientation="vertical",
            size_hint_y=None,
            spacing=10,
            padding=10
        )

        self.group_layout.bind(
            minimum_height=self.group_layout.setter(
                'height'
            )
        )

        self.scroll.add_widget(
            self.group_layout
        )

        back_button = Button(
            text="Назад",
            size_hint=(1, 0.12)
        )

        back_button.bind(
            on_press=self.go_back
        )

        root.add_widget(self.period_spinner)
        root.add_widget(self.scroll)
        root.add_widget(back_button)

        self.add_widget(root)

        self.refresh_group("Сегодня")

    def refresh_group(self, period):

        self.group_layout.clear_widgets()

        sessions = SessionStorage.load_sessions()

        today = datetime.now()

        today_key = today.strftime(
            "%Y-%m-%d"
        )

        yesterday_key = (
            today - timedelta(days=1)
        ).strftime("%Y-%m-%d")

        week_dates = []

        for i in range(7):

            day = (
                today - timedelta(days=i)
            ).strftime("%Y-%m-%d")

            week_dates.append(day)

        user_seconds = 0

        for session in sessions:

            date = session.get("date")

            if period == "Сегодня":

                if date == today_key:

                    user_seconds += session.get(
                        "duration_seconds",
                        0
                    )

            elif period == "Вчера":

                if date == yesterday_key:

                    user_seconds += session.get(
                        "duration_seconds",
                        0
                    )

            elif period == "Неделя":

                if date in week_dates:

                    user_seconds += session.get(
                        "duration_seconds",
                        0
                    )

        if period == "Неделя":
            user_seconds = int(user_seconds / 7)

        group_stats = [
            {
                "name": "Вы",
                "seconds": user_seconds
            },
            {
                "name": "Анна",
                "seconds": 7200
            },
            {
                "name": "Папа",
                "seconds": 10800
            },
            {
                "name": "Дима",
                "seconds": 14400
            }
        ]

        group_stats = sorted(
            group_stats,
            key=lambda x: x["seconds"]
        )

        status_config = {
            "good": {
                "text": "✅ Отлично",
                "color": (0.2, 0.7, 0.2, 1)
            },
            "normal": {
                "text": "⚠️ Норма",
                "color": (1, 0.76, 0.03, 1)
            },
            "bad": {
                "text": "❌ Многовато",
                "color": (0.96, 0.26, 0.21, 1)
            }
}

        for index, member in enumerate(group_stats):

            hours = (
                member["seconds"] // 3600
            )

            minutes = (
                member["seconds"] % 3600
            ) // 60

            if member["seconds"] < 7200:

                status = status_config["good"]

            elif member["seconds"] < 14400:

                status = status_config["normal"]

            else:

                status = status_config["bad"]

            row = BoxLayout(
                orientation="horizontal",
                size_hint_y=None,
                height=60
            )

            main_label = Label(
                text=(
                    f"{index + 1}. "
                    f"{member['name']} — "
                    f"{hours}ч {minutes}мин"
                ),
                font_size=46,
                halign="left"
            )

            status_label = Label(
                text=status["text"],
                color=status["color"],
                font_size=40,
                size_hint=(0.4, 1)
            )


        


            row.add_widget(main_label)
            row.add_widget(status_label)

            #Отступ
            self.group_layout.add_widget(Label(size_hint_y=None, height=30))

            self.group_layout.add_widget(row)

        
        #Отступ
        self.group_layout.add_widget(Label(size_hint_y=None, height=40))
        
        leader_seconds = group_stats[0]["seconds"]

        user_member = None

        for member in group_stats:
            if member["name"] == "Вы":
                user_member = member
                break

        if user_member:

            if user_member["seconds"] == leader_seconds:

                leader_label = Label(
                    text="Вы лидер! Так держать!",
                    color=(0.2, 0.7, 0.2, 1),
                    size_hint_y=None,
                    height=70,
                    font_size=40
                )

                self.group_layout.add_widget(
                    leader_label
                )

            else:

                diff_seconds = (
                    user_member["seconds"]
                    - leader_seconds
                )

                diff_hours = diff_seconds // 3600

                diff_minutes = (
                    diff_seconds % 3600
                ) // 60

                motivation_label = Label(
                    text=(
                        f"Разрыв с лидером: "
                        f"{diff_hours}ч "
                        f"{diff_minutes}мин. "
                        f"Поднажмите!"
                    ),
                    size_hint_y=None,
                    height=70,
                    font_size=40
                )

                self.group_layout.add_widget(
                    motivation_label
                )
            

            

    def go_back(self, instance):
        self.manager.current = "main"



# ---------------------------------
# App
# ---------------------------------
class ScreenMonitorApp(App):

    def build(self):
        sm = ScreenManager()
        sm.add_widget(MainScreen(name="main"))
        sm.add_widget(StatsScreen(name="stats"))
        sm.add_widget(GroupScreen(name="group"))

        return sm

    def on_stop(self):
        main_screen = self.root.get_screen("main")

        if main_screen._screen_on:
            main_screen.save_current_session()


if __name__ == "__main__":
    ScreenMonitorApp().run()


