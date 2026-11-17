#!/usr/bin/env bash
# Path C E2E 验证助手 (攻击侧/管理员)。需靶场已构建并起网 + AD 种子就绪 (M5 验收)。
# 验证: AS-REP/Kerberoast 可 crack / ACL 链 / DA 改密 / DA 读共享 / krbtgt 提取。
# 多数断言经 docker compose exec 在容器内只读验证种子结构 (攻击侧利用见 path-c.md)。
set -uo pipefail
cd "$(dirname "$0")/.."
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }

echo "== C0 AD 用户/OU 种子 =="
docker compose exec -T samba-dc samba-tool user list 2>/dev/null | grep -qE "contractor_li" \
  && ok "contractor_li 存在" || no "contractor_li 缺失"
docker compose exec -T samba-dc samba-tool user list 2>/dev/null | grep -qE "svc_sql|svc_backup|itadmin" \
  && ok "svc_sql/svc_backup/itadmin 存在" || no "服务账户/DA 缺失"

echo "== C1 AS-REP UAC (DONT_REQ_PREAUTH=4194816) =="
docker compose exec -T samba-dc ldbsearch -H /var/lib/samba/private/sam.ldb \
  '(sAMAccountName=contractor_li)' userAccountControl 2>/dev/null | grep -q "4194816" \
  && ok "contractor_li UAC=4194816" || no "UAC 未设 (AS-REP 不可 roast)"

echo "== C2 Kerberoast SPN =="
docker compose exec -T samba-dc samba-tool spn list svc_sql 2>/dev/null | grep -q "MSSQLSvc/sql01" \
  && ok "svc_sql SPN MSSQLSvc/sql01" || no "svc_sql SPN 缺失"

echo "== C3/C4 ACL 链 (GenericWrite / GenericAll) =="
docker compose exec -T samba-dc samba-tool dsacl get \
  --objectdn="CN=svc_backup,OU=ServiceAccounts,DC=hengyuan,DC=local" 2>/dev/null | grep -q "GW" \
  && ok "svc_sql GenericWrite over svc_backup" || no "GenericWrite ACL 缺失"
docker compose exec -T samba-dc samba-tool dsacl get \
  --objectdn="CN=itadmin,OU=IT,DC=hengyuan,DC=local" 2>/dev/null | grep -q "GA" \
  && ok "svc_backup GenericAll over itadmin" || no "GenericAll ACL 缺失"

echo "== C5/C6 DA 共享 + crown 凭证 =="
docker compose exec -T fileserver test -f /srv/shares/DA-Only/flag.txt \
  && ok "DA-Only flag.txt 存在" || no "DA-Only flag 缺失"
docker compose exec -T fileserver test -f /srv/shares/IT-backup/postgres-superuser.yaml \
  && ok "IT-Backup postgres-superuser.yaml 存在" || no "crown 凭证缺失"

echo "== C7 krbtgt 可提取 (黄金票据) =="
docker compose exec -T samba-dc ldbsearch -H /var/lib/samba/private/sam.ldb \
  '(sAMAccountName=krbtgt)' unicodePwd 2>/dev/null | grep -q "unicodePwd" \
  && ok "krbtgt unicodePwd 可读" || no "krbtgt 提取失败"

echo "== 结果: PASS=$pass FAIL=$fail =="
echo "[INFO] 攻击侧利用 (GetNPUsers/GetUserSPNs/targetedKerberoast/net rpc password/ticketer) 见 path-c.md"
[[ $fail -eq 0 ]]