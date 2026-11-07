from flask import Flask, jsonify, request
from datetime import datetime, timedelta
import psycopg2
import json
import uuid
import random
import os
import secrets
import smtplib
from email.mime.text import MIMEText
from email.header import Header
from PIL import Image
import bcrypt

from flask import send_from_directory



UPLOAD_FOLDER = "/opt/goodfamily/uploads/avatars"
app = Flask(__name__)


# ---------------------------------
# Database
# ---------------------------------
def get_connection():

    # Продакшен: задавайте через systemd Environment= / EnvironmentFile=
    DATABASE_URL = os.environ.get("DATABASE_URL")

    if not DATABASE_URL:
        raise RuntimeError(
            "DATABASE_URL не задан. Пропишите его в /opt/goodfamily/.env "
            "или в systemd EnvironmentFile."
        )

    return psycopg2.connect(DATABASE_URL)


# ---------------------------------
# SMTP (Yandex)
# ---------------------------------
def send_email(to, subject, body):
    """Отправка письма через Yandex SMTP (SSL 465). True при успехе."""
    smtp_user = os.environ.get("SMTP_USER", "")
    smtp_password = os.environ.get("SMTP_PASSWORD", "")
    smtp_host = os.environ.get("SMTP_HOST", "smtp.yandex.com")
    smtp_port = int(os.environ.get("SMTP_PORT", "465"))

    if not smtp_user or not smtp_password:
        print("SMTP NOT CONFIGURED (SMTP_USER/SMTP_PASSWORD)")
        return False

    try:
        msg = MIMEText(body, "plain", "utf-8")
        msg["Subject"] = Header(subject, "utf-8")
        msg["From"] = smtp_user
        msg["To"] = to

        with smtplib.SMTP_SSL(smtp_host, smtp_port, timeout=20) as server:
            server.login(smtp_user, smtp_password)
            server.send_message(msg)

        return True
    except Exception as e:
        print(f"SEND EMAIL ERROR: {e}")
        return False


