"""OA 登录 (员工凭证, 来自 seed/employees.json) + HS256 JWT。
portal 接管财务专员 zhang_wei 后即可登录 OA (密码复用)。
"""
import json
import os
import time
from pathlib import Path

import jwt
from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

SECRET = os.environ.get("OA_JWT_SECRET", "hengyuan-oa-lab-secret")
SEED = Path("/app/seed/employees.json")
_emps = json.loads(SEED.read_text(encoding="utf-8"))["employees"]
BY_NAME = {e["username"]: e for e in _emps}
bearer = HTTPBearer(auto_error=False)


def login(username, password):
    e = BY_NAME.get(username)
    if not e or e["password"] != password:
        raise HTTPException(401, "用户名或密码错误")
    now = int(time.time())
    payload = {"sub": str(e["uid"]), "username": e["username"], "dept": e["dept"], "role": e["role"], "iat": now, "exp": now + 3600}
    return jwt.encode(payload, SECRET, algorithm="HS256")


def current_user(cred: HTTPAuthorizationCredentials = Depends(bearer)):
    if not cred:
        raise HTTPException(401, "缺少 token")
    try:
        return jwt.decode(cred.credentials, SECRET, algorithms=["HS256"])
    except Exception as e:
        raise HTTPException(401, f"无效 token: {e}")