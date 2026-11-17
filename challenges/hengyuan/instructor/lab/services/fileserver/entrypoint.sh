#!/bin/bash
# fileserver 入口: DNS->coredns -> 等待 DC -> 加域 -> deploy SSH 公钥 -> DA-Only flag -> 启动 smb/ssh。
set -e
printf 'nameserver 172.30.3.53\nsearch hengyuan.local\n' > /etc/resolv.conf

# 等待 DC LDAP (经 coredns 转发 AD 区)
for i in $(seq 1 90); do
  ldapsearch -x -H ldap://dc01.hengyuan.local -b '' -s base '(objectClass=*)' >/dev/null 2>&1 && break
  sleep 2
done

# 加入域 (幂等)
net ads join -U "administrator%${DC_ADMIN_PW}" >/dev/null 2>&1 || true

# deploy SSH 用户 + 公钥 (对应私钥经 Gitea infra-deploy 历史泄露, Path B 入口)
id deploy >/dev/null 2>&1 || useradd -m -s /bin/bash deploy
mkdir -p /home/deploy/.ssh
cp /seed/keys/id_rsa.pub /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh
chmod 600 /home/deploy/.ssh/authorized_keys

# DA-Only flag (domain-admin 里程碑)
printf '%s\n' "${FLAG_DOMAIN_ADMIN}" > /srv/shares/DA-Only/flag.txt

# 文件系统权限放宽, 访问控制交给 SMB valid users (DA-Only/IT-Backup 仅 Domain Admins)
chmod 777 /srv/shares/finance-docs /srv/shares/public /srv/shares/DA-Only

# 启动服务
mkdir -p /var/run/samba /var/log/samba /run/sshd
winbindd
smbd
nmbd
/usr/sbin/sshd

# 前台守护
tail -f /var/log/samba/log.smbd 2>/dev/null || sleep infinity