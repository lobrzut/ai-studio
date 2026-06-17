#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${AI_STUDIO_DATA:-/var/lib/ai-studio}"
cd "$ROOT"

if [[ -f .compose.profile ]]; then
  # shellcheck disable=SC1091
  source .compose.profile
fi

export AI_STUDIO_DATA="$DATA_DIR"

echo "==> Starting Docker stack..."
docker compose build hub
docker compose --profile "${COMPOSE_PROFILES:-cpu}" up -d

echo "==> Waiting for hub :7880..."
for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:7880/api/status" >/dev/null 2>&1; then
    echo "OK: hub online"
    exit 0
  fi
  sleep 2
done
echo "WARN: hub not responding yet — check: docker compose logs hub"
