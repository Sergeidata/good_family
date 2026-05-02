from flask import Flask, request, jsonify
from datetime import date

app = Flask(__name__)

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


# -----------------------------
# Run server
# -----------------------------
@app.route("/")
def home():
    return "Family Focus API is running"


if __name__ == "__main__":
    app.run()