def init_db():
    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        CREATE TABLE IF NOT EXISTS screen_time (
            id SERIAL PRIMARY KEY,
            user_id TEXT NOT NULL,
            date DATE NOT NULL,
            total_seconds INTEGER DEFAULT 0,
            social_seconds INTEGER DEFAULT 0,
            top_apps JSONB DEFAULT '[]',
            created_at TIMESTAMP DEFAULT NOW()
        );
    """)

    cur.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_user_date
        ON screen_time(user_id, date);
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS families (
            id SERIAL PRIMARY KEY,
            family_id TEXT UNIQUE NOT NULL,
            family_name TEXT NOT NULL,
            invite_code TEXT UNIQUE NOT NULL,
            created_at TIMESTAMP DEFAULT NOW()
        );
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS members (
            id SERIAL PRIMARY KEY,
            family_id TEXT NOT NULL,
            user_name TEXT NOT NULL,
            role TEXT DEFAULT 'member',
            joined_at TIMESTAMP DEFAULT NOW()
        );
    """)

    cur.execute("ALTER TABLE members ADD COLUMN IF NOT EXISTS device_id TEXT")
    cur.execute("ALTER TABLE members ADD COLUMN IF NOT EXISTS avatar TEXT")
    cur.execute("ALTER TABLE members ADD COLUMN IF NOT EXISTS user_id INTEGER")

    cur.execute("""
        CREATE TABLE IF NOT EXISTS users (
            id SERIAL PRIMARY KEY,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            email_verified BOOLEAN DEFAULT FALSE,
            verification_code TEXT,
            verification_expires_at TIMESTAMP,
            created_at TIMESTAMP DEFAULT NOW()
        );
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS sessions (
            id SERIAL PRIMARY KEY,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            token TEXT UNIQUE NOT NULL,
            expires_at TIMESTAMP NOT NULL,
            created_at TIMESTAMP DEFAULT NOW()
        );
    """)

    cur.execute(
        "CREATE INDEX IF NOT EXISTS idx_sessions_token ON sessions(token)"
    )

    # Один аккаунт (user_id) может быть только в одной семье.
    cur.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_members_user_id
        ON members(user_id) WHERE user_id IS NOT NULL
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS achievements (
            id SERIAL PRIMARY KEY,
            user_name TEXT NOT NULL,
            family_id TEXT NOT NULL,
            achievement_key TEXT NOT NULL,
            period TEXT NOT NULL,
            earned_date DATE NOT NULL
        );
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS garden (
            id SERIAL PRIMARY KEY,
            family_id TEXT UNIQUE NOT NULL,
            level INTEGER DEFAULT 1,
            achievement_progress REAL DEFAULT 0,
            updated_at TIMESTAMP DEFAULT NOW()
        );
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS tasks (
            id SERIAL PRIMARY KEY,
            family_id TEXT NOT NULL,
            title TEXT NOT NULL,
            stars INTEGER DEFAULT 10,
            created_by TEXT NOT NULL,
            assigned_to TEXT NOT NULL,
            status TEXT DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT NOW(),
            done_at TIMESTAMP,
            approved_at TIMESTAMP,
            repeat_mode TEXT DEFAULT 'none',
            next_available_at TIMESTAMP DEFAULT NOW()
        );
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS task_log (
            id SERIAL PRIMARY KEY,
            task_id INTEGER NOT NULL,
            user_name TEXT NOT NULL,
            action TEXT NOT NULL,
            timestamp TIMESTAMP DEFAULT NOW()
        );
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS reward_shop (
            id SERIAL PRIMARY KEY,
            family_id TEXT NOT NULL,
            title TEXT NOT NULL,
            emoji TEXT DEFAULT '🎁',
            cost_stars INTEGER NOT NULL,
            active BOOLEAN DEFAULT TRUE,
            color_hex TEXT DEFAULT '#FFF4E5',
            description TEXT DEFAULT ''
        );
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS reward_requests (
            id SERIAL PRIMARY KEY,
            family_id TEXT NOT NULL,
            reward_id INTEGER NOT NULL REFERENCES reward_shop(id),
            child_name TEXT NOT NULL,
            cost_stars INTEGER NOT NULL,
            status TEXT DEFAULT 'pending',
            created_at TIMESTAMP DEFAULT NOW(),
            approved_at TIMESTAMP
        );
    """)

    


    cur.execute("""
        CREATE TABLE IF NOT EXISTS reward_types (
            id SERIAL PRIMARY KEY,
            family_id TEXT NOT NULL,
            name TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT NOW(),
            UNIQUE(family_id, name)
        )
    """)

    cur.execute("""
        CREATE TABLE IF NOT EXISTS payouts (
            id SERIAL PRIMARY KEY,
            family_id TEXT NOT NULL,
            child_name TEXT NOT NULL,
            amount_rub INTEGER NOT NULL,
            status TEXT DEFAULT 'pending'
                CHECK(status IN ('pending','confirmed')),
            created_at TIMESTAMP DEFAULT NOW(),
            confirmed_at TIMESTAMP
        )
        """)

    conn.commit()
    cur.close()
    conn.close()


init_db()

@app.route("/uploads/<path:filename>")
def uploaded_file(filename):
    return send_from_directory("/opt/goodfamily/uploads/avatars", filename)
# ---------------------------------
# Helpers
# ---------------------------------
def get_period_dates(period):
    today = datetime.now().date()

    if period == "today":
        start_date = today
        end_date = today

    elif period == "yesterday":
        start_date = today - timedelta(days=1)
        end_date = start_date

    elif period == "week":
        # С начала текущей недели (понедельник)
        start_date = today - timedelta(days=today.weekday())
        end_date = today

    elif period == "month":
        # С начала текущего месяца (1 число)
        start_date = today.replace(day=1)
        end_date = today

    else:
        start_date = today
        end_date = today

    return (str(start_date), str(end_date))


# ---------------------------------
# Routes
# ---------------------------------
@app.route("/")
def home():
    return "Family Focus API"


@app.route("/ping")
def ping():

    return jsonify({
        "status": "ok",
        "time": datetime.utcnow().isoformat()
    })


@app.route("/upload", methods=["POST"])
def upload():
    try:
        data = request.get_json()

        user_id = data.get("user_id")
        date = data.get("date")
        total_seconds = data.get("total_seconds", 0)
        social_seconds = data.get("social_seconds", 0)
        top_apps = data.get("top_apps", [])

        if not user_id or not date:
            return jsonify({
                "status": "error",
                "message": "user_id and date required"
            }), 400

        # Если клиент не прислал — считаем из top_apps
        if social_seconds == 0 and top_apps:
            social_packages = {
                "com.instagram.android",
                "com.facebook.katana",
                "com.facebook.orca",
                "com.vkontakte.android",
                "com.twitter.android",
                "com.ss.android.ugc.trill",
                "com.zhiliaoapp.musically",
                "com.snapchat.android",
                "com.linkedin.android",
                "com.pinterest",
                "com.reddit.frontpage",
            }
            total_social_minutes = 0
            for app in top_apps:
                if app.get("app") in social_packages:
                    total_social_minutes += app.get("minutes", 0)
            social_seconds = total_social_minutes * 60

        conn = get_connection()
        cur = conn.cursor()

        top_apps_json = json.dumps(top_apps)

        cur.execute("""
            INSERT INTO screen_time (user_id, date, total_seconds, social_seconds, top_apps)
            VALUES (%s, %s, %s, %s, %s)
            ON CONFLICT (user_id, date)
            DO UPDATE SET
                total_seconds = EXCLUDED.total_seconds,
                social_seconds = EXCLUDED.social_seconds,
                top_apps = EXCLUDED.top_apps,
                created_at = NOW()
        """, (user_id, date, total_seconds, social_seconds, top_apps_json))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok"})

    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route("/stats")
def stats():

    try:

        user_id = request.args.get(
            "user_id"
        )

        period = request.args.get(
            "period",
            "today"
        )

        if not user_id:

            return jsonify({
                "status": "error",
                "message": "user_id required"
            }), 400

        start_date, end_date = (
            get_period_dates(period)
        )

        conn = get_connection()

        cur = conn.cursor()

        cur.execute("""
            SELECT
                total_seconds,
                top_apps
            FROM screen_time
            WHERE user_id = %s
            AND date BETWEEN %s AND %s
        """, (
            user_id,
            start_date,
            end_date
        ))

        rows = cur.fetchall()

        total_seconds = 0

        app_totals = {}

        for row in rows:

            total = row[0]
            top_apps = row[1]

            total_seconds += total

            if not top_apps:
                continue

            for app in top_apps:

                app_name = app.get("app")

                minutes = app.get(
                    "minutes",
                    0
                )

                if not app_name:
                    continue

                app_totals[app_name] = (
                    app_totals.get(
                        app_name,
                        0
                    ) + minutes
                )

        if period in ["week", "month"]:

            now = datetime.now()

            if period == "week":

                days_passed = (
                        now.weekday() + 1
                )

            else:

                days_passed = now.day

            if days_passed < 1:
                days_passed = 1

            total_seconds = int(
                total_seconds / days_passed
            )

            averaged_apps = {}

            for app_name, minutes in (
                    app_totals.items()
            ):
                averaged_apps[app_name] = int(
                    minutes / days_passed
                )

            app_totals = averaged_apps

        sorted_apps = sorted(
            app_totals.items(),
            key=lambda x: x[1],
            reverse=True
        )

        aggregated_apps = []

        for app_name, minutes in sorted_apps:

            aggregated_apps.append({
                "app": app_name,
                "minutes": minutes
            })

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "user_id": user_id,
            "period": period,
            "total_seconds": total_seconds,
            "top_apps": aggregated_apps
        })

    except Exception as e:

        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

# ---------------------------------
# семья
# ---------------------------------
@app.route("/create_family", methods=["POST"])
def create_family():
    try:
        data = request.get_json()
        family_name = data.get("family_name", "").strip()
        user_name = data.get("user_name", "").strip()
        device_id = data.get("device_id", "").strip()
        avatar = data.get("avatar", "").strip()

        if not family_name:
            return jsonify({"status": "error", "message": "family_name required"}), 400

        # Опциональная авторизация: токена нет — работаем по-старому.
        auth_user_id = get_auth_user()

        family_id = str(uuid.uuid4())
        invite_code = str(random.randint(100000, 999999))

        conn = get_connection()
        cur = conn.cursor()

        if auth_user_id is not None:
            cur.execute(
                "SELECT family_id FROM members WHERE user_id = %s LIMIT 1",
                (auth_user_id,),
            )
            already = cur.fetchone()

            if already:
                cur.close()
                conn.close()
                return jsonify({
                    "status": "error",
                    "message": "already in another family",
                }), 409

        cur.execute("""
            INSERT INTO families (family_id, family_name, invite_code)
            VALUES (%s, %s, %s)
        """, (family_id, family_name, invite_code))

        cur.execute("""
            INSERT INTO members (
                family_id, user_name, role, avatar, device_id, user_id
            )
            VALUES (%s, %s, 'admin_parent', %s, %s, %s)
        """, (family_id, user_name, avatar, device_id, auth_user_id))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "family_id": family_id,
            "invite_code": invite_code
        })

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

# ---------------------------------
# присоединение к семье
# ---------------------------------
@app.route("/join_family", methods=["POST"])
def join_family():
    try:
        data = request.get_json()
        invite_code = data.get("invite_code", "").strip()
        user_name = data.get("user_name", "").strip()
        device_id = data.get("device_id", "").strip()
        role = data.get("role", "child").strip()
        avatar = data.get("avatar", "").strip()

        if role not in ("parent", "child"):
            return jsonify({"status": "error", "message": "invalid role"}), 400

        if not invite_code:
            return jsonify({"status": "error", "message": "invite_code required"}), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("SELECT family_id, family_name FROM families WHERE invite_code = %s", (invite_code,))
        row = cur.fetchone()

        if not row:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "family not found"}), 404

        family_id = row[0]
        family_name = row[1]

        # Опциональная авторизация: токена нет — работаем по-старому.
        auth_user_id = get_auth_user()

        # Аккаунт уже в другой семье — 409.
        if auth_user_id is not None:
            cur.execute(
                "SELECT family_id FROM members WHERE user_id = %s LIMIT 1",
                (auth_user_id,),
            )
            mine = cur.fetchone()

            if mine and mine[0] != family_id:
                cur.close()
                conn.close()
                return jsonify({
                    "status": "error",
                    "message": "already in another family",
                }), 409

        # Проверка device_id — обновить существующего участника
        if device_id:
            cur.execute("SELECT user_name, role FROM members WHERE family_id = %s AND device_id = %s", (family_id, device_id))
            existing = cur.fetchone()
            
            if existing:
                existing_name, existing_role = existing[0], existing[1]
                # Обновить имя, аватар и (если есть) привязать аккаунт
                cur.execute("""
                    UPDATE members
                    SET user_name = %s,
                        avatar = %s,
                        user_id = COALESCE(user_id, %s)
                    WHERE family_id = %s AND device_id = %s
                """, (user_name, avatar, auth_user_id, family_id, device_id))
                
                conn.commit()
                cur.close()
                conn.close()
                return jsonify({"status": "ok", "family_id": family_id, "family_name": family_name})

        # Не плодим дубликаты: записи, созданные старыми версиями клиента,
        # могли остаться с пустым device_id при том же user_name. Пустой
        # device_id не отклоняем (мягкий режим) — ищем дубль по user_name.
        cur.execute("""
            SELECT id, avatar FROM members
            WHERE family_id = %s AND user_name = %s
              AND (device_id = %s OR device_id IS NULL OR device_id = '')
            ORDER BY id ASC
            LIMIT 1
        """, (family_id, user_name, device_id))

        dup = cur.fetchone()

        if dup:
            member_id, db_avatar = dup

            # Не затираем загруженное фото эмодзи из формы.
            new_avatar = avatar
            if (db_avatar or "").startswith("/uploads/") and not new_avatar.startswith("/uploads/"):
                new_avatar = db_avatar

            cur.execute("""
                UPDATE members
                SET device_id = COALESCE(NULLIF(device_id, ''), %s),
                    avatar = %s,
                    user_id = COALESCE(user_id, %s)
                WHERE id = %s AND family_id = %s
            """, (device_id, new_avatar, auth_user_id, member_id, family_id))

            conn.commit()
            cur.close()
            conn.close()

            return jsonify({"status": "ok", "family_id": family_id, "family_name": family_name})

        # Добавляем нового участника
        cur.execute("""
            INSERT INTO members (
                family_id, user_name, role, avatar, device_id, user_id
            )
            VALUES (%s, %s, %s, %s, %s, %s)
        """, (family_id, user_name, role, avatar, device_id, auth_user_id))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok", "family_id": family_id, "family_name": family_name})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    
   

@app.route("/family_members", methods=["GET"])
def family_members():
    family_id = request.args.get("family_id")
    requester_device_id = request.args.get("requester_device_id", "")

    conn = get_connection()
    cursor = conn.cursor()

    # device_id намеренно НЕ возвращается клиенту: он нужен только
    # для вычисления is_me внутри сервера
    cursor.execute("""
        SELECT id, user_name, role, joined_at, avatar, device_id
        FROM members
        WHERE family_id = %s
        ORDER BY joined_at ASC
    """, (family_id,))

    rows = cursor.fetchall()
    members = []

    for row in rows:
        is_me = bool(
            requester_device_id
            and row[5]
            and row[5] == requester_device_id
        )

        members.append({
            "id": row[0],
            "user_name": row[1],
            "role": row[2],
            "joined_at": str(row[3]),
            "avatar": row[4] or "",
            "device_id": row[5] or "",
            "is_me": is_me,
            "is_admin": (
                is_me
                and row[2] in ("admin", "admin_parent")
            ),
        })

    conn.close()
    return jsonify({"members": members})

@app.route("/remove_member", methods=["POST"])
def remove_member():
    try:
        # ВНИМАНИЕ: device_id не является секретом — он отдаётся всем
        # участникам семьи в /family_members. Эта проверка снижает
        # поверхность атаки, но НЕ устраняет подделку. Полное решение —
        # серверные сессии (см. вариант B).
        data = request.json
        family_id = data.get("family_id")
        member_id = data.get("member_id")
        requester_device_id = data.get("requester_device_id")

        if not family_id or not member_id or not requester_device_id:
            return jsonify({"status": "error", "message": "missing fields"}), 400

        conn = get_connection()
        cur = conn.cursor()

        # Запрашивающий должен быть админом ИМЕННО этой семьи
        cur.execute("""
            SELECT 1 FROM members
            WHERE family_id = %s AND device_id = %s AND role IN ('admin', 'admin_parent')
        """, (family_id, requester_device_id))

        admin_row = cur.fetchone()
        if not admin_row:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "not authorized"}), 403

        # Нельзя оставить семью без администратора
        cur.execute("""
            SELECT COUNT(*) FROM members
            WHERE family_id = %s
              AND role IN ('admin', 'admin_parent')
              AND id <> %s
        """, (family_id, member_id))

        if cur.fetchone()[0] == 0:
            cur.close()
            conn.close()
            return jsonify({
                "status": "error",
                "message": "cannot remove the last admin"
            }), 403

        # Удаляем ровно одну запись и проверяем, что она реально была
        cur.execute("""
            DELETE FROM members
            WHERE family_id = %s AND id = %s
        """, (family_id, member_id))

        if cur.rowcount == 0:
            conn.rollback()
            cur.close()
            conn.close()
            return jsonify({
                "status": "error",
                "message": "member not found"
            }), 404

        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "ok"})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# Выход из семьи: удаляем только свою запись, найденную по device_id.
@app.route("/leave_family", methods=["POST"])
def leave_family():
    try:
        data = request.json
        family_id = data.get("family_id")
        user_name = data.get("user_name")
        requester_device_id = data.get("requester_device_id")

        if not family_id or not user_name or not requester_device_id:
            return jsonify({"status": "error", "message": "missing fields"}), 400

        conn = get_connection()
        cur = conn.cursor()

        # Имя может дублироваться — берём все записи с этим именем в семье
        cur.execute("""
            SELECT id, device_id, role FROM members
            WHERE family_id = %s AND user_name = %s
        """, (family_id, user_name))

        rows = cur.fetchall()
        if not rows:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "not found"}), 404

        member = None
        for row in rows:
            if (row[1] or "") == requester_device_id:
                member = row
                break

        if not member:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "not your account"}), 403

        member_id = member[0]

        # Последний админ не может выйти, иначе семья останется без управления.
        # Проверка только для админа: обычный участник выходит без ограничений.
        if member[2] in ("admin", "admin_parent"):
            cur.execute("""
                SELECT COUNT(*) FROM members
                WHERE family_id = %s
                  AND role IN ('admin', 'admin_parent')
                  AND id <> %s
            """, (family_id, member_id))

            if cur.fetchone()[0] == 0:
                cur.close()
                conn.close()
                return jsonify({
                    "status": "error",
                    "message": "cannot leave as last admin"
                }), 403

        cur.execute("""
            DELETE FROM members
            WHERE id = %s AND family_id = %s
        """, (member_id, family_id))

        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "ok"})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route(
    "/update_member",
    methods=["POST"]
)
@app.route("/update_member", methods=["POST"])
def update_member():
    try:
        data = request.json
        family_id = data.get("family_id")
        old_name = data.get("old_name")
        new_name = data.get("new_name")
        device_id = data.get("device_id")
        avatar = data.get("avatar")

        if not family_id or not old_name or not new_name or not device_id:
            return jsonify({"status": "error", "message": "missing fields"}), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("SELECT user_name FROM members WHERE family_id = %s AND device_id = %s", (family_id, device_id))
        member = cur.fetchone()

        if not member:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "member not found"}), 404

        cur.execute("UPDATE members SET user_name = %s WHERE family_id = %s AND device_id = %s", (new_name, family_id, device_id))
        cur.execute("UPDATE screen_time SET user_id = %s WHERE user_id = %s", (new_name, old_name))

        if avatar is not None:
            cur.execute("UPDATE members SET avatar = %s WHERE family_id = %s AND device_id = %s", (avatar, family_id, device_id))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok"})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500







@app.route("/family_member_status")
def family_member_status():

    try:

        family_id = request.args.get(
            "family_id"
        )

        if not family_id:

            return jsonify({
                "status": "error",
                "message": "family_id required"
            }), 400

        conn = get_connection()

        cur = conn.cursor()

        cur.execute("""
            SELECT
                m.user_name,
                MAX(st.created_at) as last_sync
            FROM members m
            LEFT JOIN screen_time st
                ON m.user_name = st.user_id
            WHERE m.family_id = %s
            GROUP BY m.user_name
            ORDER BY m.user_name
        """, (
            family_id,
        ))

        rows = cur.fetchall()

        members = []

        for row in rows:

            members.append({
                "user_name": row[0],
                "last_sync": (
                    row[1].isoformat()
                    if row[1]
                    else None
                )
            })

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "members": members
        })

    except Exception as e:

        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

@app.route("/family_info")
def family_info():

    family_id = request.args.get(
        "family_id"
    )

    if not family_id:

        return jsonify({
            "status": "error",
            "message": "family_id required"
        }), 400

    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT
            family_name,
            invite_code,
            created_at
        FROM families
        WHERE family_id = %s
    """, (
        family_id,
    ))

    row = cur.fetchone()

    if not row:
        return jsonify({
            "status": "error"
        }), 404

    result = {
        "family_name": row[0],
        "invite_code": row[1],
        "created_at": str(row[2])
    }

    cur.close()
    conn.close()

    return jsonify({
        "status": "ok",
        **result
    })


