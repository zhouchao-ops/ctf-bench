import os

from fastapi import FastAPI, Form, Request
from fastapi.responses import HTMLResponse

from .alerts import log_event

app = FastAPI(title="恒远集团管理后台", docs_url=None, redoc_url=None)

DECOY_ADMIN = os.environ.get("FLAG_DECOY_ADMIN", "flag{hengyuan_decoy_admin_panel_000000}")
GIT_USER = os.environ.get("DECOY_GIT_USER", "backup_admin")
GIT_PW = os.environ.get("DECOY_GIT_PW", "BackupAdmin@2023")
# D1 admin:admin123 + D3 假 .git 凭证 (仅本 honeypot 生效, 真实服务拒绝)
VALID = {"admin": "admin123", GIT_USER: GIT_PW}

LOGIN_HTML = """<!doctype html><html lang="zh"><head><meta charset="utf-8">
<title>恒远集团 · 管理后台</title></head><body>
<h2>恒远集团管理后台</h2>
<form method="post" action="/admin/login">
<input name="username" placeholder="用户名"><br>
<input name="password" type="password" placeholder="密码"><br>
<button type="submit">登录</button></form>
<p style="color:#888">仅限信息技术部授权人员访问。</p></body></html>"""

DASHBOARD_HTML = """<!doctype html><html lang="zh"><head><meta charset="utf-8">
<title>恒远集团 · 管理后台</title></head><body>
<h2>管理控制台</h2><p>欢迎, {user}。</p>
<ul><li>在线用户: 0</li><li>待处理工单: 0</li><li>系统状态: 正常</li></ul>
<p>运维备注: {flag}</p>
<p style="color:#888">数据每日 03:00 同步。</p></body></html>"""


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/admin", response_class=HTMLResponse)
def admin_login(request: Request):
    log_event(request, "GET /admin (登录页)")
    return LOGIN_HTML


@app.post("/admin/login", response_class=HTMLResponse)
def login(request: Request, username: str = Form(...), password: str = Form(...)):
    log_event(request, f"POST /admin/login user={username}", creds=(username, password))
    if VALID.get(username) == password:
        log_event(request, f"成功登录假面板 user={username} [SOC 告警: 诱饵触碰]")
        return DASHBOARD_HTML.format(user=username, flag=DECOY_ADMIN)
    return HTMLResponse("<h3>认证失败</h3>", status_code=401)


@app.get("/admin/dashboard", response_class=HTMLResponse)
def dashboard(request: Request):
    log_event(request, "GET /admin/dashboard (未授权访问假面板)")
    return DASHBOARD_HTML.format(user="guest", flag=DECOY_ADMIN)


@app.get("/admin/api/users")
def fake_users(request: Request):
    log_event(request, "GET /admin/api/users (假数据接口)")
    return {"users": [], "total": 0, "note": "暂无数据"}