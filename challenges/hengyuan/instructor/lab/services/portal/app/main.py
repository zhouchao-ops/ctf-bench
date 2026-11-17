from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from .auth import KEYS
from .routers import auth, reset, search, users

FRONTEND = Path(__file__).resolve().parent / "frontend"

app = FastAPI(title="恒远集团门户", docs_url=None, redoc_url=None)
app.include_router(users.router)
app.include_router(reset.router)
app.include_router(search.router)
app.include_router(auth.router)


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/static/public.pem")
def public_pem():
    return FileResponse(KEYS / "public.pem", media_type="application/x-pem-file")


app.mount("/assets", StaticFiles(directory=FRONTEND / "assets"), name="assets")
app.mount("/static", StaticFiles(directory=FRONTEND / "static"), name="static")
app.mount("/", StaticFiles(directory=FRONTEND, html=True), name="frontend")