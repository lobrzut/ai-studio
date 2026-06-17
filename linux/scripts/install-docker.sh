#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODE="${1:-cpu}"
DATA_DIR="${AI_STUDIO_DATA:-/var/lib/ai-studio}"

log() { echo "==> $*"; }

install_docker() {
  if command -v docker >/dev/null 2>&1; then
    log "Docker already installed: $(docker --version)"
    return
  fi
  log "Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  systemctl enable --now docker
}

install_nvidia_toolkit() {
  if docker info 2>/dev/null | grep -qi nvidia; then
    return
  fi
  log "Installing NVIDIA Container Toolkit..."
  apt-get install -y -qq curl
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
  curl -fsSL https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    > /etc/apt/sources.list.d/nvidia-container-toolkit.list
  apt-get update -qq
  apt-get install -y -qq nvidia-container-toolkit
  nvidia-ctk runtime configure --runtime=docker
  systemctl restart docker
}

write_compose_override() {
  local profile="$1"
  mkdir -p "${DATA_DIR}/config"
  case "$profile" in
    nvidia)
      cat >"${ROOT}/.compose.profile" <<'EOF'
COMPOSE_PROFILES=nvidia
EOF
      ;;
    *)
      cat >"${ROOT}/.compose.profile" <<'EOF'
COMPOSE_PROFILES=cpu
EOF
      ;;
  esac
}

install_docker
case "$MODE" in
  nvidia) install_nvidia_toolkit; write_compose_override nvidia ;;
  *)      write_compose_override cpu ;;
esac

log "Docker ready (mode: $MODE)"
