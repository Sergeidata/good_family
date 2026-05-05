from kivy.app import App
from kivy.uix.screenmanager import ScreenManager, Screen
from kivy.uix.boxlayout import BoxLayout
from kivy.uix.label import Label
from kivy.uix.textinput import TextInput
from kivy.uix.button import Button
from kivy.uix.popup import Popup
from kivy.clock import Clock
from kivy.metrics import dp
from kivy.uix.scrollview import ScrollView

import threading

from api import create_family, register_child, get_family_data

from permissions import (
    has_usage_stats_permission,
    request_usage_stats_permission
)
from usage_stats import collect_and_send
from api import SESSION

# =====================
# GLOBAL STATE
# =====================

APP_STATE = {
    "family_id": None,
    "invite_code": None,
    "user_id": None,
    "role": None,
}


def show_error(message):
    layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(10))
    layout.add_widget(Label(text=message))

    btn = Button(text="OK", size_hint=(1, None), height=dp(44))
    layout.add_widget(btn)

    popup = Popup(title="Ошибка", content=layout, size_hint=(0.8, 0.4))
    btn.bind(on_press=popup.dismiss)
    popup.open()


def show_permission_dialog():
    layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(10))

    layout.add_widget(Label(text="Нужно разрешение Usage Stats"))

    btn = Button(text="Открыть настройки", size_hint=(1, None), height=dp(44))
    layout.add_widget(btn)

    popup = Popup(title="Разрешение", content=layout, size_hint=(0.8, 0.4))

    def open_settings(instance):
        request_usage_stats_permission()
        popup.dismiss()

    btn.bind(on_press=open_settings)
    popup.open()


# =====================
# MENU SCREEN
# =====================

class MenuScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=dp(30), spacing=dp(20))

        layout.add_widget(Label(text="Family Focus", font_size=dp(26)))

        btn_parent = Button(text="Я родитель", size_hint=(1, None), height=dp(50))
        btn_parent.bind(on_press=self.go_parent)

        btn_child = Button(text="Я ребенок", size_hint=(1, None), height=dp(50))
        btn_child.bind(on_press=self.go_child)

        layout.add_widget(btn_parent)
        layout.add_widget(btn_child)

        self.add_widget(layout)

    def go_parent(self, *args):
        self.manager.current = "parent"

    def go_child(self, *args):
        self.manager.current = "child_register"


# =====================
# PARENT CREATE FAMILY
# =====================

class ParentScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=dp(30), spacing=dp(16))

        layout.add_widget(Label(text="Создать семью", font_size=dp(22)))

        self.input = TextInput(
            hint_text="Название семьи",
            multiline=False,
            size_hint=(1, None),
            height=dp(50)
        )
        layout.add_widget(self.input)

        btn = Button(text="Создать", size_hint=(1, None), height=dp(50))
        btn.bind(on_press=self.on_create)
        layout.add_widget(btn)

        back = Button(text="Назад", size_hint=(1, None), height=dp(50))
        back.bind(on_press=self.go_menu)
        layout.add_widget(back)

        self.add_widget(layout)

    def go_menu(self, *args):
        self.manager.current = "menu"

    def on_create(self, *args):
        name = self.input.text.strip()
        if not name:
            show_error("Введите название семьи")
            return

        threading.Thread(target=self._create, args=(name,)).start()

    def _create(self, name):
        result = create_family(name)
        print("CREATE FAMILY:", result)

        if "error" in result:
            Clock.schedule_once(lambda dt: show_error(result["error"]))
            return

        APP_STATE["family_id"] = result["family_id"]
        APP_STATE["invite_code"] = result["invite_code"]
        APP_STATE["role"] = "parent"

        Clock.schedule_once(lambda dt: self.go_dashboard())

    def go_dashboard(self):
        self.manager.current = "parent_dashboard"


# =====================
# CHILD REGISTER
# =====================

class ChildRegisterScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=dp(30), spacing=dp(16))

        layout.add_widget(Label(text="Регистрация ребенка", font_size=dp(22)))

        self.code_input = TextInput(
            hint_text="Invite code",
            multiline=False,
            size_hint=(1, None),
            height=dp(50)
        )
        layout.add_widget(self.code_input)

        self.name_input = TextInput(
            hint_text="Имя",
            multiline=False,
            size_hint=(1, None),
            height=dp(50)
        )
        layout.add_widget(self.name_input)

        btn = Button(text="Зарегистрироваться", size_hint=(1, None), height=dp(50))
        btn.bind(on_press=self.on_register)
        layout.add_widget(btn)

        back = Button(text="Назад", size_hint=(1, None), height=dp(50))
        back.bind(on_press=self.go_menu)
        layout.add_widget(back)

        self.add_widget(layout)

    def go_menu(self, *args):
        self.manager.current = "menu"

    def on_register(self, *args):
        code = self.code_input.text.strip()
        name = self.name_input.text.strip()

        if not code or not name:
            show_error("Заполни все поля")
            return

        threading.Thread(target=self._register, args=(code, name)).start()

    def _register(self, code, name):
        result = register_child(code, name)
        print("REGISTER:", result)

        if "error" in result:
            Clock.schedule_once(lambda dt: show_error(result["error"]))
            return

        APP_STATE["user_id"] = result["user_id"]
        APP_STATE["family_id"] = result["family_id"]
        APP_STATE["role"] = "child"

        Clock.schedule_once(lambda dt: self.go_child())

    def go_child(self):
        self.manager.current = "child"


