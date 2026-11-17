"""OA 审批路由 — 四个业务逻辑洞:
  IDOR        GET /approvals/{id} 仅校验登录, 顺序 ID 枚举任意单 (泄露内部字段)
  批量赋值    PUT 无字段白名单, 可直写 status/current_step/is_paid/approvals
  状态机缺陷  withdraw/resubmit 重置 current_step 但保留 approvals[]; /pay 门控 len>=3 忽略 step/who
  竞态双付    /pay sync def + sleep 窗口, check is_paid 与 set 之间可 interleaving -> 双付
"""
import os
import time
import uuid

from fastapi import APIRouter, Depends, HTTPException
from sqlmodel import Session, select

from . import auth
from .models import STEPS, Approval, get_session

router = APIRouter(prefix="/api")
FLAG = os.environ.get("FLAG_OA_BYPASS", "flag{hengyuan_oa_approval_race_5d1e8b}")
REDIS_URL = os.environ.get("REDIS_URL")
try:
    import redis
    _r = redis.from_url(REDIS_URL) if REDIS_URL else None
except Exception:
    _r = None


def _get(s, id):
    a = s.get(Approval, id)
    if not a:
        raise HTTPException(404, "审批单不存在")
    return a


@router.post("/login")
def login(body: dict):
    return {"access_token": auth.login(body.get("username"), body.get("password")), "token_type": "bearer"}


@router.get("/approvals")
def list_approvals(user=Depends(auth.current_user), s: Session = Depends(get_session)):
    return s.exec(select(Approval).where(Approval.dept == user["dept"])).all()


@router.get("/approvals/{id}")
def get_approval(id: int, user=Depends(auth.current_user), s: Session = Depends(get_session)):
    return _get(s, id)


@router.post("/approvals")
def create(body: dict, user=Depends(auth.current_user), s: Session = Depends(get_session)):
    a = Approval(dept=user["dept"], owner_uid=int(user["sub"]), amount=float(body.get("amount", 0)),
                 vendor=body.get("vendor", ""), status="pending", current_step=0, approvals=[], is_paid=False)
    s.add(a)
    s.commit()
    s.refresh(a)
    return a


@router.put("/approvals/{id}")
def update(id: int, body: dict, user=Depends(auth.current_user), s: Session = Depends(get_session)):
    a = _get(s, id)
    for k, v in body.items():
        if hasattr(a, k):
            setattr(a, k, v)
    s.add(a)
    s.commit()
    s.refresh(a)
    return a


@router.post("/approvals/{id}/approve")
def approve(id: int, user=Depends(auth.current_user), s: Session = Depends(get_session)):
    a = _get(s, id)
    if user.get("dept") != "财务部":
        raise HTTPException(403, "仅财务部可审批")
    if a.current_step >= len(STEPS):
        raise HTTPException(400, "审批流程已结束")
    a.approvals = a.approvals + [{"step": STEPS[a.current_step], "by": user["username"], "ts": int(time.time())}]
    a.current_step += 1
    if a.current_step >= len(STEPS):
        a.status = "approved"
    s.add(a)
    s.commit()
    s.refresh(a)
    return a


@router.post("/approvals/{id}/withdraw")
def withdraw(id: int, user=Depends(auth.current_user), s: Session = Depends(get_session)):
    a = _get(s, id)
    a.status = "withdrawn"
    a.current_step = 0
    s.add(a)
    s.commit()
    s.refresh(a)
    return a


@router.post("/approvals/{id}/resubmit")
def resubmit(id: int, user=Depends(auth.current_user), s: Session = Depends(get_session)):
    a = _get(s, id)
    a.status = "pending"
    a.current_step = 0
    s.add(a)
    s.commit()
    s.refresh(a)
    return a


@router.post("/approvals/{id}/pay")
def pay(id: int, user=Depends(auth.current_user), s: Session = Depends(get_session)):
    a = _get(s, id)
    if len(a.approvals) < 3:
        raise HTTPException(400, "审批未完成 (需 >=3 审批)")
    if a.is_paid:
        raise HTTPException(400, "已付款")
    time.sleep(0.1)
    a.is_paid = True
    token = "vendor-" + uuid.uuid4().hex
    a.vendor_token = token
    s.add(a)
    s.commit()
    s.refresh(a)
    if _r:
        try:
            _r.set(f"oa:vendor:{id}", token)
        except Exception:
            pass
    return {"vendor_token": token, "flag": FLAG, "amount": a.amount, "paid": True}