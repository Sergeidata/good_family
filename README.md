# Good Family

Семейное приложение для здоровых цифровых привычек: родители и дети следят
за экранным временем, выполняют задания, зарабатывают звёзды и получают награды
в общем семейном пространстве.

## Что делает приложение

- **Экранное время** — сбор статистики использования приложений на Android,
  разбивка по дням/неделям/месяцам, определение времени в соцсетях.
- **Семейная группа** — создание семьи по пригласительному коду, роли
  (организатор / родитель / ребёнок), рейтинг участников.
- **Задания («хорошие дела»)** — создание заданий, назначение ребёнку,
  подтверждение выполнения, повторяющиеся задачи (будни/выходные).
- **Награды и звёзды** — магазин наград, балансы детей, запросы на покупку
  и их подтверждение.
- **Достижения и сад** — личные и групповые достижения, «сад» семьи,
  который растёт с прогрессом.

Приложение рассчитано на Android-устройства и синхронизируется через общий
сервер, чтобы все члены семьи видели актуальные данные.

## Технологии

- **Клиент:** Flutter / Dart, Android (Kotlin), локальное хранилище
  (`shared_preferences`, файлы в `path_provider`), работа с нативными
  правами через `MethodChannel`.
- **Сервер:** Python 3, Flask, `psycopg2` (PostgreSQL), Gunicorn.
- **БД:** PostgreSQL.

## Структура проекта

```
lib/                     # Flutter-клиент
  screens/               # экраны (главная, семья, достижения, задания, статистика, магазин)
  services/              # API-клиент, хранилища, обёртки нативных каналов
  widgets/               # переиспользуемые виджеты (нижняя панель, пикер эмодзи)
  utils/                 # утилиты (форматирование, имена приложений, snackbar'ы)
  main.dart              # точка входа
server/                  # Python-бэкенд
  server.py              # Flask-приложение, все маршруты и схема БД
  requirements.txt       # зависимости Python
  familyfocus.db         # локальная SQLite-копия (артефакт, в проде не используется)
android/                 # нативная Android-часть
  app/src/main/kotlin/   # MainActivity, SyncService (фоновый сбор и синхронизация)
assets/                  # анимации (Lottie)
mobile_app/              # ранний прототип на Kivy (не используется Flutter-сборкой)
test/                    # тесты Flutter
```

## Запуск локально

### Требования

- Flutter SDK (3.x) и Android SDK
- Python 3.10+
- PostgreSQL (локально или в Docker)

### Установка зависимостей

Сервер:

```bash
cd server
python -m venv .venv
source .venv/bin/activate      # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Клиент:

```bash
flutter pub get
```

### Настройка БД

Создайте базу и пользователя, затем укажите строку подключения в переменной
окружения `DATABASE_URL` (значение по умолчанию задано в `server.py` — при
локальной разработке переопределите его под своё окружение):

```bash
export DATABASE_URL="postgresql://USER:PASSWORD@localhost:5432/familyfocus"
```

Таблицы создаются автоматически при запуске сервера (`init_db()` в `server.py`).

### Запуск сервера

```bash
cd server
python server.py        # слушает 0.0.0.0:5000
```

Проверка: `curl http://localhost:5000/ping`.

### Запуск клиента

Адрес сервера задан в `lib/services/api_service.dart` (константа `baseUrl`).
Для локального запуска укажите адрес локального сервера:

```dart
static const String baseUrl = "http://<ВАШ_СЕРВЕР>:5000";
```

Затем:

```bash
flutter run --release
```

> Сервер работает по HTTP без шифрования. Для реального использования
> настройте HTTPS (обратный прокси) и укажите HTTPS-адрес в `baseUrl`.

## Деплой сервера (кратко)

1. Разверните приложение через Gunicorn с несколькими воркерами:

   ```bash
   gunicorn -w 4 -b 0.0.0.0:8000 server:app
   ```

2. Настройте переменную `DATABASE_URL` и, при необходимости, `EXPORT_STATS_SECRET`
   в окружении процесса (systemd `Environment=` / `EnvironmentFile=`, или
   переменная окружения в Docker-контейнере).

3. По желанию — обратный прокси (nginx) для HTTPS и раздачи статики.

4. Каталог для загружаемых аватаров задан в `server.py` (`UPLOAD_FOLDER`);
   убедитесь, что он существует и доступен процессу на запись.

## Переменные окружения

| Переменная | Назначение |
|---|---|
| `DATABASE_URL` | Строка подключения к PostgreSQL |
| `EXPORT_STATS_SECRET` | Секрет для доступа к `/export_stats` (административная статистика). Если не задана, эндпоинт отвечает `403` |

## Основные эндпоинты API

- Семья: `POST /create_family`, `POST /join_family`, `GET /family_members`,
  `POST /remove_member`, `POST /update_member`, `GET /family_info`
- Статистика: `POST /upload`, `GET /stats`, `GET /family_daily_stats`,
  `GET /family_member_status`
- Задания: `POST /tasks/create`, `POST /tasks/done`, `POST /tasks/approve`,
  `POST /tasks/reject`, `POST /tasks/retry`, `POST /tasks/delete`, `GET /tasks`
- Награды: `GET /reward_shop`, `POST /reward_shop/create`, `POST /reward_shop/update`,
  `POST /reward_shop/delete`, `POST /reward_shop/buy`, `GET /child_balance`,
  `GET /reward_requests`, `POST /reward_requests/approve`, `POST /reward_requests/confirm`,
  `POST /reward_requests/reject`
- Достижения: `GET /achievements`, `POST /achievements/check`, `GET /achievement_progress`,
  `GET /personal_achievements`
- Прочее: `GET /garden`, `POST /garden/levelup`, `GET /latest_version`,
  `POST /upload_avatar`, `GET /export_stats`, `GET /ping`

Полные параметры тел запросов и формат ответов смотрите в `server.py`.

## Публикация

Приложение распространяется через RuStore

- https://apps.rustore.ru/app/com.example.family_focus

## Примечание

`mobile_app/` — ранний прототип на Kivy, не используется текущей Flutter-сборкой
и не собирается вместе с ней. Оставлен в репозитории как справочный материал.
