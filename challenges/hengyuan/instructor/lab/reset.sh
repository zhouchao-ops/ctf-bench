#!/usr/bin/env bash
# 恒远靶场一键起网 / 确定性重置。
#   bash reset.sh                 生成前置(证书/密钥) -> down -v -> up --build --wait
#   bash reset.sh --verify-seed   断言关键 flag/凭证存在且稳定 (需容器已起)
# 重置确定性: AD provision 烘焙构建期(固定 SID/krbtgt); postgres init 空卷运行;
#             Gitea/Jenkins/Nacos/OA 入口幂等重种子; down -v 清空所有 named volume。
set -euo pipefail
cd "$(dirname "$0")"
MODE="${1:-}"

# ---- 前置: 证书 + deploy 密钥 + portal JWT 密钥 (幂等) ----
bash seed/ca/gen-ca.sh
sh seed/keys/gen-deploy-key.sh
bash seed/keys/gen-portal-jwt.sh

if [[ "$MODE" == "--verify-seed" ]]; then
  echo "[verify-seed] 断言关键种子 (只读)..."
  fail=0
  # postgres crown jewels (superuser-only)
  if docker compose exec -T postgres \
      psql -U "${PG_SUPER_USER:-postgres}" -d "${PG_DB:-hengyuan}" -tAc \
      "SELECT count(*) FROM crown_jewels;" 2>/dev/null | grep -qE '^[1-9]'; then
    echo "  [OK] postgres crown_jewels 已种子"
  else
    echo "  [FAIL] postgres crown_jewels 缺失"; fail=1
  fi
  # AD 用户
  if docker compose exec -T samba-dc samba-tool user list 2>/dev/null | grep -q svc_backup; then
    echo "  [OK] AD svc_backup 存在"
  else
    echo "  [FAIL] AD svc_backup 缺失"; fail=1
  fi
  # fileserver IT-Backup  loot (来自 dc_backup 卷)
  if docker compose exec -T fileserver test -f /srv/shares/IT-backup/dc-sam.ldb.bak; then
    echo "  [OK] IT-Backup dc-sam.ldb.bak 存在 (krbtgt/黄金票据路径)"
  else
    echo "  [FAIL] IT-Backup dc-sam.ldb.bak 缺失"; fail=1
  fi
  if docker compose exec -T fileserver test -f /srv/shares/IT-backup/postgres-superuser.yaml; then
    echo "  [OK] IT-Backup postgres-superuser.yaml 存在 (crown 凭证)"
  else
    echo "  [FAIL] IT-Backup postgres-superuser.yaml 缺失"; fail=1
  fi
  [[ "$fail" == 0 ]] && echo "[verify-seed] 全部通过" || { echo "[verify-seed] 有失败项"; exit 1; }
  exit 0
fi

# ---- 确定性重置 ----
echo "[reset] 停止并清空 volumes..."
docker compose down -v --remove-orphans
echo "[reset] 构建并启动 (等待 healthy)..."
docker compose up -d --build --wait
echo "[reset] 完成。入口: https://www.hengyuan.local / https://supplier.hengyuan.local"
echo "[reset] 需将 www/supplier.hengyuan.local 指向 127.0.0.1 (/etc/hosts 或 curl --resolve)。"
echo "[reset] 校验种子: bash reset.sh --verify-seed"