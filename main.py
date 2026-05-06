from kivy.app import App
from kivy.uix.screenmanager import ScreenManager, Screen
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.button import Button
from kivy.clock import Clock
from kivy.metrics import dp

import threading

from api import create_family, join_family, get_family_usage
from usage_stats import collect_and_send
from api import SESSION


APP_STATE = {
    "family_id": None,
    "invite_code": None,
    "user_id": None,
}


# =====================
# MENU
# =====================

class MenuScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=30, spacing=20)

        layout.add_widget(Label(text="Family Focus", font_size=26))

        btn1 = Button(text="Создать семью")
        btn1.bind(on_press=lambda x: self.go_parent())
        layout.add_widget(btn1)

        btn2 = Button(text="Вступить в семью")
        btn2.bind(on_press=lambda x: self.go_join())
        layout.add_widget(btn2)

        btn3 = Button(text="Открыть дашборд")
        btn3.bind(on_press=lambda x: self.go_dashboard())
        layout.add_widget(btn3)

        self.add_widget(layout)

    def go_parent(self):
        self.manager.current = "parent"

    def go_join(self):
        self.manager.current = "join"

    def go_dashboard(self):
        if APP_STATE["family_id"]:
            self.manager.current = "dashboard"


# =====================
# CREATE FAMILY
# =====================

class ParentScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=30, spacing=15)

        self.input = TextInput(hint_text="Название семьи")
        layout.add_widget(self.input)

        btn = Button(text="Создать")
        btn.bind(on_press=self.create)
        layout.add_widget(btn)

        self.add_widget(layout)

    def create(self, *args):
        threading.Thread(target=self._create).start()

    def _create(self):
        res = create_family(self.input.text)

        APP_STATE["family_id"] = res["family_id"]
        APP_STATE["invite_code"] = res["invite_code"]

        Clock.schedule_once(lambda dt: setattr(self.manager, "current", "dashboard"))


# =====================
# JOIN FAMILY
# =====================

class JoinScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=30, spacing=15)

        self.code = TextInput(hint_text="Invite code")
        self.name_input = TextInput(hint_text="Имя")

        layout.add_widget(self.code)
        layout.add_widget(self.name)

        btn = Button(text="Войти")
        btn.bind(on_press=self.join)
        layout.add_widget(btn)

        self.add_widget(layout)

    def join(self, *args):
        threading.Thread(target=self._join).start()

    def _join(self):
        res = join_family(self.code.text, self.name.text)

        APP_STATE["family_id"] = res["family_id"]
        APP_STATE["user_id"] = res["user_id"]

        Clock.schedule_once(lambda dt: setattr(self.manager, "current", "dashboard"))


# =====================
# DASHBOARD
# =====================

class Dashboard(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=20, spacing=10)

        self.label = Label(text="Дашборд")
        layout.add_widget(self.label)

        btn = Button(text="Обновить активность")
        btn.bind(on_press=self.refresh)
        layout.add_widget(btn)

        self.add_widget(layout)

    def refresh(self, *args):
        threading.Thread(target=self._refresh).start()

    def _refresh(self):
        collect_and_send()
        data = get_family_usage()

        Clock.schedule_once(lambda dt: self.render(data))

    def render(self, data):
        text = ""

        for user, minutes in data.items():
            text += f"{user}: {int(minutes)} мин\n"

        self.label.text = text


# =====================
# APP
# =====================

class AppMain(App):
    def build(self):
        sm = ScreenManager()

        sm.add_widget(MenuScreen(name="menu"))
        sm.add_widget(ParentScreen(name="parent"))
        sm.add_widget(JoinScreen(name="join"))
        sm.add_widget(Dashboard(name="dashboard"))

        return sm


if __name__ == "__main__":
    AppMain().run()