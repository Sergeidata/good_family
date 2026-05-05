from flask import Flask, request, jsonify
import sqlite3
import uuid
import random
from datetime import datetime

app = Flask(__name__)
DB_NAME = "family.db"


# =====================
# DB INIT
# =====================

def init_db():
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS families (
        family_id TEXT PRIMARY KEY,
        family_name TEXT,
        invite_code TEXT UNIQUE,
        created_at TIMESTAMP
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users (
        user_id TEXT PRIMARY KEY,
        family_id TEXT,
        name TEXT,
        role TEXT,
        created_at TIMESTAMP
    )
    """)

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS usage (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        app_name TEXT,
        minutes REAL,
        created_at TIMESTAMP
    )
    """)

    conn.commit()
    conn.close()


init_db()


# =====================
# HELPERS
# =====================

def generate_invite_code():
    return str(random.randint(100000, 999999))


def get_conn():
    return sqlite3.connect(DB_NAME)


# =====================
# CREATE FAMILY
# =====================

@app.route("/create_family", methods=["POST"])
def create_family():
    data = request.json
    family_name = data.get("family_name")

    if not family_name:
        return jsonify({"error": "family_name required"}), 400

    family_id = str(uuid.uuid4())
    invite_code = generate_invite_code()

    conn = get_conn()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO families (family_id, family_name, invite_code, created_at)
        VALUES (?, ?, ?, ?)
    """, (family_id, family_name, invite_code, datetime.utcnow()))

    conn.commit()
    conn.close()

    return jsonify({
        "family_id": family_id,
        "invite_code": invite_code
    })


# =====================
# REGISTER CHILD
# =====================

@app.route("/register_child", methods=["POST"])
def register_child():
    data = request.json
    invite_code = data.get("invite_code")
    name = data.get("name")

    if not invite_code or not name:
        return jsonify({"error": "invite_code and name required"}), 400

    conn = get_conn()
    cursor = conn.cursor()

    cursor.execute(
        "SELECT family_id FROM families WHERE invite_code = ?",
        (invite_code,)
    )
    row = cursor.fetchone()

    if not row:
        return jsonify({"error": "invalid invite_code"}), 400

    family_id = row[0]
    user_id = str(uuid.uuid4())

    cursor.execute("""
        INSERT INTO users (user_id, family_id, name, role, created_at)
        VALUES (?, ?, ?, ?, ?)
    """, (user_id, family_id, name, "child", datetime.utcnow()))

    conn.commit()
    conn.close()

    return jsonify({
        "user_id": user_id,
        "family_id": family_id
    })


# =====================
# SEND USAGE (FIXED)
# =====================

@app.route("/send_usage", methods=["POST"])
def send_usage():
    try:
        data = request.json or {}

        user_id = data.get("user_id")
        usage_list = data.get("usage", [])

        if not user_id:
            return jsonify({"error": "user_id required"}), 400

        if not isinstance(usage_list, list):
            return jsonify({"error": "usage must be list"}), 400

        conn = sqlite3.connect(DB_NAME, timeout=10)
        cursor = conn.cursor()

        for item in usage_list:
            if not isinstance(item, dict):
                continue

            app_name = item.get("app")
            minutes = item.get("minutes")

            if app_name is None or minutes is None:
                continue

            cursor.execute("""
                INSERT INTO usage (user_id, app_name, minutes, created_at)
                VALUES (?, ?, ?, ?)
            """, (
                user_id,
                str(app_name),
                float(minutes),
                datetime.utcnow()
            ))

        conn.commit()
        conn.close()

        return jsonify({"status": "ok"})

    except Exception as e:
        print("SEND_USAGE ERROR:", e)
        return jsonify({"error": str(e)}), 500


# =====================
# GET FAMILY DATA
# =====================

@app.route("/family/<family_id>", methods=["GET"])
def get_family(family_id):
    conn = get_conn()
    cursor = conn.cursor()

    # users
    cursor.execute("""
        SELECT user_id, name, role
        FROM users
        WHERE family_id = ?
    """, (family_id,))
    users = cursor.fetchall()

    # usage aggregated
    cursor.execute("""
        SELECT user_id, app_name, SUM(minutes)
        FROM usage
        GROUP BY user_id, app_name
    """)
    usage_rows = cursor.fetchall()

    conn.close()

    users_list = [
        {"user_id": u[0], "name": u[1], "role": u[2]}
        for u in users
    ]

    usage_list = [
        {"user_id": r[0], "app": r[1], "minutes": r[2]}
        for r in usage_rows
    ]

    return jsonify({
        "users": users_list,
        "usage": usage_list
    })

@app.route("/get_family_usage", methods=["POST"])
def get_family_usage():
    data = request.json
    family_id = data.get("family_id")

    if not family_id:
        return jsonify({"error": "family_id required"}), 400

    conn = get_conn()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT u.name, us.app_name, SUM(us.minutes)
        FROM usage us
        JOIN users u ON us.user_id = u.user_id
        WHERE u.family_id = ?
        GROUP BY u.name, us.app_name
    """, (family_id,))

    rows = cursor.fetchall()
    conn.close()

    result = {}

    for name, app, minutes in rows:
        if name not in result:
            result[name] = []
        result[name].append({
            "app": app,
            "minutes": minutes
        })

    return jsonify(result)
# =====================
# RUN
# =====================

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=10000)