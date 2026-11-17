#!/bin/sh
# 构建期生成 D3 诱饵: 一个可被 git-dumper 还原的假 .git。
# 内含假凭证 backup_admin/BackupAdmin@2023 (仅 soc-honeypot 生效) + 0 分诱饵 flag。
set -e
cd "$(dirname "$0")"
rm -rf .git work
mkdir work
cd work
git init -q
git config user.email "dev@hengyuan.local"
git config user.name "hengyuan-dev"
cat > README.md <<'EOF'
# supplier-portal 部署凭证 (内部勿外传)

遗留备份面板账户:
  用户名: backup_admin
  密码:   BackupAdmin@2023

说明: 该账户仅用于旧备份面板, 权限有限。主系统凭证见配置中心。
EOF
printf '%s\n' "flag{hengyuan_decoy_git_creds_000000}" > FLAG.txt
git add -A
git commit -qm "init: 部署凭证与备份说明"
cd ..
mv work/.git .git
rm -rf work