@app.route("/achievements/check", methods=["POST"])
def achievement_check():
    try:
        data = request.get_json()

        family_id = data.get("family_id")
        user_name = data.get("user_name")
        achievement_key = data.get("achievement_key")
        period = data.get("period")
        earned_date = data.get("earned_date")

        if not family_id or not user_name or not achievement_key or not period or not earned_date:
            return jsonify({"status": "error", "message": "missing fields"}), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            INSERT INTO achievements (user_name, family_id, achievement_key, period, earned_date)
            VALUES (%s, %s, %s, %s, %s)
        """, (user_name, family_id, achievement_key, period, earned_date))

        cur.execute("""
            SELECT COUNT(*)
            FROM achievements
            WHERE user_name = %s
              AND achievement_key = %s
        """, (user_name, achievement_key))

        count = cur.fetchone()[0]

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok", "count": count})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# ---------------------------------
# Auth (регистрация по почте)
# ---------------------------------
SESSION_TTL_DAYS = 90
VERIFICATION_TTL_MINUTES = 15


def _create_session(cur, user_id):
    """Создаёт сессию на SESSION_TTL_DAYS и возвращает токен."""
    token = secrets.token_hex(32)
    cur.execute("""
        INSERT INTO sessions (user_id, token, expires_at)
        VALUES (%s, %s, NOW() + INTERVAL '90 days')
    """, (user_id, token))
    return token


def get_auth_user():
    """Возвращает user_id по заголовку Authorization, либо None.

    Опциональная проверка: клиенты без токена работают по-старому.
    """
    header = request.headers.get("Authorization", "")
    if not header.startswith("Bearer "):
        return None

    token = header[len("Bearer "):].strip()
    if not token:
        return None

    try:
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT user_id FROM sessions
            WHERE token = %s AND expires_at > NOW()
        """, (token,))
        row = cur.fetchone()
        cur.close()
        conn.close()
        return row[0] if row else None
    except Exception:
        return None


@app.route("/auth/register", methods=["POST"])
def auth_register():
    try:
        data = request.get_json() or {}
        email = (data.get("email") or "").strip().lower()
        password = data.get("password") or ""

        if "@" not in email or len(email) < 5:
            return jsonify({"status": "error", "message": "invalid email"}), 400
        if len(password) < 6:
            return jsonify({"status": "error", "message": "password too short"}), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute(
            "SELECT id, email_verified FROM users WHERE email = %s",
            (email,),
        )
        row = cur.fetchone()

        if row and row[1]:
            cur.close()
            conn.close()
            return jsonify({
                "status": "error",
                "message": "email already registered",
            }), 409

        code = f"{secrets.randbelow(1000000):06d}"
        password_hash = bcrypt.hashpw(
            password.encode(), bcrypt.gensalt()
        ).decode()

        if row:
            # Email есть, но не подтверждён — обновляем пароль и код.
            cur.execute("""
                UPDATE users
                SET password_hash = %s,
                    verification_code = %s,
                    verification_expires_at = NOW() + INTERVAL '15 minutes'
                WHERE id = %s
            """, (password_hash, code, row[0]))
        else:
            cur.execute("""
                INSERT INTO users (
                    email, password_hash, verification_code,
                    verification_expires_at
                )
                VALUES (%s, %s, %s, NOW() + INTERVAL '15 minutes')
            """, (email, password_hash, code))

        conn.commit()
        cur.close()
        conn.close()

        sent = send_email(
            email,
            "Код подтверждения Good Family",
            f"Ваш код подтверждения: {code}\n\n"
            f"Он действует {VERIFICATION_TTL_MINUTES} минут.\n\n"
            f"Если вы не регистрировались в Good Family, "
            f"просто проигнорируйте это письмо.",
        )

        if not sent:
            return jsonify({
                "status": "error",
                "message": "email send failed",
            }), 500

        return jsonify({"status": "ok", "message": "code sent"})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/auth/resend", methods=["POST"])
