#!/usr/bin/env bash
# Native install path for AMD ROCm (ComfyUI + ACE-Step on host, hub in venv)
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA_DIR="${AI_STUDIO_DATA:-/var/lib/ai-studio}"
VENV="${DATA_DIR}/venv"

log() { echo "==> $*"; }

install_rocm_hint() {
  if ! command -v rocm-smi >/dev/null 2>&1; then
    cat <<'EOF' >&2
!! ROCm not detected. On Debian/Ubuntu install ROCm first, then re-run bootstrap.
   https://rocm.docs.amd.com/projects/install-on-linux/en/latest/
   Or force CPU/docker:  ... | sudo bash -s -- --profile cpu
EOF
    exit 1
  fi
}

install_comfy_native() {
  local comfy="${DATA_DIR}/comfyui"
  if [[ -f "${comfy}/.installed" ]]; then
    log "ComfyUI native already installed"
    return
  fi
  log "Installing ComfyUI (native)..."
  mkdir -p "$comfy"
  if [[ ! -d "${comfy}/ComfyUI/.git" ]]; then
    git clone --depth 1 https://github.com/comfyanonymous/ComfyUI.git "${comfy}/ComfyUI"
  fi
  python3 -m venv "$VENV"
  # shellcheck disable=SC1091
  source "${VENV}/bin/activate"
  pip install -q --upgrade pip wheel
  pip install -q torch torchvision torchaudio --index-url https://download.pytorch.org/whl/rocm6.2
  pip install -q -r "${comfy}/ComfyUI/requirements.txt"
  touch "${comfy}/.installed"
}

install_rocm_hint
install_comfy_native
log "Native ROCm base ready — enable systemd units with: ./scripts/up-native.sh"
