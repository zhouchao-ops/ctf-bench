#!/usr/bin/env bash
# Nacos 配置中心种子入口。
# 弱默认值 (NACOS_AUTH_TOKEN / serverIdentity) 由 compose env 注入, 复现 QVD-2023-6271。
# 本脚本仅负责启动后导入配置 loot (dataId), 凭证来自 compose 环境变量 (单一事实源)。
set -euo pipefail
cd /home/nacos

# 1) 生成配置 loot
mkdir -p /home/nacos/seed-configs
cat > /home/nacos/seed-configs/postgres-prod.yaml <<EOF
spring:
  datasource:
    url: jdbc:postgresql://172.30.5.20:5432/${PG_DB}
    username: ${PG_APP_USER}
    password: ${PG_APP_PW}
    driver-class-name: org.postgresql.Driver
EOF
cat > /home/nacos/seed-configs/oa-admin.properties <<EOF
oa.admin.user=oa_admin
oa.admin.secret=OaAdminSecret@2023
oa.jwt.secret=hengyuan-oa-jwt-secret-2023
oa.url=http://172.30.3.31:8000
EOF
cat > /home/nacos/seed-configs/jenkins-deploy.yaml <<EOF
jenkins:
  url: http://172.30.3.40:8080
  vendor_user: ${JENKINS_VENDOR_USER}
  vendor_password: ${JENKINS_VENDOR_PW}
  deploy_target: fileserver (172.30.3.50, ssh deploy)
  gitea: http://172.30.4.20:3000/hengyuan
EOF
cat > /home/nacos/seed-configs/redis.conf <<EOF
redis.host=172.30.3.32
redis.port=6379
redis.auth=none
EOF
cat > /home/nacos/seed-configs/flag-nacos.yaml <<EOF
# 配置中心沦陷证明
flag: ${FLAG_NACOS_CONFIG}
EOF

# 2) 启动官方 nacos (后台)
bin/docker-startup.sh &
NACOS_PID=$!

# 3) 等待就绪
for i in $(seq 1 90); do
  if curl -fsS http://127.0.0.1:8848/nacos/v1/console/health/readiness >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# 4) 默认 nacos/nacos 登录拿 accessToken
TOKEN="$(curl -fsS -X POST 'http://127.0.0.1:8848/nacos/v1/auth/login' \
  -d 'username=nacos&password=nacos' | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')"

# 5) 导入配置 loot
if [ -n "${TOKEN}" ]; then
  for f in /home/nacos/seed-configs/*; do
    dataId="$(basename "$f")"
    curl -fsS -X POST 'http://127.0.0.1:8848/nacos/v1/cs/configs' \
      --data-urlencode "dataId=${dataId}" \
      --data-urlencode 'group=DEFAULT_GROUP' \
      --data-urlencode "content@${f}" \
      --data-urlencode "accessToken=${TOKEN}" >/dev/null 2>&1 || true
  done
fi

# 6) 前台守护 nacos 进程
wait "${NACOS_PID}"