#!/usr/bin/env bash
set -euo pipefail
LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$LINUX_DIR/.." && pwd)"
DATA_DIR="${AI_STUDIO_DATA:-/var/lib/ai-studio}"

install_unit() {
  local name="$1"
  sed "s|@REPO_ROOT@|${REPO_ROOT}|g; s|@DATA_DIR@|${DATA_DIR}|g; s|@LINUX_DIR@|${LINUX_DIR}|g" \
    "${LINUX_DIR}/systemd/${name}.service.in" >"/etc/systemd/system/${name}.service"
}

echo "==> Installing systemd units..."
install_unit aistudio-hub
install_unit aistudio-comfy
systemctl daemon-reload
systemctl enable aistudio-hub aistudio-comfy
systemctl restart aistudio-hub aistudio-comfy || true