def auth_resend():
    """Повторная отправка кода подтверждения (без смены пароля)."""
    try:
        data = request.get_json() or {}
        email = (data.get("email") or "").strip().lower()

        if not email:
            return jsonify({"status": "error", "message": "missing params"}), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute(
            "SELECT id, email_verified FROM users WHERE email = %s",
            (email,),
        )
        row = cur.fetchone()

        if not row:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "user not found"}), 404

        if row[1]:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "already verified"}), 409

        code = f"{secrets.randbelow(1000000):06d}"

        cur.execute("""
            UPDATE users
            SET verification_code = %s,
                verification_expires_at = NOW() + INTERVAL '15 minutes'
            WHERE id = %s
        """, (code, row[0]))

        conn.commit()
        cur.close()
        conn.close()

        sent = send_email(
            email,
            "Код подтверждения Good Family",
            f"Ваш код подтверждения: {code}\n\n"
            f"Он действует {VERIFICATION_TTL_MINUTES} минут.",
        )

        if not sent:
            return jsonify({
                "status": "error",
                "message": "email send failed",
            }), 500

        return jsonify({"status": "ok", "message": "code sent"})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/auth/verify", methods=["POST"])
def auth_verify():
    try:
        data = request.get_json() or {}
        email = (data.get("email") or "").strip().lower()
        code = (data.get("code") or "").strip()

        if not email or not code:
            return jsonify({"status": "error", "message": "missing params"}), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT id, verification_code, verification_expires_at,
                   email_verified
            FROM users
            WHERE email = %s
        """, (email,))
        row = cur.fetchone()

        if not row:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "user not found"}), 404

        user_id, db_code, expires_at, verified = row

        if verified:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "already verified"}), 409

        if not db_code or code != db_code:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "invalid code"}), 400

        if expires_at is None or expires_at < datetime.now():
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "code expired"}), 400

        cur.execute("""
            UPDATE users
            SET email_verified = TRUE,
                verification_code = NULL,
                verification_expires_at = NULL
            WHERE id = %s
        """, (user_id,))

        token = _create_session(cur, user_id)

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok", "session_token": token})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/auth/login", methods=["POST"])
def auth_login():
    try:
        data = request.get_json() or {}
        email = (data.get("email") or "").strip().lower()
        password = data.get("password") or ""

        if not email or not password:
            return jsonify({"status": "error", "message": "missing params"}), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT id, password_hash, email_verified
            FROM users
            WHERE email = %s
        """, (email,))
        row = cur.fetchone()

        if not row:
            cur.close()
            conn.close()
            return jsonify({
                "status": "error",
                "message": "invalid credentials",
            }), 401

        user_id, password_hash, verified = row

        if not bcrypt.checkpw(password.encode(), password_hash.encode()):
            cur.close()
            conn.close()
            return jsonify({
                "status": "error",
                "message": "invalid credentials",
            }), 401

        if not verified:
            cur.close()
            conn.close()
            return jsonify({
                "status": "error",
                "message": "email not verified",
            }), 403

        token = _create_session(cur, user_id)

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok", "session_token": token})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/auth/logout", methods=["POST"])
def auth_logout():
    try:
        data = request.get_json() or {}
        token = (data.get("session_token") or "").strip()

        if not token:
            header = request.headers.get("Authorization", "")
            if header.startswith("Bearer "):
                token = header[len("Bearer "):].strip()

        if not token:
            return jsonify({"status": "error", "message": "missing token"}), 400

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("DELETE FROM sessions WHERE token = %s", (token,))
        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok"})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/achievements", methods=["GET"])
def achievements():
    try:
        family_id = request.args.get("family_id")
        period = request.args.get("period")
        min_date = request.args.get("min_date")

        if not family_id:
            return jsonify({"status": "error", "message": "family_id required"}), 400

        conn = get_connection()
        cur = conn.cursor()

        query = """
            SELECT achievement_key, user_name,family_id, COUNT(*) AS count, MAX(earned_date) AS last_earned
            FROM achievements
            WHERE family_id = %s
        """
        params = [family_id]

        if period:
            query += " AND period = %s"
            params.append(period)

        if min_date:
            query += " AND earned_date >= %s"
            params.append(min_date)

        query += " GROUP BY achievement_key, user_name, family_id ORDER BY achievement_key, user_name"

        cur.execute(query, tuple(params))
        rows = cur.fetchall()

        result = []
        for row in rows:
            result.append({
                "achievement_key": row[0],
                "user_name": row[1],
                "family_id": row[2],
                "count": row[3],
                "last_earned": row[4].isoformat() if row[4] else None,
            })

        cur.close()
        conn.close()

        return jsonify({"status": "ok", "achievements": result})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    

 
    
@app.route("/garden")
def get_garden():
    try:
        family_id = request.args.get("family_id")
        if not family_id:
            return jsonify({"status": "error", "message": "family_id required"}), 400

        conn = get_connection()
        cur = conn.cursor()

        # Уровень сада + прогресс от заданий
        cur.execute("""
            SELECT level, COALESCE(achievement_progress, 0), updated_at
            FROM garden
            WHERE family_id = %s
        """, (family_id,))
        row = cur.fetchone()
        if row:
            garden_level = row[0]
            achievement_progress = round(row[1], 2)
            last_levelup = str(row[2]) if row[2] else None
        else:
            garden_level = 1
            achievement_progress = 0.0
            last_levelup = None

        cur.execute("""
            SELECT COUNT(DISTINCT achievement_key)
            FROM achievements
            WHERE family_id = %s AND period = 'personal'
        """, (family_id,))
        personal_count = cur.fetchone()[0]

        cur.execute("""
            SELECT COUNT(DISTINCT achievement_key)
            FROM achievements
            WHERE family_id = %s AND period = 'group'
        """, (family_id,))
        group_count = cur.fetchone()[0]

        achievements_count = personal_count + group_count

        # Можно ли расти (понедельник + достаточно достижений)
        import datetime
        is_monday = datetime.datetime.now().weekday() == 0
        can_grow = is_monday and achievements_count >= garden_level + 1

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "level": garden_level,
            "achievements_count": achievements_count,
            "achievement_progress": achievement_progress,
            "unique_achievements": achievements_count,  
            "task_progress": achievement_progress,       
            "can_grow": can_grow,
            "last_levelup": last_levelup,
        })

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    

@app.route(
    "/garden/levelup",
    methods=["POST"]
)
def garden_levelup():

    try:

        data = request.get_json()

        family_id = data.get(
            "family_id"
        )

        new_level = int(
            data.get(
                "new_level",
                1
            )
        )

        if not family_id:

            return jsonify({
                "status": "error",
                "message": "family_id required"
            }), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT level
            FROM garden
            WHERE family_id = %s
        """, (
            family_id,
        ))

        row = cur.fetchone()

        if not row:

            cur.execute("""
                INSERT INTO garden (
                    family_id,
                    level
                )
                VALUES (%s, %s)
            """, (
                family_id,
                max(
                    1,
                    new_level
                )
            ))

            final_level = max(
                1,
                new_level
            )

        else:

            current_level = row[0]

            final_level = current_level

            if new_level > current_level:

                cur.execute("""
                    UPDATE garden
                    SET
                        level = %s,
                        updated_at = NOW()
                    WHERE family_id = %s
                """, (
                    new_level,
                    family_id
                ))

                final_level = new_level

        conn.commit()

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "level": final_level
        })

    except Exception as e:

        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500
    
@app.route("/weekly_events")
def weekly_events():
    try:
        family_id = request.args.get("family_id")
        if not family_id:
            return jsonify({"status": "error", "message": "family_id required"}), 400

        conn = get_connection()
        cur = conn.cursor()

        # Последние достижения
        cur.execute("""
            SELECT achievement_key, earned_date
            FROM achievements
            WHERE family_id = %s
            ORDER BY earned_date DESC
            LIMIT 20
        """, (family_id,))
        achievement_rows = cur.fetchall()

        achievements = [{"achievement_key": row[0], "earned_date": str(row[1])} for row in achievement_rows]

        # Уровень сада + дата последнего обновления
        cur.execute("""
            SELECT level, updated_at
            FROM garden
            WHERE family_id = %s
        """, (family_id,))
        garden_row = cur.fetchone()

        garden_level = garden_row[0] if garden_row else 1
        last_levelup = str(garden_row[1]) if garden_row and garden_row[1] else None

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "achievements": achievements,
            "garden_level": garden_level,
            "last_levelup": last_levelup,
        })

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    

@app.route("/family_daily_stats")
def family_daily_stats():

    try:

        family_id = request.args.get("family_id")
        date = request.args.get("date")

        if not family_id or not date:

            return jsonify({
                "status": "error",
                "message": "family_id and date required"
            }), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT
                AVG(st.total_seconds)::INTEGER AS average_seconds,
                AVG(st.social_seconds)::INTEGER AS average_social_seconds,
                COUNT(*) AS members_count
            FROM members m
            JOIN screen_time st ON m.user_name = st.user_id
            WHERE m.family_id = %s AND st.date = %s
        """, (family_id, date))

        row = cur.fetchone()

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "average_seconds": row[0] or 0,
            "average_social_seconds": row[1] or 0,
            "members_count": row[2] or 0
        })

    except Exception as e:

        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500    
    


