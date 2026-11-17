"""种子审批单 (财务部, 顺序 ID, 3 步审批门控)。重启重种子 -> 确定性。"""
from sqlmodel import Session, select

from .models import ENGINE, Approval

SEED_ROWS = [
    {"dept": "财务部", "owner_uid": 1001, "amount": 12800.00, "vendor": "恒远云部署服务"},
    {"dept": "财务部", "owner_uid": 1001, "amount": 3600.50, "vendor": "办公用品采购"},
    {"dept": "财务部", "owner_uid": 1001, "amount": 45900.00, "vendor": "服务器配件采购"},
    {"dept": "采购部", "owner_uid": 1003, "amount": 8200.00, "vendor": "差旅服务"},
]


def seed():
    with Session(ENGINE) as s:
        if s.exec(select(Approval)).first():
            return
        for row in SEED_ROWS:
            s.add(Approval(**row, status="pending", current_step=0, approvals=[], is_paid=False))
        s.commit()