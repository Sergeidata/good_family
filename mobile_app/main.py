from kivy.app import App
from kivy.uix.label import Label
from kivy.clock import Clock

from stats_collector import get_screen_time_today


class MyApp(App):

    def build(self):
        self.label = Label(text="Loading...")
        Clock.schedule_interval(self.update_time, 5)
        return self.label

    def update_time(self, dt):
        seconds = get_screen_time_today()
        hours = seconds / 3600

        self.label.text = f"Screen time today:\n{hours:.2f} hours"


if __name__ == "__main__":
    MyApp().run()