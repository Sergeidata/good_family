from flask import Flask, request, jsonify
import sqlite3
import uuid
import random
from datetime import datetime

app = Flask(__name__)
DB_NAME = "family.db"


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


def generate_invite_code():
    return str(random.randint(100000, 999999))


@app.route("/create_family", methods=["POST"])
def create_family():
    data = request.json
    name = data.get("family_name")

    if not name:
        return jsonify({"error": "family_name required"}), 400

    family_id = str(uuid.uuid4())
    invite_code = generate_invite_code()

    conn = sqlite3.connect(DB_NAME)
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


@app.route("/register_child", methods=["POST"])
def register_child():
    data = request.json
    code = data.get("invite_code")
    name = data.get("name")

    if not code or not name:
        return jsonify({"error": "invite_code and name required"}), 400

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("SELECT family_id FROM families WHERE invite_code = ?", (code,))
    row = cursor.fetchone()

    if not row:
        return jsonify({"error": "invalid invite_code"}), 400

    family_id = row[0]
    user_id = str(uuid.uuid4())

    cursor.execute("""
        INSERT INTO users VALUES (?, ?, ?, ?, ?)
    """, (user_id, family_id, name, "child", datetime.utcnow()))

    conn.commit()
    conn.close()

    return jsonify({
        "user_id": user_id,
        "family_id": family_id
    })


@app.route("/send_usage", methods=["POST"])
def send_usage():
    data = request.json

    user_id = data.get("user_id")
    usage = data.get("usage")

    if not user_id or not usage:
        return jsonify({"error": "missing data"}), 400

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    for app, minutes in usage.items():
        cursor.execute("""
            INSERT INTO usage (user_id, app_name, minutes, created_at)
            VALUES (?, ?, ?, ?)
        """, (user_id, app, minutes, datetime.utcnow()))

    conn.commit()
    conn.close()

    return jsonify({"status": "ok"})


@app.route("/family/<family_id>", methods=["GET"])
def get_family(family_id):
    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT user_id, name, role
        FROM users
        WHERE family_id = ?
    """, (family_id,))

    users = cursor.fetchall()
    conn.close()

    return jsonify({
        "users": [
            {"user_id": u[0], "name": u[1], "role": u[2]}
            for u in users
        ]
    })


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=10000)