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


def get_conn():
    return sqlite3.connect(DB_NAME)


def generate_invite_code():
    return str(random.randint(100000, 999999))


# =====================
# CREATE FAMILY
# =====================

@app.route("/create_family", methods=["POST"])
def create_family():
    data = request.json or {}
    name = data.get("family_name")

    if not name:
        return jsonify({"error": "family_name required"}), 400

    family_id = str(uuid.uuid4())
    invite_code = generate_invite_code()

    conn = get_conn()
    cursor = conn.cursor()

    cursor.execute("""
        INSERT INTO families VALUES (?, ?, ?, ?)
    """, (family_id, name, invite_code, datetime.utcnow()))

    conn.commit()
    conn.close()

    return jsonify({
        "family_id": family_id,
        "invite_code": invite_code
    })


# =====================
# JOIN FAMILY
# =====================

@app.route("/join_family", methods=["POST"])
def join_family():
    data = request.json or {}
    code = data.get("invite_code")
    name = data.get("name")

    if not code or not name:
        return jsonify({"error": "invite_code and name required"}), 400

    conn = get_conn()
    cursor = conn.cursor()

    cursor.execute("SELECT family_id FROM families WHERE invite_code = ?", (code,))
    row = cursor.fetchone()

    if not row:
        return jsonify({"error": "invalid invite_code"}), 400

    family_id = row[0]
    user_id = str(uuid.uuid4())

    cursor.execute("""
        INSERT INTO users VALUES (?, ?, ?, ?)
    """, (user_id, family_id, name, datetime.utcnow()))

    conn.commit()
    conn.close()

    return jsonify({
        "user_id": user_id,
        "family_id": family_id
    })


# =====================
# SEND USAGE (NO DUPES)
# =====================

@app.route("/send_usage", methods=["POST"])
def send_usage():
    try:
        data = request.json or {}

        user_id = data.get("user_id")
        usage_list = data.get("usage", [])

        if not user_id:
            return jsonify({"error": "user_id required"}), 400

        conn = get_conn()
        cursor = conn.cursor()

        for item in usage_list:
            app = item.get("app")
            minutes = item.get("minutes")

            if not app or minutes is None:
                continue

            # UPSERT логика
            cursor.execute("""
                SELECT id FROM usage
                WHERE user_id = ? AND app_name = ?
            """, (user_id, app))

            row = cursor.fetchone()

            if row:
                cursor.execute("""
                    UPDATE usage
                    SET minutes = ?, created_at = ?
                    WHERE id = ?
                """, (float(minutes), datetime.utcnow(), row[0]))
            else:
                cursor.execute("""
                    INSERT INTO usage (user_id, app_name, minutes, created_at)
                    VALUES (?, ?, ?, ?)
                """, (user_id, app, float(minutes), datetime.utcnow()))

        conn.commit()
        conn.close()

        return jsonify({"status": "ok"})

    except Exception as e:
        print("ERROR:", e)
        return jsonify({"error": str(e)}), 500


# =====================
# GET FAMILY USAGE
# =====================

@app.route("/get_family_usage", methods=["POST"])
def get_family_usage():
    data = request.json or {}
    family_id = data.get("family_id")

    if not family_id:
        return jsonify({"error": "family_id required"}), 400

    conn = get_conn()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT u.name, us.app_name, us.minutes
        FROM usage us
        JOIN users u ON u.user_id = us.user_id
        WHERE u.family_id = ?
    """, (family_id,))

    rows = cursor.fetchall()
    conn.close()

    result = {}

    for name, app, minutes in rows:
        result.setdefault(name, []).append({
            "app": app,
            "minutes": minutes
        })

    return jsonify(result)


# =====================
# RUN
# =====================

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=10000)