# =====================
# CHILD SCREEN
# =====================

class ChildScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(12))

        layout.add_widget(Label(text="Ребёнок", font_size=dp(24)))

        self.invite_input = TextInput(hint_text="Invite code", multiline=False)
        layout.add_widget(self.invite_input)

        self.name_input = TextInput(hint_text="Имя", multiline=False)
        layout.add_widget(self.name_input)

        btn_register = Button(text="Зарегистрироваться")
        btn_register.bind(on_press=self.on_register)
        layout.add_widget(btn_register)

        btn_refresh = Button(text="Обновить активность")
        btn_refresh.bind(on_press=self.on_refresh)
        layout.add_widget(btn_refresh)

        self.output = Label(text="")
        layout.add_widget(self.output)

        self.add_widget(layout)

    def on_pre_enter(self):
        Clock.schedule_once(lambda dt: self.force_permission_check(), 0.5)

    def check_permission(self):
        try:
            if not has_usage_stats_permission():
                show_permission_dialog()
        except Exception as e:
            show_error(f"Permission error: {e}")

    def on_register(self, *args):
        invite = self.invite_input.text.strip()
        name = self.name_input.text.strip()

        if not invite or not name:
            show_error("Введите код и имя")
            return

        try:
            result = register_child(invite, name)

            print("REGISTER RESULT:", result)

            if not isinstance(result, dict):
                show_error("Ошибка сервера: неверный ответ")
                return

            if "error" in result:
                show_error(result["error"])
                return

            self.output.text = "Успешно зарегистрирован"

        except Exception as e:
            print("REGISTER ERROR:", e)
            show_error(f"Ошибка регистрации: {e}")

    def on_refresh(self, *args):
        try:
            if not has_usage_stats_permission():
                show_permission_dialog()
                return

            data = collect_and_send()
            self.output.text = str(data)

        except Exception as e:
            show_error(f"Ошибка: {e}")

    def go_menu(self, *args):
        self.manager.current = "menu"

    def load_data(self, *args):
        threading.Thread(target=self._load).start()

    def _load(self):
        try:
            result = get_family_data(APP_STATE["family_id"])
            print("DATA:", result)

            Clock.schedule_once(lambda dt: self.show_data(result))

        except Exception as e:
            print("LOAD ERROR:", e)
            Clock.schedule_once(lambda dt: show_error(str(e)))

    def show_data(self, data):
        if not data:
            show_error("Пустые данные")
            return

        if isinstance(data, dict) and "error" in data:
            show_error(data["error"])
            return

        popup_layout = BoxLayout(orientation="vertical")

        for user in data.get("users", []):
            popup_layout.add_widget(Label(text=user.get("name", "unknown")))

        popup = Popup(title="Семья", content=popup_layout, size_hint=(0.8, 0.8))
        popup.open()

    def force_permission_check(self):
        try:
            if not has_usage_stats_permission():
                show_permission_dialog()
            else:
                # 👇 иногда система врет — всё равно откроем один раз
                print("Permission looks granted, but forcing check")
        except Exception as e:
            print("PERMISSION ERROR:", e)
            show_permission_dialog()

# =====================
# PARENT DASHBOARD
# =====================

class ParentDashboard(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(10))

        self.label = Label(text="Дашборд родителя", font_size=dp(22))
        layout.add_widget(self.label)

        self.code_label = Label(text="")
        layout.add_widget(self.code_label)

        btn_refresh = Button(text="Обновить", size_hint=(1, None), height=dp(50))
        btn_refresh.bind(on_press=self.load_data)
        layout.add_widget(btn_refresh)

        back = Button(text="Назад", size_hint=(1, None), height=dp(50))
        back.bind(on_press=self.go_menu)
        layout.add_widget(back)

        self.add_widget(layout)

    def on_enter(self):
        self.code_label.text = f"Invite code: {APP_STATE['invite_code']}"

    def go_menu(self, *args):
        self.manager.current = "menu"

    def load_data(self, *args):
        threading.Thread(target=self._load).start()

    def _load(self):
        result = get_family_data(APP_STATE["family_id"])
        print("PARENT DATA:", result)

        Clock.schedule_once(lambda dt: self.show_data(result))

    def show_data(self, data):
        if "error" in data:
            show_error(data["error"])
            return

        text = "Участники:\n"
        for u in data.get("users", []):
            text += f"- {u['name']} ({u['role']})\n"

        self.label.text = text


# =====================
# APP
# =====================

class FamilyApp(App):
    def build(self):
        sm = ScreenManager()
        sm.add_widget(MenuScreen(name="menu"))
        sm.add_widget(ParentScreen(name="parent"))
        sm.add_widget(ChildRegisterScreen(name="child_register"))
        sm.add_widget(ChildScreen(name="child"))
        sm.add_widget(ParentDashboard(name="parent_dashboard"))
        return sm


if __name__ == "__main__":
    FamilyApp().run()