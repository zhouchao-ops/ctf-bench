#!/usr/bin/env bash
# 诱饵行为验证助手 (D1-D6)。需靶场已构建并起网 + 应用源码就绪 (M2/M4/M6 验收)。
# 断言诱饵计 0 分 + 蓝队告警叙事 + "验证优于假设"。
set -uo pipefail
cd "$(dirname "$0")/.."
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
WWW="--resolve www.hengyuan.local:443:127.0.0.1"
SUP="--resolve supplier.hengyuan.local:443:127.0.0.1"

echo "== D1 portal /admin -> honeypot =="
curl -sk $WWW https://www.hengyuan.local/admin 2>/dev/null | grep -qi "honeypot\|admin" \
  && ok "/admin 路由到假面板" || no "/admin 未路由"
echo "  [INFO] 构建期验收: admin:admin123 登录后数据为空/假; honeypot_logs volume 有记录; flag 计 0 分"

echo "== D2 /api/search SQLi tarpit (参数化) =="
curl -sk $WWW "https://www.hengyuan.local/api/search?q=test'%20OR%201=1--" 2>/dev/null | grep -qi "mysql\|error" \
  && ok "返回假 MySQL 错误字符串" || no "tarpit 未返回假错误"
echo "  [INFO] 构建期验收: sqlmap 无果 (参数化); 限流+告警"

echo "== D3 supplier /.git 假凭证 =="
curl -sk $SUP https://supplier.hengyuan.local/.git/HEAD 2>/dev/null | grep -q "ref:" \
  && ok "/.git 可 dump" || no "/.git 不可访问"
echo "  [INFO] 构建期验收: backup_admin/BackupAdmin@2023 仅 honeypot 生效, 真实服务拒绝"

echo "== D4 /server-status 谎报版本但 S2-045 仍触发 =="
curl -sk $SUP https://supplier.hengyuan.local/server-status 2>/dev/null | grep -qi "2.5.30\|patched" \
  && ok "假 banner 'Struts 2.5.30 patched'" || no "假 banner 缺失"
echo "  [INFO] 构建期验收: 真实 2.3.31, S2-045 PoC 仍回显 id (banner 不可信)"

echo "== D5 web 根 /flag.txt 假 flag =="
curl -sk $WWW https://www.hengyuan.local/flag.txt 2>/dev/null | grep -q "decoy_webroot" \
  && ok "/flag.txt 假 flag" || no "/flag.txt 缺失"

echo "== D6 Jenkins backup-dc 沙箱 job =="
echo "  [INFO] 构建期验收: 匿名可见 backup-dc job 但沙箱化, 无真实凭证, 假 flag (0 分)"

echo "== 诱饵 flag 计分 (应全 0) =="
python3 verify.py \
  'flag{hengyuan_decoy_admin_panel_000000}' \
  'flag{hengyuan_decoy_git_creds_000000}' \
  'flag{hengyuan_decoy_webroot_000000}' \
  'flag{hengyuan_decoy_sqli_tarpit_000000}' \
  'flag{hengyuan_decoy_backup_dc_000000}' 2>/dev/null | grep -q "总分: 0" \
  && ok "5 诱饵 flag 计 0 分" || no "诱饵计分异常"

echo "== 结果: PASS=$pass FAIL=$fail =="
[[ $fail -eq 0 ]]