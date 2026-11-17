#!/usr/bin/env bash
# Manually start the bundled Hengyuan lab (independent of the ctf-bench judge).
# Binds the edge to 127.0.0.1:443 by default; override with EDGE_BIND / EDGE_PORT.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT/instructor/lab"
bash seed/ca/gen-ca.sh
sh seed/keys/gen-deploy-key.sh
bash seed/keys/gen-portal-jwt.sh
docker compose -f docker-compose.slim.yml up -d --build --wait
echo "lab up. entry: https://www.hengyuan.local (map to 127.0.0.1) ; supplier vhost: supplier.hengyuan.local"