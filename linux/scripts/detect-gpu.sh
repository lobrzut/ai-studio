#!/usr/bin/env bash
# Source this file — sets DETECTED_PROFILE: docker-nvidia | native-rocm | cpu

warn() { echo "!! $*" >&2; }

detect_gpu_profile() {
  DETECTED_PROFILE=cpu

  if command -v nvidia-smi >/dev/null 2>&1; then
    if nvidia-smi -L >/dev/null 2>&1; then
      DETECTED_PROFILE=docker-nvidia
      return
    fi
  fi

  if [[ -d /opt/rocm ]] || command -v rocm-smi >/dev/null 2>&1; then
    DETECTED_PROFILE=native-rocm
    return
  fi

  if lspci 2>/dev/null | grep -qiE 'vga|3d.*nvidia'; then
    warn "NVIDIA GPU detected but nvidia-smi missing — install driver, then re-run bootstrap."
  fi

  if lspci 2>/dev/null | grep -qiE 'vga|3d.*amd|ati'; then
    warn "AMD GPU detected but ROCm not found — install ROCm for native-rocm, or use CPU profile:"
    warn "  curl ... | sudo bash -s -- --profile cpu"
  fi
}
