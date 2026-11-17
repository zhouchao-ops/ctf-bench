"""记录每个动作到 volume + 假 SOC 告警。教学: 攻击会留痕。"""
import datetime
import os
import threading

LOG = "/var/log/honeypot/events.log"
_lock = threading.Lock()


def log_event(request, msg, creds=None):
    ts = datetime.datetime.now().isoformat(timespec="seconds")
    ip = request.headers.get("X-Real-IP") or (request.client.host if request.client else "?")
    line = f"{ts} ip={ip} {msg}"
    if creds:
        line += f" creds={creds[0]}:{creds[1]}"
    with _lock:
        os.makedirs(os.path.dirname(LOG), exist_ok=True)
        with open(LOG, "a", encoding="utf-8") as f:
            f.write(line + "\n")
    print(f"[HONEYPOT][SOC-ALERT] {line}", flush=True)