@app.route("/personal_achievements")
def personal_achievements():

    family_id = request.args.get("family_id")

    if not family_id:
        return jsonify({
            "status": "error",
            "message": "family_id required"
        }), 400

    conn = get_connection()
    cur = conn.cursor()

    cur.execute("""
        SELECT user_name
        FROM members
        WHERE family_id = %s
    """, (family_id,))

    members = [row[0] for row in cur.fetchall()]

    now = datetime.now()

    current_monday = now - timedelta(days=now.weekday())

    last_week_monday = current_monday - timedelta(days=7)
    last_week_sunday = current_monday - timedelta(days=1)

    first_day_current_month = datetime(now.year, now.month, 1)
    last_day_previous_month = first_day_current_month - timedelta(days=1)
    first_day_previous_month = datetime(
        last_day_previous_month.year,
        last_day_previous_month.month,
        1,
    )

    result = {
        "status": "ok",
        "week": {},
        "month": {},
    }

    week_keys = [
        "3", "5", "7",
        "3p", "5p", "7p",
        "3s", "5s", "7s"
    ]

    month_keys = [
        "10", "20", "25", "-1",
        "10p", "20p", "25p", "-1p",
        "10s", "20s", "25s", "-1s"
    ]

    for key in week_keys:
        result["week"][key] = []

    for key in month_keys:
        result["month"][key] = []

    for user_name in members:

        # ---------- WEEK ----------

        cur.execute("""
            SELECT
                date,
                total_seconds,
                social_seconds
            FROM screen_time
            WHERE user_id = %s
              AND date >= %s
              AND date <= %s
        """, (
            user_name,
            last_week_monday.date(),
            last_week_sunday.date()
        ))

        rows = cur.fetchall()

        good = 0
        super_good = 0
        social_good = 0

        for _, total_seconds, social_seconds in rows:

            total_seconds = total_seconds or 0
            social_seconds = social_seconds or 0

            if total_seconds < 10800:
                good += 1

            if total_seconds < 1800:
                super_good += 1

            if social_seconds < 2700:
                social_good += 1

        if good >= 3:
            result["week"]["3"].append(user_name)

        if good >= 5:
            result["week"]["5"].append(user_name)

        if good >= 7:
            result["week"]["7"].append(user_name)

        if super_good >= 3:
            result["week"]["3p"].append(user_name)

        if super_good >= 5:
            result["week"]["5p"].append(user_name)

        if super_good >= 7:
            result["week"]["7p"].append(user_name)

        if social_good >= 3:
            result["week"]["3s"].append(user_name)

        if social_good >= 5:
            result["week"]["5s"].append(user_name)

        if social_good >= 7:
            result["week"]["7s"].append(user_name)

        # ---------- MONTH ----------

        cur.execute("""
            SELECT
                date,
                total_seconds,
                social_seconds
            FROM screen_time
            WHERE user_id = %s
              AND date >= %s
              AND date <= %s
        """, (
            user_name,
            first_day_previous_month.date(),
            last_day_previous_month.date()
        ))

        rows = cur.fetchall()

        good = 0
        super_good = 0
        social_good = 0

        for _, total_seconds, social_seconds in rows:

            total_seconds = total_seconds or 0
            social_seconds = social_seconds or 0

            if total_seconds < 10800:
                good += 1

            if total_seconds < 1800:
                super_good += 1

            if social_seconds < 2700:
                social_good += 1

        total_days = last_day_previous_month.day

        if good >= 10:
            result["month"]["10"].append(user_name)

        if good >= 20:
            result["month"]["20"].append(user_name)

        if good >= 25:
            result["month"]["25"].append(user_name)

        if good >= total_days:
            result["month"]["-1"].append(user_name)

        if super_good >= 10:
            result["month"]["10p"].append(user_name)

        if super_good >= 20:
            result["month"]["20p"].append(user_name)

        if super_good >= 25:
            result["month"]["25p"].append(user_name)

        if super_good >= total_days:
            result["month"]["-1p"].append(user_name)

        if social_good >= 10:
            result["month"]["10s"].append(user_name)

        if social_good >= 20:
            result["month"]["20s"].append(user_name)

        if social_good >= 25:
            result["month"]["25s"].append(user_name)

        if social_good >= total_days:
            result["month"]["-1s"].append(user_name)

    #
    today = datetime.now().date()
    for key in week_keys + month_keys:
        for user_name in result["week"].get(key, []) + result["month"].get(key, []):
            cur.execute("""
                INSERT INTO achievements (user_name, family_id, achievement_key, period, earned_date)
                VALUES (%s, %s, %s, %s, %s)
                ON CONFLICT (user_name, achievement_key, period) DO NOTHING
            """, (user_name, family_id, key, "personal", today))

    conn.commit()

    cur.close()
    conn.close()

    return jsonify(result)   



# Ключ -> (period_type, metric, threshold_seconds, target)
ACHIEVEMENT_METRICS = {
    "3": ("weekly", "screen", 7200, 3),
    "5": ("weekly", "screen", 7200, 5),
    "7": ("weekly", "screen", 7200, 7),
    "3p": ("weekly", "screen", 1200, 3),
    "5p": ("weekly", "screen", 1200, 5),
    "7p": ("weekly", "screen", 1200, 7),
    "3s": ("weekly", "social", 1800, 3),
    "5s": ("weekly", "social", 1800, 5),
    "7s": ("weekly", "social", 1800, 7),
    "10": ("monthly", "screen", 7200, 10),
    "20": ("monthly", "screen", 7200, 20),
    "25": ("monthly", "screen", 7200, 25),
    "-1": ("monthly", "screen", 7200, 30),
    "10p": ("monthly", "screen", 1200, 10),
    "20p": ("monthly", "screen", 1200, 20),
    "25p": ("monthly", "screen", 1200, 25),
    "-1p": ("monthly", "screen", 1200, 30),
    "10s": ("monthly", "social", 1800, 10),
    "20s": ("monthly", "social", 1800, 20),
    "25s": ("monthly", "social", 1800, 25),
    "-1s": ("monthly", "social", 1800, 30),
}

ACHIEVEMENT_TITLES = {
    "3": "3 дня минимум телефона",
    "5": "5 дней минимум телефона",
    "7": "7 дней минимум телефона",
    "10": "10 дней минимум телефона",
    "20": "20 дней минимум телефона",
    "25": "25 дней минимум телефона",
    "-1": "Весь месяц минимум телефона",
    "3p": "3 дня без телефона",
    "5p": "5 дней без телефона",
    "7p": "7 дней без телефона",
    "10p": "10 дней без телефона",
    "20p": "20 дней без телефона",
    "25p": "25 дней без телефона",
    "-1p": "Весь месяц без телефона",
    "3s": "3 дня минимум соцсетей",
    "5s": "5 дней минимум соцсетей",
    "7s": "7 дней минимум соцсетей",
    "10s": "10 дней минимум соцсетей",
    "20s": "20 дней минимум соцсетей",
    "25s": "25 дней минимум соцсетей",
    "-1s": "Весь месяц минимум соцсетей",
}


def get_achievement_config(key):
    """Возвращает (period_type, metric, threshold_seconds, target)"""
    return ACHIEVEMENT_METRICS.get(key)


def get_periods(period_type):
    import datetime
    today = datetime.date.today()
    
    if period_type == "weekly":
        # Текущая неделя: с понедельника по вчера
        current_monday = today - datetime.timedelta(days=today.weekday())
        current_start = current_monday
        current_end = today - datetime.timedelta(days=1)
        
        # Прошлая неделя: пн-вс
        prev_monday = current_monday - datetime.timedelta(days=7)
        prev_sunday = current_monday - datetime.timedelta(days=1)
        return (current_start, current_end, prev_monday, prev_sunday)
    else:
        # Текущий месяц
        current_start = today.replace(day=1)
        current_end = today - datetime.timedelta(days=1)
        
        # Прошлый месяц
        first_of_current = today.replace(day=1)
        prev_end = first_of_current - datetime.timedelta(days=1)
        prev_start = prev_end.replace(day=1)
        return (current_start, current_end, prev_start, prev_end)



