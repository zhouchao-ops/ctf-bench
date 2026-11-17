"""IDOR: 顺序 uid, 无鉴权 -> 枚举员工 (喂重置 token uid + OA 用户名)。"""
from fastapi import APIRouter, HTTPException

from .. import store

router = APIRouter(prefix="/api")


@router.get("/users/{uid}/profile")
def profile(uid: int):
    u = store.get_user(uid)
    if not u:
        raise HTTPException(404, "用户不存在")
    return {k: u[k] for k in ("uid", "username", "name", "dept", "role", "email")}