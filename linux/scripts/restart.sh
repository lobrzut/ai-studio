#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
"${ROOT}/scripts/stop.sh"
if [[ -f .compose.profile ]]; then
  # shellcheck disable=SC1091
  source .compose.profile
  docker compose --profile "${COMPOSE_PROFILES:-cpu}" up -d
else
  systemctl restart aistudio-hub aistudio-comfy 2>/dev/null || true
fi
echo "Restarted."
