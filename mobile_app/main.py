from kivy.app import App
from kivy.uix.label import Label


class GoodFamilyApp(App):

    def build(self):
        return Label(
            text="Good Family MVP",
            font_size=40
        )


if __name__ == "__main__":
    GoodFamilyApp().run()