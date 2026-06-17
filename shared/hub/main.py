"""AI Studio Server hub — Linux port of Toolkit/Dashboard-Server.ps1 (MVP)."""
from __future__ import annotations

import os
import socket
from pathlib import Path

import httpx
from fastapi import FastAPI, Query
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles

DATA_DIR = Path(os.environ.get("DATA_DIR", "/data"))
WEB_DIR = Path(os.environ.get("WEB_DIR", "/app/web"))
COMFY_URL = os.environ.get("COMFY_URL", "http://127.0.0.1:7871").rstrip("/")
ACE_URL = os.environ.get("ACE_URL", "http://127.0.0.1:7870").rstrip("/")
HUB_API_VERSION = 1
LOCALE_FILE = DATA_DIR / "config" / "locale.env"

app = FastAPI(title="AI Studio Server Hub")


def port_open(host: str, port: int, timeout: float = 1.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def parse_host_port(base_url: str) -> tuple[str, int]:
    from urllib.parse import urlparse

    u = urlparse(base_url)
    host = u.hostname or "127.0.0.1"
    port = u.port or (443 if u.scheme == "https" else 80)
    return host, port


def service_state(base_url: str) -> dict:
    host, port = parse_host_port(base_url)
    online = port_open(host, port)
    return {
        "online": online,
        "state": "online" if online else "offline",
        "url": f"{base_url}/",
        "port": port,
    }


def get_locale() -> str:
    if LOCALE_FILE.is_file():
        line = LOCALE_FILE.read_text(encoding="utf-8").strip()
        if "en" in line:
            return "en"
    return "pl"


def set_locale(lang: str) -> None:
    LOCALE_FILE.parent.mkdir(parents=True, exist_ok=True)
    LOCALE_FILE.write_text(f"LANG={lang}\n", encoding="utf-8")


@app.get("/api/status")
async def api_status():
    ace = service_state(ACE_URL)
    comfy = service_state(COMFY_URL)
    return {
        "ace": ace,
        "comfy": comfy,
        "hub": {
            "online": True,
            "state": "online",
            "port": 7880,
            "url": "http://127.0.0.1:7880/",
            "api_version": HUB_API_VERSION,
            "upload": False,
            "locale": get_locale(),
            "features": ["i18n", "linux"],
            "edition": "linux",
        },
        "gpu": {"available": False, "name": "GPU", "error": "not implemented on server MVP"},
        "comfy_outputs": {"items": []},
    }


@app.get("/api/locale")
async def api_locale_get():
    return {"ok": True, "locale": get_locale()}


@app.post("/api/locale")
async def api_locale_set(lang: str = Query(..., alias="lang")):
    if lang not in ("pl", "en"):
        return JSONResponse({"ok": False, "error": "lang must be pl or en"}, status_code=400)
    set_locale(lang)
    return {"ok": True, "locale": lang}


@app.get("/api/action")
async def api_action(name: str = Query(...)):
    actions = {
        "open_ace": f"Open {ACE_URL}",
        "open_comfy": f"Open {COMFY_URL}",
        "start_stack": "Use: ./scripts/restart.sh on the server host",
        "stop_stack": "Use: ./scripts/stop.sh on the server host",
    }
    if name in ("open_ace", "open_comfy"):
        return {"ok": True, "message": actions[name], "action": name}
    if name in actions:
        return {"ok": True, "message": actions[name], "action": name}
    return JSONResponse({"ok": False, "error": f"Unknown action: {name}"}, status_code=400)


@app.get("/health")
async def health():
    return {"ok": True, "edition": "linux"}


if WEB_DIR.is_dir():
    app.mount("/", StaticFiles(directory=str(WEB_DIR), html=True), name="web")