@app.route("/achievement_progress")
def achievement_progress():
    try:
        family_id = request.args.get("family_id")
        key = request.args.get("achievement_key")
        user_name = request.args.get("user_name")  # для личных достижений
        
        if not family_id or not key:
            return jsonify({"status": "error", "message": "missing params"}), 400
        
        config = get_achievement_config(key)
        if not config:
            return jsonify({"status": "error", "message": "unknown key"}), 400
        
        period_type, metric, threshold, target = config
        period_type_full = "weekly" if period_type == "weekly" else "monthly"
        
        # Личное или групповое?
        # Личные ключи: 3,5,7,3p,5p,7p,3s,5s,7s,10,20,25,-1,10p,20p,25p,-1p,10s,20s,25s,-1s
        # Групповые — те же ключи, но с period='group' в БД.
        # По ключу не определить. Определяем по user_name: если передан — личное, нет — групповое.
        is_personal = user_name is not None and user_name != ""
        
        cur_start, cur_end, prev_start, prev_end = get_periods(period_type_full)
        
        conn = get_connection()
        cur = conn.cursor()
        
        def get_member_stats(name, start_date, end_date):
            """Возвращает (good_days, avg_seconds, days_count) для одного пользователя"""
            if metric == "screen":
                cur.execute("""
                    SELECT date, total_seconds FROM screen_time
                    WHERE user_id = %s AND date >= %s AND date <= %s
                """, (name, start_date, end_date))
            else:
                cur.execute("""
                    SELECT date, COALESCE(social_seconds, 0) FROM screen_time
                    WHERE user_id = %s AND date >= %s AND date <= %s
                """, (name, start_date, end_date))
            
            days = cur.fetchall()
            good_days = sum(1 for _, sec in days if sec < threshold)
            avg_seconds = int(sum(sec for _, sec in days) / len(days)) if days else 0
            return good_days, avg_seconds, len(days)
        
        def get_group_stats(start_date, end_date):
            """Возвращает среднее по семье за каждый день + разбивку по членам"""
            if start_date > end_date:
                return 0, 0, 0, []
            
            if metric == "screen":
                cur.execute("""
                    SELECT date, AVG(total_seconds)::int
                    FROM screen_time
                    WHERE user_id IN (
                        SELECT user_name FROM members WHERE family_id = %s
                    )
                    AND date >= %s AND date <= %s
                    GROUP BY date
                    ORDER BY date
                """, (family_id, start_date, end_date))
            else:
                cur.execute("""
                    SELECT date, AVG(COALESCE(social_seconds, 0))::int
                    FROM screen_time
                    WHERE user_id IN (
                        SELECT user_name FROM members WHERE family_id = %s
                    )
                    AND date >= %s AND date <= %s
                    GROUP BY date
                    ORDER BY date
                """, (family_id, start_date, end_date))
            
            daily = cur.fetchall()
            good_days = sum(1 for _, avg in daily if avg < threshold)
            avg_all = int(sum(avg for _, avg in daily) / len(daily)) if daily else 0
            
            # Разбивка по членам
            cur.execute("SELECT user_name FROM members WHERE family_id = %s", (family_id,))
            member_names = [r[0] for r in cur.fetchall()]
            members_list = []
            for name in member_names:
                gd, avg, total = get_member_stats(name, start_date, end_date)
                members_list.append({
                    "name": name,
                    "days": gd,
                    "avg_seconds": avg,
                    "days_total": total,
                })
            
            return good_days, avg_all, len(daily), members_list
        
        # Считаем текущий период
        if is_personal:
            cur_days, cur_avg, cur_total = get_member_stats(user_name, cur_start, cur_end) if cur_start <= cur_end else (0, 0, 0)
            current = {
                "days_count": cur_days,
                "days_total": cur_total,
                "avg_seconds": cur_avg,
                "members": [{"name": user_name, "days": cur_days, "avg_seconds": cur_avg, "days_total": cur_total}],
            }
            prev_days, prev_avg, prev_total = get_member_stats(user_name, prev_start, prev_end)
            previous = {
                "days_count": prev_days,
                "days_total": prev_total,
                "avg_seconds": prev_avg,
                "members": [{"name": user_name, "days": prev_days, "avg_seconds": prev_avg, "days_total": prev_total}],
            }
        else:
            cur_days, cur_avg, cur_total, cur_members = get_group_stats(cur_start, cur_end) if cur_start <= cur_end else (0, 0, 0, [])
            current = {
                "days_count": cur_days,
                "days_total": cur_total,
                "avg_seconds": cur_avg,
                "members": cur_members,
            }
            prev_days, prev_avg, prev_total, prev_members = get_group_stats(prev_start, prev_end)
            previous = {
                "days_count": prev_days,
                "days_total": prev_total,
                "avg_seconds": prev_avg,
                "members": prev_members,
            }
        
        cur.close()
        conn.close()
        
        return jsonify({
            "status": "ok",
            "achievement_key": key,
            "type": "personal" if is_personal else "group",
            "period_type": period_type_full,
            "target": target,
            "threshold_seconds": threshold,
            "current": current,
            "previous": previous,
        })
    
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/achievement_progress_all")
def achievement_progress_all():
    """Прогресс по всем личным достижениям за один запрос (1 SQL-запрос)."""
    try:
        family_id = request.args.get("family_id")
        user_name = request.args.get("user_name")

        if not family_id or not user_name:
            return jsonify({"status": "error", "message": "missing params"}), 400

        today = datetime.now().date()
        month_start = today.replace(day=1)
        week_start = today - timedelta(days=today.weekday())
        # Самый ранний из нужных периодов: неделя может начаться в прошлом месяце
        start = min(month_start, week_start)
        end = today - timedelta(days=1)  # как в get_periods: сегодня не учитываем

        conn = get_connection()
        cur = conn.cursor()

        rows = []
        if start <= end:
            cur.execute("""
                SELECT date, total_seconds, COALESCE(social_seconds, 0)
                FROM screen_time
                WHERE user_id = %s AND date >= %s AND date <= %s
            """, (user_name, start, end))
            rows = cur.fetchall()

        cur.close()
        conn.close()

        achievements = []
        for key, (period_type, metric, threshold, target) in ACHIEVEMENT_METRICS.items():
            p_start = week_start if period_type == "weekly" else month_start

            good_days = 0
            if p_start <= end:
                for day, total, social in rows:
                    if day < p_start or day > end:
                        continue
                    seconds = total if metric == "screen" else social
                    if seconds < threshold:
                        good_days += 1

            achievements.append({
                "key": key,
                "current": good_days,
                "target": target,
                "title": ACHIEVEMENT_TITLES.get(key, key),
            })

        return jsonify({"status": "ok", "achievements": achievements})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500



@app.route("/tasks/create", methods=["POST"])
def create_task():
    try:
        data = request.get_json()
        family_id = data.get("family_id")
        title = data.get("title")
        stars = data.get("stars", 10)
        created_by = data.get("created_by")
        assigned_to = data.get("assigned_to")
        repeat_mode = data.get("repeat_mode", "none")

        if not family_id or not title or not created_by or not assigned_to:
            return jsonify({"status": "error", "message": "missing parameters"}), 400

        conn = get_connection()
        cur = conn.cursor()

     # Удаляем старую невыполненную задачу с тем же названием
        cur.execute("""
            DELETE FROM tasks
            WHERE family_id = %s
            AND title = %s
            AND assigned_to = %s
            AND status = 'pending'
        """, (family_id, title, assigned_to))  
        
        cur.execute("""
            INSERT INTO tasks (family_id, title, stars, created_by, assigned_to, repeat_mode, next_available_at)
            VALUES (%s, %s, %s, %s, %s, %s, NOW())
            RETURNING id
        """, (family_id, title, stars, created_by, assigned_to, repeat_mode))

        task_id = cur.fetchone()[0]

        cur.execute("""
            INSERT INTO task_log (task_id, user_name, action)
            VALUES (%s, %s, %s)
        """, (task_id, created_by, "created"))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok", "task_id": task_id})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

    

