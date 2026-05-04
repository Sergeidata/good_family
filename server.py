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

    conn = sqlite3.connect(DB_NAME)
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

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("SELECT family_id FROM families WHERE invite_code = ?", (invite_code,))
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
# SEND USAGE
# =====================

@app.route("/send_usage", methods=["POST"])
def send_usage():
    data = request.json

    user_id = data.get("user_id")
    usage_list = data.get("usage")  # список

    if not user_id or not usage_list:
        return jsonify({"error": "user_id and usage required"}), 400

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    for item in usage_list:
        cursor.execute("""
            INSERT INTO usage (user_id, app_name, minutes, created_at)
            VALUES (?, ?, ?, ?)
        """, (
            user_id,
            item["app"],
            item["minutes"],
            datetime.utcnow()
        ))

    conn.commit()
    conn.close()

    return jsonify({"status": "ok"})


# =====================
# GET USAGE (для родителя/ребенка)
# =====================

@app.route("/get_usage", methods=["POST"])
def get_usage():
    data = request.json
    user_id = data.get("user_id")

    if not user_id:
        return jsonify({"error": "user_id required"}), 400

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT app_name, SUM(minutes)
        FROM usage
        WHERE user_id = ?
        GROUP BY app_name
        ORDER BY SUM(minutes) DESC
    """, (user_id,))

    rows = cursor.fetchall()
    conn.close()

    result = [
        {"app": row[0], "minutes": row[1]}
        for row in rows
    ]

    return jsonify(result)


# =====================
# RUN
# =====================

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=10000)