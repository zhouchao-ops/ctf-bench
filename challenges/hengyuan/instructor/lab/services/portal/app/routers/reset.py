"""可预测重置 token: md5(uid:ts), ts=服务器时间 (Date 头泄露), 窗口 now-60..now (<=61 候选)。"""
import hashlib
import os
import time

from fastapi import APIRouter, HTTPException

from .. import store

router = APIRouter(prefix="/api")
WINDOW = int(os.environ.get("RESET_TOKEN_WINDOW", "60"))


@router.post("/password-reset")
def request_reset(body: dict):
    uid = body.get("uid")
    try:
        uid = int(uid)
    except (TypeError, ValueError):
        raise HTTPException(400, "uid 无效")
    u = store.get_user(uid)
    if not u:
        raise HTTPException(404, "用户不存在")
    ts = int(time.time())
    token = hashlib.md5(f"{uid}:{ts}".encode()).hexdigest()
    # lab: "邮件" 仅记录到 stdout, 不返回 token。攻击者用响应 Date 头时间离线预测。
    print(f"[reset] uid={uid} token={token} ts={ts} (模拟邮件发送)", flush=True)
    return {"msg": "重置链接已发送至注册邮箱", "uid": uid}


@router.get("/reset")
def confirm_reset(uid: int, token: str, new_password: str):
    u = store.get_user(uid)
    if not u:
        raise HTTPException(404, "用户不存在")
    now = int(time.time())
    valid = {hashlib.md5(f"{uid}:{ts}".encode()).hexdigest() for ts in range(now - WINDOW, now + 1)}
    if token not in valid:
        raise HTTPException(400, "无效或过期的重置 token")
    store.set_password(uid, new_password)
    return {"msg": "密码已重置", "username": u["username"]}