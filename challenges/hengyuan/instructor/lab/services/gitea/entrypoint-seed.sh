#!/usr/bin/env bash
# Gitea 种子入口: 启动 web -> 创建管理员/org/repos -> 推送 infra-deploy Uber 式历史。
set -euo pipefail
export GITEA_WORK_DIR=/data
CFG=/etc/gitea/app.ini
API=http://127.0.0.1:3000/api/v1

# 1) 启动 gitea web (后台, 内置 SSH server)
gitea web --config "$CFG" &
GITEA_PID=$!

# 2) 等待就绪
for i in $(seq 1 60); do
  curl -fsS http://127.0.0.1:3000/api/healthz >/dev/null 2>&1 && break
  sleep 2
done

# 3) 创建管理员 (幂等)
gitea admin user create --config "$CFG" \
  --username "$GITEA_ADMIN_USER" --password "$GITEA_ADMIN_PW" \
  --email admin@hengyuan.local --admin --must-change-password=false || true

AUTH=(-u "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PW}")

# 4) 创建私有 org + repos
curl -fsS "${AUTH[@]}" -X POST "$API/orgs" \
  -H 'Content-Type: application/json' \
  -d '{"username":"hengyuan","visibility":"private"}' || true
for repo in supplier-portal oa-service hr-docs infra-deploy; do
  curl -fsS "${AUTH[@]}" -X POST "$API/orgs/hengyuan/repos" \
    -H 'Content-Type: application/json' \
    -d "{\"name\":\"$repo\",\"private\":true,\"auto_init\":false}" || true
done

# 5) 推送 infra-deploy 历史 (提交私钥 -> "删除" commit, 私钥仍在历史中)
bash /seed/infra-deploy/make_history.sh

# 6) 前台守护
wait "$GITEA_PID"