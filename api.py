import requests

BASE_URL = "https://good-family.onrender.com"


def create_family(family_name):
    r = requests.post(f"{BASE_URL}/create_family", json={
        "family_name": family_name
    })
    return r.json()


def register_parent(family_id, invite_code, name):
    r = requests.post(f"{BASE_URL}/register", json={
        "family_id": family_id,
        "invite_code": invite_code,
        "name": name,
        "role": "parent"
    })
    return r.json()


def register_child(invite_code, name):
    r = requests.post(f"{BASE_URL}/register_child", json={
        "invite_code": invite_code,
        "name": name
    })
    return r.json()