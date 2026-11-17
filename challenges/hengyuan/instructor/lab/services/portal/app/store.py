"""员工内存存储 (单一事实源 seed/employees.json)。重置改密仅内存, 重启重种子 -> 确定性。"""
import json
from pathlib import Path

SEED = Path("/app/seed/employees.json")
_data = json.loads(SEED.read_text(encoding="utf-8"))
USERS = {e["uid"]: dict(e) for e in _data["employees"]}
BY_NAME = {e["username"]: e["uid"] for e in _data["employees"]}


def get_user(uid):
    return USERS.get(uid)


def set_password(uid, pw):
    if uid in USERS:
        USERS[uid]["password"] = pw