#!/usr/bin/env bash
set -euo pipefail
LINUX_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$LINUX_DIR/.." && pwd)"
DATA_DIR="${AI_STUDIO_DATA:-/var/lib/ai-studio}"
VENV="${DATA_DIR}/venv/hub"

log() { echo "==> $*"; }

if [[ ! -d "$VENV" ]]; then
  python3 -m venv "$VENV"
fi
# shellcheck disable=SC1091
source "${VENV}/bin/activate"
pip install -q --upgrade pip
pip install -q -r "${REPO_ROOT}/shared/hub/requirements.txt"

if [[ -f "${LINUX_DIR}/.compose.profile" ]] || command -v docker >/dev/null 2>&1; then
  if docker compose -f "${LINUX_DIR}/docker-compose.yml" ps hub 2>/dev/null | grep -q Up; then
    log "Hub runs in Docker — skip venv service"
    exit 0
  fi
fi

log "Hub venv ready at $VENV"
log "Run: ${VENV}/bin/uvicorn hub.main:app --host 0.0.0.0 --port 7880"
