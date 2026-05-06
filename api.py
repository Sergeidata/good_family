import requests

BASE_URL = "https://good-family.onrender.com"

SESSION = {
    "user_id": None,
    "family_id": None
}


# =====================
# CREATE FAMILY
# =====================

def create_family(name):
    try:
        r = requests.post(
            f"{BASE_URL}/create_family",
            json={"family_name": name},
            timeout=5
        )

        data = safe_json(r)

        SESSION["family_id"] = data.get("family_id")

        return data

    except Exception as e:
        return {"error": str(e)}


# =====================
# JOIN FAMILY (бывш. register_child)
# =====================

def join_family(invite_code, name):
    try:
        r = requests.post(
            f"{BASE_URL}/register_child",
            json={
                "invite_code": invite_code,
                "name": name
            },
            timeout=5
        )

        data = safe_json(r)

        SESSION["user_id"] = data.get("user_id")
        SESSION["family_id"] = data.get("family_id")

        return data

    except Exception as e:
        return {"error": str(e)}


# =====================
# SEND USAGE
# =====================

def send_usage(usage_list):
    if not SESSION["user_id"]:
        return {"error": "user not registered"}

    try:
        r = requests.post(
            f"{BASE_URL}/send_usage",
            json={
                "user_id": SESSION["user_id"],
                "usage": usage_list
            },
            timeout=10
        )

        print("STATUS:", r.status_code)
        print("RAW RESPONSE:", r.text)

        return safe_json(r)

    except Exception as e:
        return {"error": str(e)}


# =====================
# GET FAMILY USAGE
# =====================

def get_family_usage():
    if not SESSION["family_id"]:
        return {"error": "no family_id"}

    try:
        r = requests.post(
            f"{BASE_URL}/get_family_usage",
            json={"family_id": SESSION["family_id"]},
            timeout=5
        )

        print("STATUS:", r.status_code)
        print("RAW:", r.text)

        return safe_json(r)

    except Exception as e:
        return {"error": str(e)}


# =====================
# HELPERS
# =====================

def safe_json(response):
    try:
        return response.json()
    except Exception:
        return {
            "error": "invalid json",
            "raw": response.text
        }