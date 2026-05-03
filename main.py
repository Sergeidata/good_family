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
from dataclasses import dataclass

from usage_stats import (
    has_usage_stats_permission,
    request_usage_stats_permission,
    get_usage_stats,
    collect_and_send
)

@dataclass
class Member:
    id: int
    name: str
    role: str
    balance_bonus: float = 0.0
    balance_real: float = 0.0

parent = Member(id=1, name="Мама", role="parent")
child  = Member(id=2, name="Миша", role="child")
conversion_rate: float = 1.0


def show_error(message):
    layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(10))
    layout.add_widget(Label(text=message))
    btn = Button(text="OK", size_hint=(1, None), height=dp(44))
    layout.add_widget(btn)
    popup = Popup(title="Ошибка", content=layout, size_hint=(0.8, 0.4))
    btn.bind(on_press=popup.dismiss)
    popup.open()


class ParentScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=dp(30), spacing=dp(16))

        layout.add_widget(Label(text="Family Focus", font_size=dp(26)))
        layout.add_widget(Label(text="Курс: 1 минута = ? рублей"))

        self.rate_input = TextInput(
            hint_text="Например: 5",
            input_filter="float",
            multiline=False,
            size_hint=(1, None),
            height=dp(50)
        )
        layout.add_widget(self.rate_input)

        btn = Button(text="Подтвердить", size_hint=(1, None), height=dp(50))
        btn.bind(on_press=self.confirm_rate)
        layout.add_widget(btn)

        self.add_widget(layout)

    def confirm_rate(self, *args):
        global conversion_rate
        try:
            value = float(self.rate_input.text.replace(",", "."))
            if value <= 0:
                raise ValueError
            conversion_rate = value
            self.manager.current = "child"
        except:
            show_error("Введите корректное число")


class ChildScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(12))

        layout.add_widget(Label(text="Привет!", font_size=dp(24)))

        btn_refresh = Button(
            text="Обновить (список приложений)",
            size_hint=(1, None),
            height=dp(50)
        )
        btn_refresh.bind(on_press=self.on_refresh)
        layout.add_widget(btn_refresh)

        btn_timer = Button(text="Начать сессию", size_hint=(1, None), height=dp(50))
        btn_timer.bind(on_press=self.go_to_timer)
        layout.add_widget(btn_timer)

        self.add_widget(layout)

    def on_enter(self):
        if not has_usage_stats_permission():
            self.show_permission_dialog()

    def show_permission_dialog(self):
        layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(10))

        layout.add_widget(Label(text="Нужно разрешение на доступ к статистике"))

        btn = Button(text="Открыть настройки", size_hint=(1, None), height=dp(44))
        layout.add_widget(btn)

        popup = Popup(title="Разрешение", content=layout, size_hint=(0.8, 0.4))

        def open_settings(*args):
            request_usage_stats_permission()
            popup.dismiss()

        btn.bind(on_press=open_settings)

        popup.open()

    def show_usage(self, *args):
        if not has_usage_stats_permission():
            self.show_permission_dialog()
            return

        data = get_usage_stats()

        layout = BoxLayout(orientation="vertical", size_hint_y=None, padding=10, spacing=5)
        layout.bind(minimum_height=layout.setter('height'))

        if not data:
            layout.add_widget(Label(text="Нет данных"))
        else:
            for pkg, minutes in data:
                layout.add_widget(Label(
                    text=f"{pkg} — {minutes:.1f} мин",
                    size_hint_y=None,
                    height=dp(30)
                ))

        scroll = ScrollView()
        scroll.add_widget(layout)

        popup = Popup(
            title="Использование приложений",
            content=scroll,
            size_hint=(0.9, 0.9)
        )
        popup.open()

    def go_to_timer(self, *args):
        self.manager.current = "balance"

    def on_refresh(self, *args):
        if not has_usage_stats_permission():
            self.show_permission_dialog()
            return

        result = collect_and_send()
        print("SERVER RESPONSE:", result)

        self.show_usage()
        
class BalanceScreen(Screen):
    def __init__(self, **kwargs):
        super().__init__(**kwargs)

        self._seconds = 0
        self._event = None

        layout = BoxLayout(orientation="vertical", padding=dp(20), spacing=dp(10))

        self.timer_label = Label(text="00:00", font_size=dp(40))
        layout.add_widget(self.timer_label)

        btn_start = Button(text="Старт", size_hint=(1, None), height=dp(50))
        btn_start.bind(on_press=self.start)
        layout.add_widget(btn_start)

        btn_stop = Button(text="Стоп", size_hint=(1, None), height=dp(50))
        btn_stop.bind(on_press=self.stop)
        layout.add_widget(btn_stop)

        self.balance_label = Label(text="0 руб")
        layout.add_widget(self.balance_label)

        self.add_widget(layout)

    def start(self, *args):
        self._seconds = 0
        if self._event:
            self._event.cancel()
        self._event = Clock.schedule_interval(self.tick, 1)

    def tick(self, dt):
        self._seconds += 1
        m, s = divmod(self._seconds, 60)
        self.timer_label.text = f"{m:02}:{s:02}"

    def stop(self, *args):
        if self._event:
            self._event.cancel()

        minutes = self._seconds / 60
        earned = minutes * conversion_rate

        child.balance_real += earned

        self.balance_label.text = f"{child.balance_real:.2f} руб"


class FamilyFocusApp(App):
    def build(self):
        sm = ScreenManager()
        sm.add_widget(ParentScreen(name="parent"))
        sm.add_widget(ChildScreen(name="child"))
        sm.add_widget(BalanceScreen(name="balance"))
        return sm


if __name__ == "__main__":
    FamilyFocusApp().run()