#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
if docker compose ps 2>/dev/null | grep -q Up; then
  docker compose ps
else
  systemctl status aistudio-hub aistudio-comfy --no-pager 2>/dev/null || true
fi
curl -fsS http://127.0.0.1:7880/api/status 2>/dev/null | jq . || echo "Hub :7880 not responding"