@app.route("/tasks/done", methods=["POST"])
def task_done():
    try:
        data = request.get_json()
        task_id = data.get("task_id")
        user_name = data.get("user_name")

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT family_id, title, stars, created_by, assigned_to, repeat_mode
            FROM tasks WHERE id = %s
        """, (task_id,))
        task = cur.fetchone()

        if not task:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "task not found"}), 404

        family_id, title, stars, created_by, assigned_to, repeat_mode = task

        cur.execute("""
            UPDATE tasks SET status = 'done', done_at = NOW()
            WHERE id = %s
        """, (task_id,))

        cur.execute("""
            INSERT INTO task_log (task_id, user_name, action)
            VALUES (%s, %s, %s)
        """, (task_id, user_name, "done"))

        if repeat_mode and repeat_mode != "none":
            if repeat_mode == "daily":
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day'"
            elif repeat_mode == "weekly":
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day' + (8 - EXTRACT(DOW FROM NOW())) * INTERVAL '1 day'"
            elif repeat_mode == "weekdays":
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day'"
            elif repeat_mode == "weekends":
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day'"
            else:
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day'"

              # Удаляем старую невыполненную задачу с тем же названием
            cur.execute("""
                DELETE FROM tasks
                WHERE family_id = %s
                  AND title = %s
                  AND assigned_to = %s
                  AND status = 'pending'
                  AND id != %s
            """, (family_id, title, assigned_to, task_id))

            cur.execute(f"""
                INSERT INTO tasks (family_id, title, stars, created_by, assigned_to, repeat_mode, next_available_at, status)
                VALUES (%s, %s, %s, %s, %s, %s, {next_available}, 'pending')
            """, (family_id, title, stars, created_by, assigned_to, repeat_mode))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    


@app.route("/tasks/delete", methods=["POST"])
def delete_task():
    try:

        data = request.get_json()

        task_id = data.get("task_id")
        user_name = data.get("user_name")

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT status
            FROM tasks
            WHERE id=%s
        """, (
            task_id,
        ))

        row = cur.fetchone()

        if not row:

            cur.close()
            conn.close()

            return jsonify({
                "status": "error",
                "message": "task_not_found"
            }), 404

        if row[0] == "approved":

            cur.close()
            conn.close()

            return jsonify({
                "status": "error",
                "message": "approved_task_cannot_be_deleted"
            }), 400

        cur.execute("""
            INSERT INTO task_log(
                task_id,
                user_name,
                action
            )
            VALUES(%s,%s,%s)
        """, (
            task_id,
            user_name,
            "deleted",
        ))

        cur.execute("""
            DELETE FROM tasks
            WHERE id=%s
        """, (
            task_id,
        ))

        conn.commit()

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok"
        })

    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500

    

@app.route("/tasks/retry", methods=["POST"])
def task_retry():
    try:

        data = request.get_json()

        task_id = data.get("task_id")
        user_name = data.get("user_name")

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            UPDATE tasks
            SET
                status='pending',
                done_at=NULL
            WHERE id=%s
        """, (
            task_id,
        ))

        cur.execute("""
            INSERT INTO task_log(
                task_id,
                user_name,
                action
            )
            VALUES(%s,%s,%s)
        """, (
            task_id,
            user_name,
            "retry",
        ))

        conn.commit()

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok"
        })

    except Exception as e:
        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500    

@app.route("/tasks/approve", methods=["POST"])
def task_approve():
    try:
        data = request.get_json()
        task_id = data.get("task_id")
        user_name = data.get("user_name")

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT family_id, title, stars, created_by, assigned_to, repeat_mode
            FROM tasks WHERE id = %s
        """, (task_id,))

        task = cur.fetchone()
        if not task:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "task not found"}), 404

        family_id, title, stars, created_by, assigned_to, repeat_mode = task

        cur.execute("""
            UPDATE tasks SET status = 'approved', approved_at = NOW()
            WHERE id = %s
        """, (task_id,))



        cur.execute("""
            INSERT INTO task_log (task_id, user_name, action) VALUES (%s, %s, %s)
        """, (task_id, user_name, "approved"))

        if repeat_mode and repeat_mode != "none":
            if repeat_mode == "daily":
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day'"
            elif repeat_mode == "weekly":
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day' + (8 - EXTRACT(DOW FROM NOW())) * INTERVAL '1 day'"
            elif repeat_mode == "weekdays":
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day'"
            elif repeat_mode == "weekends":
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day'"
            else:
                next_available = "DATE_TRUNC('day', NOW()) + INTERVAL '1 day'"


                  # Удаляем старую невыполненную задачу с тем же названием
            cur.execute("""
                DELETE FROM tasks
                WHERE family_id = %s
                  AND title = %s
                  AND assigned_to = %s
                  AND status = 'pending'
                  AND id != %s
            """, (family_id, title, assigned_to, task_id))

            cur.execute(f"""
                INSERT INTO tasks (family_id, title, stars, created_by, assigned_to, repeat_mode, next_available_at, status)
                VALUES (%s, %s, %s, %s, %s, %s, {next_available}, 'pending')
            """, (family_id, title, stars, created_by, assigned_to, repeat_mode))

            cur.execute("""
                UPDATE garden
                SET achievement_progress = COALESCE(achievement_progress, 0) + 0.01
                WHERE family_id = %s
            """, (family_id,))

        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "ok"})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500



@app.route("/tasks/reject", methods=["POST"])
def task_reject():
    try:

        data = request.get_json()

        task_id = data.get("task_id")
        user_name = data.get("user_name")

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            UPDATE tasks
            SET status = 'rejected'
            WHERE id = %s
        """, (
            task_id,
        ))

        cur.execute("""
            INSERT INTO task_log (
                task_id,
                user_name,
                action
            )
            VALUES (%s,%s,%s)
        """, (
            task_id,
            user_name,
            "rejected",
        ))

        conn.commit()

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok"
        })
    
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/tasks", methods=["GET"])
def get_tasks():
    try:
        family_id = request.args.get("family_id")
        user_name = request.args.get("user_name")

        conn = get_connection()
        cur = conn.cursor()

        query = """
            SELECT t.id, t.family_id, t.title, t.stars, t.created_by, t.assigned_to, t.status,
                   t.created_at, t.done_at, t.approved_at, t.repeat_mode, t.next_available_at
            FROM tasks t
            WHERE t.family_id = %s
              AND t.next_available_at <= NOW()
        """
        params = [family_id]

        if user_name:
            query += " AND (t.assigned_to = %s OR t.created_by = %s)"
            params.extend([user_name, user_name])

        query += " ORDER BY t.created_at DESC"

        cur.execute(query, params)
        rows = cur.fetchall()
        tasks = []
        for row in rows:
            tasks.append({
                "id": row[0],
                "family_id": row[1],
                "title": row[2],
                "stars": row[3] or 10,
                "created_by": row[4],
                "assigned_to": row[5],
                "status": row[6],
                "created_at": row[7].isoformat() if row[7] else None,
                "done_at": row[8].isoformat() if row[8] else None,
                "approved_at": row[9].isoformat() if row[9] else None,
                "repeat_mode": row[10],
                "next_available_at": row[11].isoformat() if row[11] else None,
            })

        cur.close()
        conn.close()
        return jsonify({"status": "ok", "tasks": tasks})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


# ──────────────────────────────────────
# REWARD SHOP
# ──────────────────────────────────────

@app.route("/reward_shop", methods=["GET"])
def get_reward_shop():
    try:
        family_id = request.args.get("family_id")
        if not family_id:
            return jsonify({"status": "error", "message": "family_id required"}), 400

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            SELECT id, title, emoji, cost_stars, active, COALESCE(color_hex, '#FFF4E5'), COALESCE(description, '')
            FROM reward_shop
            WHERE family_id = %s AND active = TRUE
            ORDER BY id
        """, (family_id,))
        rows = cur.fetchall()
        items = []
        for row in rows:
            items.append({
                "id": row[0],
                "title": row[1],
                "emoji": row[2] or "🎁",
                "cost_stars": row[3],
                "active": row[4],
                "color_hex": row[5],
                "description": row[6],
            })
        cur.close()
        conn.close()
        return jsonify({"status": "ok", "items": items})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/reward_shop/create", methods=["POST"])
def create_reward_shop():
    try:
        data = request.get_json()
        family_id = data.get("family_id")
        title = data.get("title")
        emoji = data.get("emoji", "🎁")
        cost_stars = data.get("cost_stars", 100)
        color_hex = data.get("color_hex", "#FFF4E5")
        description = data.get("description", "")

        

        if not family_id or not title:
            return jsonify({"status": "error", "message": "missing fields"}), 400

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            INSERT INTO reward_shop (family_id, title, emoji, cost_stars, color_hex, description)
            VALUES (%s, %s, %s, %s, %s, %s)
            RETURNING id
        """, (family_id, title, emoji, cost_stars, color_hex, description))
        reward_id = cur.fetchone()[0]
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "ok", "id": reward_id})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/reward_shop/update", methods=["POST"])
def update_reward_shop():
    try:
        data = request.get_json()
        reward_id = data.get("id")
        title = data.get("title")
        emoji = data.get("emoji", "🎁")
        cost_stars = data.get("cost_stars", 100)
        color_hex = data.get("color_hex", "#FFF4E5")
        description = data.get("description", "")

        if not reward_id:
            return jsonify({"status": "error", "message": "id required"}), 400

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            UPDATE reward_shop SET title = %s, emoji = %s, cost_stars = %s, color_hex = %s,  description = %s
            WHERE id = %s
        """, (title, emoji, cost_stars, color_hex, description, reward_id))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/reward_shop/delete", methods=["POST"])
