from flask import Flask, jsonify, request
from datetime import datetime, timedelta
import psycopg2
import sqlite3
import json
import os

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
            CREATE UNIQUE INDEX IF NOT EXISTS
            idx_user_date
            ON screen_time(user_id, date);
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


if __name__ == "__main__":

    app.run(
        host="0.0.0.0",
        port=5000
    )