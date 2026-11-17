#!/usr/bin/env python3
"""ctf-bench service wrapper for the Hengyuan network-range challenge.

Judge invokes:  python3 instructor/server.py --host <bind> --port <port|0>
We bring up the bundled Docker-Compose lab locally (never touches any remote
host), bind the nginx edge to <bind>:<port>, then print ``LISTENING <port>``.
On SIGTERM/SIGINT we tear the lab down. All logs go to stderr; stdout carries
only the ready line the judge parses.
"""
import argparse
import os
import signal
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent          # challenges/hengyuan
LAB = ROOT / "instructor" / "lab"
COMPOSE = ["docker", "compose", "-f", "docker-compose.slim.yml"]


def log(msg):
    print(msg, file=sys.stderr, flush=True)


def run(cmd, **kw):
    return subprocess.run(cmd, cwd=str(LAB), **kw)


def pick_port():
    s = socket.socket()
    s.bind(("0.0.0.0", 0))
    p = s.getsockname()[1]
    s.close()
    return p


def gen_prereqs():
    for script, shell in (("seed/ca/gen-ca.sh", "bash"),
                          ("seed/keys/gen-deploy-key.sh", "sh"),
                          ("seed/keys/gen-portal-jwt.sh", "bash")):
        r = run([shell, script], capture_output=True, text=True)
        if r.returncode != 0:
            log(f"prereq {script} failed:\n{r.stderr}")
            sys.exit(1)


def edge_ok():
    # Plain-HTTP probe inside the edge container; avoids TLS entirely (lab cert is self-signed).
    r = run(COMPOSE + ["exec", "-T", "nginx-edge", "wget", "-qO-", "http://127.0.0.1/healthz"],
            capture_output=True, text=True)
    return r.returncode == 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--port", type=int, default=0)
    args = ap.parse_args()
    host = args.host
    port = args.port or pick_port()

    if not LAB.is_dir():
        log(f"bundled lab missing: {LAB}")
        sys.exit(1)

    gen_prereqs()

    env = dict(os.environ, EDGE_BIND=host, EDGE_PORT=str(port))
    log(f"bringing up lab edge at {host}:{port} ...")
    up = subprocess.run(COMPOSE + ["up", "-d", "--build", "--wait"],
                        cwd=str(LAB), env=env, capture_output=True, text=True)
    if up.returncode != 0:
        log(up.stdout[-2000:] + up.stderr[-2000:])
        sys.exit(1)

    for _ in range(60):
        if edge_ok():
            break
        time.sleep(1)
    else:
        log("edge did not become ready")
        run(COMPOSE + ["down", "-v"], capture_output=True)
        sys.exit(1)

    stop = threading.Event()

    def teardown(*_):
        stop.set()

    signal.signal(signal.SIGTERM, teardown)
    signal.signal(signal.SIGINT, teardown)

    print(f"LISTENING {port}", flush=True)
    stop.wait()
    log("tearing down lab ...")
    run(COMPOSE + ["down", "-v", "--remove-orphans"], capture_output=True)


if __name__ == "__main__":
    main()