def delete_reward_shop():
    try:
        data = request.get_json()
        reward_id = data.get("reward_id")
        if not reward_id:
            return jsonify({"status": "error", "message": "reward_id required"}), 400

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("UPDATE reward_shop SET active = FALSE WHERE id = %s", (reward_id,))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/child_balance", methods=["GET"])
def child_balance():
    try:
        family_id = request.args.get("family_id")
        user_name = request.args.get("user_name")

        conn = get_connection()
        cur = conn.cursor()

        # ⭐ Звёзды: заработано - потрачено
        cur.execute("""
            SELECT COALESCE(SUM(stars), 0)
            FROM tasks
            WHERE family_id = %s AND assigned_to = %s AND status = 'approved'
        """, (family_id, user_name))
        earned = cur.fetchone()[0]

        cur.execute("""
            SELECT COALESCE(SUM(cost_stars), 0)
            FROM reward_requests
            WHERE family_id = %s AND child_name = %s AND status IN ('pending', 'approved', 'completed')
        """, (family_id, user_name))
        spent = cur.fetchone()[0]

        total_stars = earned - spent

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "stars": total_stars
        })

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    


@app.route("/reward_shop/buy", methods=["POST"])
def buy_reward():
    try:
        data = request.get_json()
        family_id = data.get("family_id")
        reward_id = data.get("reward_id")
        child_name = data.get("child_name")

        conn = get_connection()
        cur = conn.cursor()

        # Стоимость награды
        cur.execute("SELECT cost_stars FROM reward_shop WHERE id = %s", (reward_id,))
        reward = cur.fetchone()
        if not reward:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "reward not found"})

        cost = reward[0]

        # Заработано звёзд
        cur.execute("""
            SELECT COALESCE(SUM(stars), 0)
            FROM tasks
            WHERE family_id = %s AND assigned_to = %s AND status = 'approved'
        """, (family_id, child_name))
        earned = cur.fetchone()[0]

        # Потрачено звёзд
        cur.execute("""
            SELECT COALESCE(SUM(cost_stars), 0)
            FROM reward_requests
            WHERE family_id = %s AND child_name = %s AND status IN ('pending', 'approved')
        """, (family_id, child_name))
        spent = cur.fetchone()[0]

        balance = earned - spent

        if balance < cost:
            cur.close()
            conn.close()
            return jsonify({"status": "not_enough_stars", "balance": balance})

        # Создаём запрос на покупку
        cur.execute("""
            INSERT INTO reward_requests (family_id, reward_id, child_name, cost_stars, status)
            VALUES (%s, %s, %s, %s, 'pending')
            RETURNING id
        """, (family_id, reward_id, child_name, cost))
        request_id = cur.fetchone()[0]

        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "ok", "request_id": request_id})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/reward_requests")
def get_reward_requests():
    try:
        family_id = request.args.get("family_id")
        if not family_id:
            return jsonify({"status": "error", "message": "family_id required"}), 400

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            SELECT rr.id, rr.family_id, rr.reward_id, rr.child_name, rr.cost_stars, 
                   rr.status, rr.created_at, rr.approved_at,
                   rs.title, rs.emoji, COALESCE(rs.color_hex, '#FFF4E5')
            FROM reward_requests rr
            JOIN reward_shop rs ON rr.reward_id = rs.id
            WHERE rr.family_id = %s
            ORDER BY rr.created_at DESC
        """, (family_id,))

        requests = []
        for row in cur.fetchall():
            requests.append({
                "id": row[0], "family_id": row[1], "reward_id": row[2],
                "child_name": row[3], "cost_stars": row[4], "status": row[5],
                "created_at": str(row[6]) if row[6] else None,
                "approved_at": str(row[7]) if row[7] else None,
                "title": row[8], "emoji": row[9] or "🎁", "color_hex": row[10],
            })

        cur.close()
        conn.close()
        return jsonify({"status": "ok", "requests": requests})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500


@app.route("/reward_requests/approve", methods=["POST"])
def approve_reward():

    data=request.json

    request_id=data["request_id"]

    conn= get_connection()
    cur=conn.cursor()

    cur.execute("""

        UPDATE reward_requests

        SET
            status='approved',
            approved_at=NOW()

        WHERE id=%s

    """,(request_id,))

    conn.commit()
    conn.close()

    return jsonify({"status":"ok"})

@app.route("/reward_requests/reject", methods=["POST"])
def reject_reward():
    try:
        data = request.get_json()
        request_id = data.get("request_id")

        conn = get_connection()
        cur = conn.cursor()
        cur.execute("UPDATE reward_requests SET status = 'rejected' WHERE id = %s", (request_id,))
        conn.commit()
        cur.close()
        conn.close()
        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

    
@app.route("/reward_requests/confirm", methods=["POST"])
def confirm_reward():
    try:
        data = request.get_json()
        request_id = data.get("request_id")

        conn = get_connection()
        cur = conn.cursor()

        cur.execute("""
            UPDATE reward_requests
            SET status = 'completed', approved_at = NOW()
            WHERE id = %s
        """, (request_id,))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500





    #загрузка аватарок

@app.route("/upload_avatar", methods=["POST"])
def upload_avatar():
    try:
        family_id = request.form.get("family_id")
        user_name = request.form.get("user_name")
        file = request.files.get("avatar")
        
        if not file:
            return jsonify({"status": "error", "message": "no file"}), 400
        
        import hashlib
        safe_name = hashlib.md5(user_name.encode()).hexdigest()[:8]
        filename = f"{family_id}_{safe_name}.jpg"
        
        img = Image.open(file)
        img = img.convert("RGB")

        # Центральный кроп в квадрат
        w, h = img.size
        size = min(w, h)
        left = (w - size) // 2
        top = (h - size) // 2
        img = img.crop((left, top, left + size, top + size))

        img = img.resize((200, 200), Image.LANCZOS)
        
        os.makedirs(UPLOAD_FOLDER, exist_ok=True)
        path = f"{UPLOAD_FOLDER}/{filename}"
        img.save(path, "JPEG", quality=70)
        
        conn = get_connection()
        cur = conn.cursor()
        cur.execute("""
            UPDATE members SET avatar = %s
            WHERE family_id = %s AND user_name = %s
        """, (f"/uploads/{filename}", family_id, user_name))
        conn.commit()
        cur.close()
        conn.close()
        
        return jsonify({"status": "ok", "avatar": f"/uploads/avatars/{filename}"})
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    



@app.route("/latest_version")
def latest_version():
    try:
        # Версия приложения (обновлять вручную при выпуске)
        current_version_name = "1.3.2"
        current_version_code = 13

        # Минимальная версия для принудительного обновления
        min_version_code = 12  # ← МЕНЯЙТЕ ВРУЧНУЮ

        return jsonify({
            "status": "ok",
            "version": current_version_name,
            "version_code": current_version_code,
            "force_update": current_version_code < min_version_code,
            "update_url": "https://apps.rustore.ru/app/com.example.family_focus"
        })
    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500

@app.route("/export_stats")
def export_stats():
    try:

        # ---------------------------------
        # Проверка секретного токена
        # ---------------------------------
        secret = request.args.get("secret", "")
        expected = os.environ.get("EXPORT_STATS_SECRET", "")

        if not expected or secret != expected:
            return jsonify({"status": "error", "message": "unauthorized"}), 403

        conn = get_connection()
        cur = conn.cursor()

        import datetime
        yesterday = datetime.date.today() - datetime.timedelta(days=1)

        # Всего семей (на сегодня)
        cur.execute("SELECT COUNT(*) FROM families;")
        total_families = cur.fetchone()[0]

        # Новые семьи за вчера
        cur.execute("""
            SELECT COUNT(*) FROM families 
            WHERE created_at >= %s
            AND created_at < %s + INTERVAL '1 day';
        """, (yesterday, yesterday))
        new_families_yesterday = cur.fetchone()[0]

        # Активные семьи вчера
        cur.execute("""
            SELECT COUNT(DISTINCT m.family_id)
            FROM members m
            JOIN families f ON f.family_id = m.family_id
            WHERE m.user_name IN (
                SELECT DISTINCT user_id FROM screen_time WHERE date = %s
            )
            AND f.created_at::date <= %s;
        """, (yesterday, yesterday))
        active_families_yesterday = cur.fetchone()[0]

        # Всего пользователей
        cur.execute("SELECT COUNT(*) FROM members;")
        total_members = cur.fetchone()[0]

        # Новые пользователи за вчера
        cur.execute("""
            SELECT COUNT(*) FROM members 
            WHERE joined_at >= %s
            AND joined_at < %s + INTERVAL '1 day';
        """, (yesterday, yesterday))
        new_members_yesterday = cur.fetchone()[0]

        # Активные пользователи вчера
        cur.execute("""
            SELECT COUNT(DISTINCT CONCAT(m.user_name, '_', m.family_id))
            FROM members m
            WHERE m.user_name IN (
                SELECT DISTINCT user_id FROM screen_time WHERE date = %s
            );
        """, (yesterday,))
        active_members_yesterday = cur.fetchone()[0]

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "date": str(yesterday),
            "total_families": total_families,
            "new_families_yesterday": new_families_yesterday,
            "active_families_yesterday": active_families_yesterday,
            "total_members": total_members,
            "new_members_yesterday": new_members_yesterday,
            "active_members_yesterday": active_members_yesterday,
        })

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    


if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000
    )