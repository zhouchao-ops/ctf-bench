"""JWT 签发/校验。
漏洞: kid 未规范化 (os.path.join 直接拼) + 同时接受 HS256/RS256。
攻击: 下载公开公钥 /static/public.pem, 伪造 HS256 token, kid 穿越到公钥文件,
      用公钥内容作 HMAC secret -> 绕过 RS256 验签, 伪造 admin。
"""
import os
import time
from pathlib import Path

import jwt

KEYS = Path(__file__).resolve().parent / "keys"
PRIV = (KEYS / "private.pem").read_text(encoding="utf-8")
PUB = (KEYS / "public.pem").read_text(encoding="utf-8")


def issue_token(uid, username, role="user"):
    now = int(time.time())
    payload = {"sub": str(uid), "username": username, "role": role, "iat": now, "exp": now + 3600}
    return jwt.encode(payload, PRIV, algorithm="RS256", headers={"kid": "public.pem"})


def decode_token(token):
    header = jwt.get_unverified_header(token)
    kid = header.get("kid", "public.pem")
    key = open(os.path.join(str(KEYS), kid), encoding="utf-8").read()
    return jwt.decode(token, key, algorithms=["HS256", "RS256"], options={"verify_aud": False})