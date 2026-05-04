import requests

BASE_URL = "https://good-family.onrender.com"


def create_family(name):
    try:
        r = requests.post(f"{BASE_URL}/create_family", json={
            "family_name": name
        })
        return r.json()
    except Exception as e:
        return {"error": str(e)}


def register_child(invite_code, name):
    try:
        r = requests.post(f"{BASE_URL}/register_child", json={
            "invite_code": invite_code,
            "name": name
        })
        return r.json()
    except Exception as e:
        return {"error": str(e)}


# ✅ ВОТ ЭТОГО У ТЕБЯ НЕ БЫЛО
def get_family_data(family_id):
    try:
        r = requests.get(f"{BASE_URL}/family/{family_id}")
        return r.json()
    except Exception as e:
        return {"error": str(e)}

# =====================
# SEND USAGE
# =====================

def send_usage(user_id, usage):
    """
    usage = [
        {"app": "YouTube", "minutes": 10},
        ...
    ]
    """
    r = requests.post(f"{BASE_URL}/send_usage", json={
        "user_id": user_id,
        "usage": usage
    })
    return r.json()


# =====================
# GET USAGE
# =====================

def get_usage(user_id):
    r = requests.post(f"{BASE_URL}/get_usage", json={
        "user_id": user_id
    })
    return r.json()

def get_children(family_id):
    r = requests.post(f"{BASE_URL}/get_children", json={
        "family_id": family_id
    })
    return r.json()

