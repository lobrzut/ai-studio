# AI Studio — project line

## This repository: **Local** edition

| | Local (this repo) | Server (planned) |
|---|-------------------|------------------|
| **Repo** | `lobrzut/ai-studio-portable` | separate repo, TBD |
| **Target** | One Windows PC, portable folder | Remote host / LAN server |
| **Install** | `Install.bat` — embedded Python, ROCm/CUDA profile | Container or system services |
| **Dashboard** | `http://127.0.0.1:7880/` + tray icon | HTTPS, auth, multi-user (TBD) |
| **Data** | Local disks only (`output/`, `Toolkit/Outputs/`) | Shared storage, API (TBD) |
| **Use case** | USB copy, homelab workstation, offline GPU | Team access, always-on inference |

**Edition marker:** `EDITION=local` (see `EDITION` file in repo root).

This repo is the **reference implementation** for workflows (ComfyUI, ACE-Step, Toolkit post-prod). The server edition will reuse concepts and UX patterns from here, not this folder structure as-is.

## Status

- **Local** — active development (PL/EN dashboard, tray stack, portable install).
- **Server** — not started; design after Local stack is stable.

## Naming (working)

- Local: **AI Studio Portable (Local)**
- Server: **AI Studio Server** (working name)
