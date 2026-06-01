from flask import Flask, jsonify, request
from datetime import datetime, timedelta
import psycopg2
import sqlite3
import json
import os
import uuid
import random

app = Flask(__name__)

DATABASE_URL = (
    "postgresql://familyfocus_user:"
    "f0waVyp8TExMqjZn1sNSQhZxDsMB38Ts"
    "@dpg-d85c92ojs32c73adrcag-a/familyfocus"
)


# ---------------------------------
# Database
# ---------------------------------
def is_postgres():
    return bool(os.environ.get("RENDER"))


def get_connection():

    if is_postgres():

        return psycopg2.connect(
            DATABASE_URL
        )

    else:

        conn = sqlite3.connect(
            "familyfocus.db"
        )

        conn.row_factory = sqlite3.Row

        return conn


def init_db():
    conn = get_connection()
    cur = conn.cursor()

    if is_postgres():
        cur.execute("""
            CREATE TABLE IF NOT EXISTS screen_time (
                id SERIAL PRIMARY KEY,
                user_id TEXT NOT NULL,
                date DATE NOT NULL,
                total_seconds INTEGER DEFAULT 0,
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

        cur.execute("""
            ALTER TABLE members ADD COLUMN IF NOT EXISTS device_id TEXT
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS achievements (
                id SERIAL PRIMARY KEY,
                user_name TEXT NOT NULL,
                family_id TEXT NOT NULL,
                achievement_key TEXT NOT NULL,
                period TEXT NOT NULL,
                earned_date DATE NOT NULL,
                UNIQUE(user_name, achievement_key, period)
            );
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS garden (
                id SERIAL PRIMARY KEY,
                family_id TEXT UNIQUE NOT NULL,
                level INTEGER DEFAULT 1,
                updated_at TIMESTAMP DEFAULT NOW()
            );
        """)

    else:
        cur.execute("""
            CREATE TABLE IF NOT EXISTS screen_time (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id TEXT,
                date TEXT,
                total_seconds INTEGER,
                top_apps TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                UNIQUE(user_id, date)
            )
        """)


        
        cur.execute("""
            CREATE TABLE IF NOT EXISTS families (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                family_id TEXT UNIQUE,
                family_name TEXT,
                invite_code TEXT UNIQUE,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        
        cur.execute("""
            CREATE TABLE IF NOT EXISTS members (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                family_id TEXT NOT NULL,
                user_name TEXT NOT NULL,
                role TEXT DEFAULT 'member',
                joined_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)

        try:
            cur.execute("ALTER TABLE members ADD COLUMN device_id TEXT")
        except:
            pass

        cur.execute("""
            CREATE TABLE IF NOT EXISTS achievements (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_name TEXT NOT NULL,
                family_id TEXT NOT NULL,
                achievement_key TEXT NOT NULL,
                period TEXT NOT NULL,
                earned_date TEXT NOT NULL,
                UNIQUE(user_name, achievement_key, period)
            )
        """)

        cur.execute("""
            CREATE TABLE IF NOT EXISTS garden (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                family_id TEXT UNIQUE NOT NULL,
                level INTEGER DEFAULT 1,
                updated_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        """)

    conn.commit()
    cur.close()
    conn.close()


init_db()


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

        total_seconds = data.get(
            "total_seconds",
            0
        )

        top_apps = data.get(
            "top_apps",
            []
        )

        if not user_id or not date:

            return jsonify({
                "status": "error",
                "message": "user_id and date required"
            }), 400

        conn = get_connection()

        cur = conn.cursor()

        top_apps_json = json.dumps(top_apps)

        if is_postgres():
            cur.execute("""
                INSERT INTO screen_time (user_id, date, total_seconds, top_apps)
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (user_id, date)
                DO UPDATE SET
                    total_seconds = EXCLUDED.total_seconds,
                    top_apps = EXCLUDED.top_apps,
                    created_at = NOW()
            """, (user_id, date, total_seconds, top_apps_json))

        else:
            cur.execute("""
                INSERT INTO screen_time (user_id, date, total_seconds, top_apps)
                VALUES (?, ?, ?, ?)
                ON CONFLICT(user_id, date)
                DO UPDATE SET
                    total_seconds = excluded.total_seconds,
                    top_apps = excluded.top_apps,
                    created_at = CURRENT_TIMESTAMP
            """, (user_id, date, total_seconds, top_apps_json))

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

        if is_postgres():

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

        else:

            cur.execute("""
                SELECT
                    total_seconds,
                    top_apps
                FROM screen_time
                WHERE user_id = ?
                AND date BETWEEN ? AND ?
            """, (
                user_id,
                start_date,
                end_date
            ))

        rows = cur.fetchall()

        total_seconds = 0

        app_totals = {}

        for row in rows:

            if is_postgres():

                total = row[0]
                top_apps = row[1]

            else:

                total = row["total_seconds"]

                top_apps_raw = row["top_apps"]

                try:
                    top_apps = json.loads(
                        top_apps_raw
                    )
                except Exception:
                    top_apps = []

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

        if not family_name:
            return jsonify({"status": "error", "message": "family_name required"}), 400

        family_id = str(uuid.uuid4())
        invite_code = str(random.randint(100000, 999999))

        conn = get_connection()
        cur = conn.cursor()

        if is_postgres():
            cur.execute("""
                INSERT INTO families (family_id, family_name, invite_code)
                VALUES (%s, %s, %s)
            """, (family_id, family_name, invite_code))
            
            cur.execute("""
                INSERT INTO members (family_id, user_name, role, device_id)
                VALUES (%s, %s, 'admin', %s)
            """, (family_id, user_name, device_id))
        else:
            cur.execute("""
                INSERT INTO families (family_id, family_name, invite_code)
                VALUES (?, ?, ?)
            """, (family_id, family_name, invite_code))
            
            cur.execute("""
                INSERT INTO members (family_id, user_name, role, device_id)
                VALUES (?, ?, 'admin', ?)
            """, (family_id, user_name, device_id))

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

        if not invite_code:
            return jsonify({"status": "error", "message": "invite_code required"}), 400

        conn = get_connection()
        cur = conn.cursor()

        if is_postgres():
            cur.execute("SELECT family_id, family_name FROM families WHERE invite_code = %s", (invite_code,))
        else:
            cur.execute("SELECT family_id, family_name FROM families WHERE invite_code = ?", (invite_code,))

        row = cur.fetchone()

        if not row:
            cur.close()
            conn.close()
            return jsonify({"status": "error", "message": "family not found"}), 404

        if is_postgres():
            family_id = row[0]
            family_name = row[1]
        else:
            family_id = row["family_id"]
            family_name = row["family_name"]

        # Проверка device_id
        if device_id:
            if is_postgres():
                cur.execute("SELECT user_name FROM members WHERE family_id = %s AND device_id = %s", (family_id, device_id))
            else:
                cur.execute("SELECT user_name FROM members WHERE family_id = ? AND device_id = ?", (family_id, device_id))
            
            existing = cur.fetchone()
            
            if existing:
                # Обновить имя существующего участника
                if is_postgres():
                    cur.execute("UPDATE members SET user_name = %s WHERE family_id = %s AND device_id = %s", (user_name, family_id, device_id))
                else:
                    cur.execute("UPDATE members SET user_name = ? WHERE family_id = ? AND device_id = ?", (user_name, family_id, device_id))
                
                conn.commit()
                cur.close()
                conn.close()
                return jsonify({"status": "ok", "family_id": family_id, "family_name": family_name})

        # Добавляем нового участника
        if is_postgres():
            cur.execute("INSERT INTO members (family_id, user_name, role, device_id) VALUES (%s, %s, 'member', %s)", (family_id, user_name, device_id))
        else:
            cur.execute("INSERT INTO members (family_id, user_name, role, device_id) VALUES (?, ?, 'member', ?)", (family_id, user_name, device_id))

        conn.commit()
        cur.close()
        conn.close()

        return jsonify({"status": "ok", "family_id": family_id, "family_name": family_name})

    except Exception as e:
        return jsonify({"status": "error", "message": str(e)}), 500
    


@app.route("/family_members", methods=["GET"])
def family_members():

    family_id = request.args.get("family_id")

    conn = get_connection()
    cursor = conn.cursor()

    if os.environ.get("RENDER"):

        cursor.execute(
            """
            SELECT user_name, role, joined_at
            FROM members
            WHERE family_id = %s
            ORDER BY joined_at ASC
            """,
            (family_id,)
        )

        rows = cursor.fetchall()

        members = []

        for row in rows:
            members.append({
                "user_name": row[0],
                "role": row[1],
                "joined_at": str(row[2])
            })

    else:

        cursor.execute(
            """
            SELECT user_name, role, joined_at
            FROM members
            WHERE family_id = ?
            ORDER BY joined_at ASC
            """,
            (family_id,)
        )

        rows = cursor.fetchall()

        members = []

        for row in rows:
            members.append({
                "user_name": row["user_name"],
                "role": row["role"],
                "joined_at": str(row["joined_at"])
            })

    conn.close()

    return jsonify({
        "members": members
    })

@app.route(
    "/remove_member",
    methods=["POST"]
)
def remove_member():

    try:

        data = request.json

        family_id = data.get(
            "family_id"
        )

        user_name = data.get(
            "user_name"
        )

        requester_device_id = data.get(
            "requester_device_id"
        )

        if (
            not family_id
            or not user_name
            or not requester_device_id
        ):
            return jsonify({
                "status": "error",
                "message": "missing fields"
            }), 400

        conn = get_connection()
        cur = conn.cursor()

        # проверяем что запросил админ

        if is_postgres():

            cur.execute("""
                SELECT role
                FROM members
                WHERE family_id = %s
                AND device_id = %s
            """, (
                family_id,
                requester_device_id
            ))

        else:

            cur.execute("""
                SELECT role
                FROM members
                WHERE family_id = ?
                AND device_id = ?
            """, (
                family_id,
                requester_device_id
            ))

        admin_row = cur.fetchone()

        if not admin_row:

            cur.close()
            conn.close()

            return jsonify({
                "status": "error",
                "message": "not member"
            }), 403

        role = (
            admin_row[0]
            if is_postgres()
            else admin_row["role"]
        )

        if role != "admin":

            cur.close()
            conn.close()

            return jsonify({
                "status": "error",
                "message": "admin only"
            }), 403

        # удаляем участника

        if is_postgres():

            cur.execute("""
                DELETE FROM members
                WHERE family_id = %s
                AND user_name = %s
            """, (
                family_id,
                user_name
            ))

        else:

            cur.execute("""
                DELETE FROM members
                WHERE family_id = ?
                AND user_name = ?
            """, (
                family_id,
                user_name
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

        if is_postgres():

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

        else:

            cur.execute("""
                SELECT
                    m.user_name,
                    MAX(st.created_at) as last_sync
                FROM members m
                LEFT JOIN screen_time st
                    ON m.user_name = st.user_id
                WHERE m.family_id = ?
                GROUP BY m.user_name
                ORDER BY m.user_name
            """, (
                family_id,
            ))

            rows = cur.fetchall()

            members = []

            for row in rows:

                members.append({
                    "user_name":
                        row["user_name"],
                    "last_sync":
                        row["last_sync"]
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

    if is_postgres():

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

    else:

        cur.execute("""
            SELECT
                family_name,
                invite_code,
                created_at
            FROM families
            WHERE family_id = ?
        """, (
            family_id,
        ))

        row = cur.fetchone()

        if not row:
            return jsonify({
                "status": "error"
            }), 404

        result = {
            "family_name": row["family_name"],
            "invite_code": row["invite_code"],
            "created_at": row["created_at"]
        }

    cur.close()
    conn.close()

    return jsonify({
        "status": "ok",
        **result
    })


@app.route(
    "/achievements/check",
    methods=["POST"]
)
def achievement_check():

    try:

        data = request.get_json()

        family_id = data.get(
            "family_id"
        )

        user_name = data.get(
            "user_name"
        )

        achievement_key = data.get(
            "achievement_key"
        )

        period = data.get(
            "period"
        )

        earned_date = data.get(
            "earned_date"
        )

        if (
            not family_id or
            not user_name or
            not achievement_key or
            not period or
            not earned_date
        ):
            return jsonify({
                "status": "error",
                "message": "missing fields"
            }), 400

        conn = get_connection()
        cur = conn.cursor()

        if is_postgres():

            cur.execute("""
                INSERT INTO achievements (
                    user_name,
                    family_id,
                    achievement_key,
                    period,
                    earned_date
                )
                VALUES (%s,%s,%s,%s,%s)
                ON CONFLICT (
                    user_name,
                    achievement_key,
                    period
                )
                DO NOTHING
            """, (
                user_name,
                family_id,
                achievement_key,
                period,
                earned_date
            ))

            cur.execute("""
                SELECT COUNT(*)
                FROM achievements
                WHERE user_name=%s
                AND achievement_key=%s
            """, (
                user_name,
                achievement_key
            ))

            count = cur.fetchone()[0]

        else:

            cur.execute("""
                INSERT OR IGNORE INTO achievements (
                    user_name,
                    family_id,
                    achievement_key,
                    period,
                    earned_date
                )
                VALUES (?,?,?,?,?)
            """, (
                user_name,
                family_id,
                achievement_key,
                period,
                earned_date
            ))

            cur.execute("""
                SELECT COUNT(*) AS cnt
                FROM achievements
                WHERE user_name=?
                AND achievement_key=?
            """, (
                user_name,
                achievement_key
            ))

            count = cur.fetchone()[0]

        conn.commit()

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "count": count
        })

    except Exception as e:

        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route(
    "/achievements",
    methods=["GET"]
)
def achievements():

    try:

        family_id = request.args.get(
            "family_id"
        )

        period = request.args.get(
            "period"
        )

        min_date = request.args.get(
            "min_date"
        )

        if not family_id:

            return jsonify({
                "status": "error",
                "message": "family_id required"
            }), 400

        conn = get_connection()
        cur = conn.cursor()

        if is_postgres():

            if period:

                cur.execute("""
                    SELECT
                        user_name,
                        min_date,
                        achievement_key,
                        period,
                        earned_date
                    FROM achievements
                    WHERE family_id=%s
                    AND period=%s
                    AND earned_date >= %s
                    ORDER BY earned_date DESC
                """, (
                    family_id,
                    period,
                    min_date
                ))

            else:

            
                if min_date:
                    cur.execute("""
                        SELECT user_name, achievement_key, period, earned_date
                        FROM achievements
                        WHERE family_id=%s AND earned_date >= %s
                        ORDER BY earned_date DESC
                    """, (family_id, min_date))
                else:
                    cur.execute("""
                        SELECT user_name, achievement_key, period, earned_date
                        FROM achievements
                        WHERE family_id=%s
                        ORDER BY earned_date DESC
                    """, (family_id,))

            rows = cur.fetchall()

            result = []

            for row in rows:

                result.append({
                    "user_name": row[0],
                    "achievement_key": row[1],
                    "period": row[2],
                    "earned_date": str(row[3])
                })

        else:

            if period:

                cur.execute("""
                    SELECT *
                    FROM achievements
                    WHERE family_id=?
                    AND period=?
                    AND earned_date >= ?
                    ORDER BY earned_date DESC
                """, (
                    family_id,
                    period,
                    min_date
                ))

            else:
                if min_date:
                    cur.execute("""
                        SELECT user_name, achievement_key, period, earned_date
                        FROM achievements
                        WHERE family_id=%s AND earned_date >= %s
                        ORDER BY earned_date DESC
                    """, (family_id, min_date))
                else:
                    cur.execute("""
                        SELECT user_name, achievement_key, period, earned_date
                        FROM achievements
                        WHERE family_id=%s
                        ORDER BY earned_date DESC
                    """, (family_id,))

            rows = cur.fetchall()

            result = []

            for row in rows:

                result.append({
                    "user_name": row["user_name"],
                    "achievement_key": row["achievement_key"],
                    "period": row["period"],
                    "earned_date": row["earned_date"]
                })

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "achievements": result
        })

    except Exception as e:

        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500
    
@app.route("/garden")
def get_garden():

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

        if is_postgres():

            cur.execute("""
                SELECT
                    level,
                    updated_at
                FROM garden
                WHERE family_id = %s
            """, (
                family_id,
            ))

            row = cur.fetchone()

            if row:

                result = {
                    "level": row[0],
                    "updated_at": str(row[1])
                }

            else:

                result = {
                    "level": 1,
                    "updated_at": None
                }

        else:

            cur.execute("""
                SELECT
                    level,
                    updated_at
                FROM garden
                WHERE family_id = ?
            """, (
                family_id,
            ))

            row = cur.fetchone()

            if row:

                result = {
                    "level": row["level"],
                    "updated_at": row["updated_at"]
                }

            else:

                result = {
                    "level": 1,
                    "updated_at": None
                }

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            **result
        })

    except Exception as e:

        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500
    

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

        if is_postgres():

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

        else:

            cur.execute("""
                SELECT level
                FROM garden
                WHERE family_id = ?
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
                    VALUES (?, ?)
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

                current_level = row["level"]

                final_level = current_level

                if new_level > current_level:

                    cur.execute("""
                        UPDATE garden
                        SET
                            level = ?,
                            updated_at = CURRENT_TIMESTAMP
                        WHERE family_id = ?
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

        # последние достижения семьи
        if is_postgres():

            cur.execute("""
                SELECT
                    achievement_key,
                    earned_date
                FROM achievements
                WHERE family_id = %s
                ORDER BY earned_date DESC
                LIMIT 20
            """, (
                family_id,
            ))

        else:

            cur.execute("""
                SELECT
                    achievement_key,
                    earned_date
                FROM achievements
                WHERE family_id = ?
                ORDER BY earned_date DESC
                LIMIT 20
            """, (
                family_id,
            ))

        achievement_rows = cur.fetchall()

        achievements = []

        for row in achievement_rows:

            if is_postgres():

                achievements.append({
                    "achievement_key": row[0],
                    "earned_date": str(row[1])
                })

            else:

                achievements.append({
                    "achievement_key":
                        row["achievement_key"],
                    "earned_date":
                        row["earned_date"]
                })

        # уровень сада

        if is_postgres():

            cur.execute("""
                SELECT level
                FROM garden
                WHERE family_id = %s
            """, (
                family_id,
            ))

        else:

            cur.execute("""
                SELECT level
                FROM garden
                WHERE family_id = ?
            """, (
                family_id,
            ))

        garden_row = cur.fetchone()

        garden_level = (
            garden_row[0]
            if garden_row
            else 1
        )

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "achievements": achievements,
            "garden_level": garden_level
        })

    except Exception as e:

        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


@app.route("/debug/members")
def debug_members():
    conn = get_connection()
    cur = conn.cursor()
    if is_postgres():
        cur.execute("SELECT * FROM members")
    else:
        cur.execute("SELECT * FROM members")
    rows = cur.fetchall()
    result = []
    for row in rows:
        if is_postgres():
            result.append({"id": row[0], "family_id": row[1], "user_name": row[2], "role": row[3]})
        else:
            result.append({"id": row["id"], "family_id": row["family_id"], "user_name": row["user_name"], "role": row["role"]})
    cur.close()
    conn.close()
    return jsonify({"members": result})

if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000
    )