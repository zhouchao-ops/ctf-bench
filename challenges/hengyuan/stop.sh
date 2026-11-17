#!/usr/bin/env bash
# Stop and reset the bundled Hengyuan lab started by start.sh.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT/instructor/lab"
docker compose -f docker-compose.slim.yml down -v --remove-orphans
echo "lab down (volumes removed)."