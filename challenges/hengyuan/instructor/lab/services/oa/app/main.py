from pathlib import Path

from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles

from .approvals import router
from .models import init_db
from .seed import seed

FRONTEND = Path(__file__).resolve().parent / "frontend"

app = FastAPI(title="恒远集团 OA", docs_url=None, redoc_url=None)
app.include_router(router)


@app.on_event("startup")
def startup():
    init_db()
    seed()


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


app.mount("/assets", StaticFiles(directory=FRONTEND / "assets"), name="assets")
app.mount("/static", StaticFiles(directory=FRONTEND / "static"), name="static")
app.mount("/", StaticFiles(directory=FRONTEND, html=True), name="frontend")