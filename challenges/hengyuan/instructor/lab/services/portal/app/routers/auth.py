"""登录 + JWT 鉴权。admin 端点仅 role=admin (正常员工无此 role -> 须 JWT 伪造)。"""
from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer

from .. import auth, store

router = APIRouter(prefix="/api")
bearer = HTTPBearer(auto_error=False)


@router.post("/login")
def login(body: dict):
    username = body.get("username")
    password = body.get("password")
    uid = store.BY_NAME.get(username)
    u = store.get_user(uid) if uid is not None else None
    if not u or u["password"] != password:
        raise HTTPException(401, "用户名或密码错误")
    return {"access_token": auth.issue_token(u["uid"], u["username"], u.get("role", "user")), "token_type": "bearer"}


def current_user(cred: HTTPAuthorizationCredentials = Depends(bearer)):
    if not cred:
        raise HTTPException(401, "缺少 token")
    try:
        return auth.decode_token(cred.credentials)
    except Exception as e:
        raise HTTPException(401, f"无效 token: {e}")


@router.get("/admin/users")
def admin_users(user=Depends(current_user)):
    if user.get("role") != "admin":
        raise HTTPException(403, "需要管理员权限")
    return list(store.USERS.values())