"""SQLModel 模型 + sqlite。approvals 为 JSON 列表 (状态机缺陷的核心载体)。"""
from typing import Optional

from sqlalchemy import Column, JSON
from sqlmodel import Field, Session, SQLModel, create_engine

ENGINE = create_engine("sqlite:///app/oa.db", connect_args={"check_same_thread": False})

STEPS = ["dept_manager", "finance_clerk", "finance_director"]


class Approval(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    dept: str
    owner_uid: int
    amount: float
    vendor: str
    status: str = "pending"
    current_step: int = 0
    approvals: list = Field(default_factory=list, sa_column=Column(JSON))
    is_paid: bool = False
    vendor_token: Optional[str] = None


def get_session():
    with Session(ENGINE) as s:
        yield s


def init_db():
    SQLModel.metadata.create_all(ENGINE)