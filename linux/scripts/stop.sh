#!/usr/bin/env bash
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
docker compose down 2>/dev/null || true
systemctl stop aistudio-hub aistudio-comfy 2>/dev/null || true
echo "Stopped."
