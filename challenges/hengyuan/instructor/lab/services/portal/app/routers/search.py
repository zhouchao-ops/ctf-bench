"""D2 诱饵: /api/search 看似 SQLi (返回假 MySQL 错误字符串), 实则无真实 DB 查询 (参数化/无注入)。
sqlmap 无果; tarpit 延时 + 告警。教 '验证优于假设'。"""
import time

from fastapi import APIRouter

router = APIRouter(prefix="/api")


@router.get("/search")
def search(q: str = ""):
    time.sleep(0.3)
    if any(c in q for c in ["'", '"', ";", "--", "/*", "*/"]):
        print(f"[ALERT][D2] 疑似 SQLi 探测 q={q!r} (参数化, 无实际注入)", flush=True)
        return {
            "error": "You have an error in your SQL syntax; check the manual that corresponds to your "
                     "MySQL server version for the right syntax to use near '" + q + "' at line 1",
            "results": [],
        }
    return {"q": q, "results": [{"title": "恒远集团简介", "snippet": "制造/零售 conglomerate。"}]}