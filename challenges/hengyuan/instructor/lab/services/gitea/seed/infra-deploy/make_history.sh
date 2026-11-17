#!/usr/bin/env bash
# Uber 2016 案例复现: 私钥/云凭证提交后又"删除", 但仍可从 git 历史恢复。
# 攻击者: git log --all --full-history -- deploy/id_rsa ; git show <首commit>:deploy/id_rsa
set -euo pipefail
WORK=/tmp/infra-deploy
rm -rf "$WORK"
mkdir -p "$WORK/deploy" "$WORK/config"
cd "$WORK"
git init -q
git checkout -q -b main
git config user.email "ops@hengyuan.local"
git config user.name "hengyuan-ops"

# 首次提交: 含 fileserver deploy 私钥 + 云凭证 + flag
cp /seed/keys/id_rsa deploy/id_rsa
cat > config/aws-credentials <<'EOF'
[default]
aws_access_key_id = AKIAHENGYUANEXAMPLE
aws_secret_access_key = hengyuanExampleSecretKey0123456789
region = cn-north-1
EOF
printf '%s\n' "$FLAG_GITEA_SSHKEY" > deploy/README.flag
git add -A
git commit -qm "init: deploy tooling + keys"

# "删除"敏感文件 (私钥仍留在历史)
git rm -q deploy/id_rsa config/aws-credentials
git commit -qm "chore: remove sensitive files (oops, rotate later)"

# 密码含 @ 等字符须 URL 编码, 否则 git 解析 remote URL 出错 (Bad hostname)
PW_ENC=$(printf '%s' "$GITEA_ADMIN_PW" | sed 's/@/%40/g')
git remote add origin "http://${GITEA_ADMIN_USER}:${PW_ENC}@127.0.0.1:3000/hengyuan/infra-deploy.git"
git push -q -u origin main