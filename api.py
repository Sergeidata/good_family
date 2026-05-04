import requests

BASE_URL = "https://good-family.onrender.com"

SESSION = {
    "user_id": None,
    "family_id": None
}


def create_family(name):
    r = requests.post(f"{BASE_URL}/create_family", json={
        "family_name": name
    })
    data = r.json()

    SESSION["family_id"] = data.get("family_id")

    return data


def register_child(invite_code, name):
    r = requests.post(f"{BASE_URL}/register_child", json={
        "invite_code": invite_code,
        "name": name
    })
    data = r.json()

    SESSION["user_id"] = data.get("user_id")
    SESSION["family_id"] = data.get("family_id")

    return data


def send_usage(usage_dict):
    return requests.post(f"{BASE_URL}/send_usage", json={
        "user_id": SESSION["user_id"],
        "usage": usage_dict
    }).json()


def get_family_data():
    return requests.get(
        f"{BASE_URL}/family/{SESSION['family_id']}"
    ).json()