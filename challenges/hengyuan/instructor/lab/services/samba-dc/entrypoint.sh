#!/bin/bash
# Samba AD DC 入口: 启动 samba(含内部 DNS) -> 等待 LDAP -> 幂等种子 -> 导出 DC 备份到共享卷。
set -e

# 系统 krb5 指向自身 provision 生成的配置
cp -f /var/lib/samba/private/krb5.conf /etc/krb5.conf 2>/dev/null || true
# 自身 DNS 解析 AD 区
printf 'nameserver 127.0.0.1\nsearch hengyuan.local\n' > /etc/resolv.conf

# 启动 samba AD DC (前台 daemon 模型, 后台运行以便种子)
samba --foreground --no-process-group &
SAMBA_PID=$!

# 等待 LDAP 就绪
for i in $(seq 1 90); do
  if ldapsearch -x -H ldap://127.0.0.1 -b '' -s base '(objectClass=*)' >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# 幂等种子 (用户/UAC/SPN/ACL/flag)
bash /seed/seed.sh

# 导出 DC 系统状态备份到共享卷 (落到 fileserver IT-Backup$ 共享)。
# 这是 Samba 原生的 krbtgt/黄金票据可靠路径 (无需 DC shell / 无 SeBackupPrivilege)。
mkdir -p /backup
cp -f /var/lib/samba/private/sam.ldb /backup/dc-sam.ldb.bak
cat > /backup/postgres-superuser.yaml <<EOF
# crown jewels 数据库超级用户 (仅 Domain Admins 可经 IT-Backup$ 读取)
postgres:
  host: 172.30.5.20
  port: 5432
  database: ${PG_DB}
  superuser: ${PG_SUPER_USER}
  password: ${PG_SUPER_PW}
EOF
cat > /backup/svc_backup-creds.txt <<EOF
服务账户备份 (Path B -> Path C 链接)
用户名: ${AD_SVC_BACKUP_USER}
密码:   ${AD_SVC_BACKUP_PW}
EOF

# 前台守护
wait "${SAMBA_PID}"