#!/usr/bin/env bash
# 生成 portal JWT RSA 密钥对 (单一事实源), 分发公钥到 portal 与 nginx 静态目录。
#   app/keys/private.pem  -> portal RS256 签发
#   app/keys/public.pem   -> portal RS256 验签 (kid 默认 public.pem)
#   app/static/public.pem -> kid 穿越攻击目标 (../../../../app/static/public.pem)
#   nginx html/static/public.pem -> 攻击者公开下载 (/static/public.pem, nginx alias)
# 首次构建前运行: bash seed/keys/gen-portal-jwt.sh  (--force 重新生成)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
KEYS="$ROOT/services/portal/app/keys"
PSTATIC="$ROOT/services/portal/app/static"
NSTATIC="$ROOT/services/nginx-edge/html/static"
FORCE="${1:-}"

mkdir -p "$KEYS" "$PSTATIC" "$NSTATIC"
if [[ -f "$KEYS/private.pem" && "$FORCE" != "--force" ]]; then
  echo "[gen-portal-jwt] private.pem 已存在, 跳过 (--force 重新生成)"
else
  openssl genrsa -out "$KEYS/private.pem" 2048 2>/dev/null
  openssl rsa -in "$KEYS/private.pem" -pubout -out "$KEYS/public.pem" 2>/dev/null
fi
cp -f "$KEYS/public.pem" "$PSTATIC/public.pem"
cp -f "$KEYS/public.pem" "$NSTATIC/public.pem"
echo "[gen-portal-jwt] 公钥已分发: portal app/static + nginx html/static (内容一致)"