from flask import Flask, request, jsonify
from datetime import date
import sqlite3
import uuid
import random
from datetime import datetime
from flask import g

app = Flask(__name__)
init_db()

DB_PATH = "family.db"

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = sqlite3.connect(DB_PATH)
        db.row_factory = sqlite3.Row
        g._database = db
    return db


def init_db():
    conn = sqlite3.connect("family.db")
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

    conn.commit()
    conn.close()

    print("DB INIT CALLED")

def generate_invite_code():
    return str(random.randint(100000, 999999))

@app.route("/create_family", methods=["POST"])
def create_family():
    data = request.json

    if not data or "family_name" not in data:
        return jsonify({"error": "family_name required"}), 400

    family_name = data["family_name"]

    db = get_db()
    cursor = db.cursor()

    family_id = str(uuid.uuid4())
    invite_code = generate_invite_code()

    try:
        cursor.execute("""
            INSERT INTO families (family_id, family_name, invite_code, created_at)
            VALUES (?, ?, ?, ?)
        """, (family_id, family_name, invite_code, datetime.utcnow()))

        db.commit()

        return jsonify({
            "family_id": family_id,
            "invite_code": invite_code,
            "status": "ok"
        })

    except sqlite3.IntegrityError:
        return jsonify({"error": "invite_code collision"}), 500

@app.route("/register", methods=["POST"])
def register():
    data = request.json

    required = ["family_id", "invite_code", "name", "role"]
    if not all(k in data for k in required):
        return jsonify({"error": "missing fields"}), 400

    family_id = data["family_id"]
    invite_code = data["invite_code"]
    name = data["name"]
    role = data["role"]

    if role not in ["parent", "child"]:
        return jsonify({"error": "invalid role"}), 400

    db = get_db()
    cursor = db.cursor()

    # проверка invite_code
    cursor.execute("""
        SELECT * FROM families WHERE family_id=? AND invite_code=?
    """, (family_id, invite_code))

    family = cursor.fetchone()

    if not family:
        return jsonify({"error": "invalid invite_code or family_id"}), 404

    user_id = str(uuid.uuid4())

    cursor.execute("""
        INSERT INTO users (user_id, family_id, name, role, created_at)
        VALUES (?, ?, ?, ?, ?)
    """, (user_id, family_id, name, role, datetime.utcnow()))

    db.commit()

    return jsonify({
        "user_id": user_id,
        "status": "ok"
    })

@app.route("/register_child", methods=["POST"])
def register_child():
    data = request.json

    if not data or "invite_code" not in data or "name" not in data:
        return jsonify({"error": "invite_code and name required"}), 400

    invite_code = data["invite_code"]
    name = data["name"]

    db = get_db()
    cursor = db.cursor()

    cursor.execute("""
        SELECT family_id FROM families WHERE invite_code=?
    """, (invite_code,))

    family = cursor.fetchone()

    if not family:
        return jsonify({"error": "invalid invite_code"}), 404

    family_id = family["family_id"]
    user_id = str(uuid.uuid4())

    cursor.execute("""
        INSERT INTO users (user_id, family_id, name, role, created_at)
        VALUES (?, ?, ?, 'child', ?)
    """, (user_id, family_id, name, datetime.utcnow()))

    db.commit()

    return jsonify({
        "user_id": user_id,
        "family_id": family_id,
        "status": "ok"
    })



# -----------------------------
# Классификатор приложений
# -----------------------------
APP_CATEGORIES = {
    "social": [
        "com.instagram.android",
        "com.snapchat.android",
        "com.facebook.katana",
        "com.vkontakte.android",
        "org.telegram.messenger"
    ],

    "games": [
        "com.supercell.clashofclans",
        "com.supercell.clashroyale",
        "com.king.candycrushsaga",
        "com.nianticlabs.pokemongo"
    ]
}

# -----------------------------
# Хранилище в памяти
# -----------------------------
daily_log = {}


def classify_app(package_name):
    for category, packages in APP_CATEGORIES.items():
        if package_name in packages:
            return category
    return "neutral"


def calculate_bonus(neutral_minutes):
    return neutral_minutes * 0.5


# -----------------------------
# Upload usage stats
# -----------------------------
@app.route("/upload_stats", methods=["POST"])
def upload_stats():
    data = request.json

    family_id = data["family_id"]
    member = data["member"]
    usage = data["usage"]

    bad_minutes = 0
    neutral_minutes = 0

    for package_name, minutes in usage.items():
        category = classify_app(package_name)

        if category in ["social", "games"]:
            bad_minutes += minutes
        else:
            neutral_minutes += minutes

    bonus = calculate_bonus(neutral_minutes)

    key = f"{family_id}:{member}:{date.today()}"

    daily_log[key] = {
        "bad_minutes": bad_minutes,
        "neutral_minutes": neutral_minutes,
        "bonus": bonus
    }

    return jsonify({
        "status": "ok",
        "bad_minutes": bad_minutes,
        "neutral_minutes": neutral_minutes,
        "bonus": bonus
    })


# -----------------------------
# Get reward
# -----------------------------
@app.route("/get_reward", methods=["GET"])
def get_reward():
    family_id = request.args.get("family_id")
    member = request.args.get("member")

    key = f"{family_id}:{member}:{date.today()}"

    result = daily_log.get(key, {
        "bad_minutes": 0,
        "neutral_minutes": 0,
        "bonus": 0
    })

    return jsonify(result)



@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()


# -----------------------------
# Run server
# -----------------------------



if __name__ == "__main__":
    init_db()
    app.run(host="0.0.0.0", port=5000)

