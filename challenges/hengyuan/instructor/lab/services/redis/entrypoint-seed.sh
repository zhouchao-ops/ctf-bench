#!/bin/sh
# redis 启动 + 幂等种子 loot (未授权访问可读)。
set -e
CONF=/usr/local/etc/redis/redis.conf
redis-server "$CONF" &
RPID=$!

for i in $(seq 1 30); do
  redis-cli ping >/dev/null 2>&1 && break
  sleep 1
done

# gitea 管理员凭证 (运维误存于缓存, 未授权可读 -> slim 中替代 Jenkins 解密来源)
redis-cli SET deploy:gitea "${GITEA_ADMIN_USER}:${GITEA_ADMIN_PW}" >/dev/null
redis-cli SET notes:deploy "gitea 管理员凭证见 deploy:gitea; infra-deploy 仓库含部署密钥提交历史" >/dev/null
redis-cli SET oa:hint "财务审批 /pay 门控仅校验审批数量, 留意 withdraw/resubmit 状态机" >/dev/null

wait "$RPID"