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

        start_date = today - timedelta(days=6)
        end_date = today

    else:

        start_date = today
        end_date = today

    return (
        str(start_date),
        str(end_date)
    )


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
                INSERT INTO screen_time (
                    user_id,
                    date,
                    total_seconds,
                    top_apps
                )
                VALUES (%s, %s, %s, %s)
                ON CONFLICT (user_id, date)
                DO UPDATE SET
                    total_seconds = EXCLUDED.total_seconds,
                    top_apps = EXCLUDED.top_apps;
            """, (
                user_id,
                date,
                total_seconds,
                top_apps_json
            ))

        else:

            cur.execute("""
                INSERT INTO screen_time (
                    user_id,
                    date,
                    total_seconds,
                    top_apps
                )
                VALUES (?, ?, ?, ?)
                ON CONFLICT(user_id, date)
                DO UPDATE SET
                    total_seconds=excluded.total_seconds,
                    top_apps=excluded.top_apps
            """, (
                user_id,
                date,
                total_seconds,
                top_apps_json
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

        if period == "week":

            days_passed = (
                datetime.now().weekday() + 1
            )

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

        if not family_name:

            return jsonify({
                "status": "error",
                "message": "family_name required"
            }), 400

        family_id = str(uuid.uuid4())

        invite_code = str(
            random.randint(100000, 999999)
        )

        conn = get_connection()

        cur = conn.cursor()

        if is_postgres():
            cur.execute("""
                INSERT INTO families (family_id, family_name, invite_code)
                VALUES (%s, %s, %s)
            """, (family_id, family_name, invite_code))
            
            cur.execute("""
                INSERT INTO members (family_id, user_name, role)
                VALUES (%s, %s, 'admin')
            """, (family_id, user_name))
        else:
            cur.execute("""
                INSERT INTO families (family_id, family_name, invite_code)
                VALUES (?, ?, ?)
            """, (family_id, family_name, invite_code))
            
            cur.execute("""
                INSERT INTO members (family_id, user_name, role)
                VALUES (?, ?, 'admin')
            """, (family_id, user_name))

        conn.commit()       

        cur.close()
        conn.close()

        return jsonify({
            "status": "ok",
            "family_id": family_id,
            "invite_code": invite_code
        })

    except Exception as e:

        return jsonify({
            "status": "error",
            "message": str(e)
        }), 500


# ---------------------------------
# присоединение к семье
# ---------------------------------
@app.route("/join_family", methods=["POST"])
def join_family():
    try:
        data = request.get_json()
        invite_code = data.get("invite_code", "").strip()
        user_name = data.get("user_name", "").strip()

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

        # Добавляем участника
        if is_postgres():
            cur.execute("INSERT INTO members (family_id, user_name, role) VALUES (%s, %s, 'member')", (family_id, user_name))
        else:
            cur.execute("INSERT INTO members (family_id, user_name, role) VALUES (?, ?, 'member')", (family_id, user_name))

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