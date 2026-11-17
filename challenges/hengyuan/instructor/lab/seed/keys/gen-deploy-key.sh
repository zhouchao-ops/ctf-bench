#!/bin/sh
# 生成共享 deploy SSH 密钥对 (单一事实源)。
#   id_rsa     -> gitea infra-deploy 历史泄露 + jenkins deploy-ssh-key 凭证
#   id_rsa.pub -> fileserver /home/deploy/.ssh/authorized_keys
# 在首次 build/up 前运行: sh seed/keys/gen-deploy-key.sh
set -e
cd "$(dirname "$0")"
if [ ! -f id_rsa ]; then
  ssh-keygen -t rsa -b 2048 -f id_rsa -N '' -C 'deploy@hengyuan.local'
fi
echo "deploy keypair ready: $(pwd)/id_rsa[.pub]"