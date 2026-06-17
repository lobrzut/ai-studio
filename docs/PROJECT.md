# AI Studio — Windows & Linux editions

Single monorepo: **shared UI**, **windows/** stack, **linux/** deploy.

## Editions

| | **Windows** | **Linux** |
|---|-------------|-----------|
| **Folder** | `windows/` | `linux/` |
| **Install** | `Install.bat` (root wrapper) | `curl …/linux/bootstrap.sh \| sudo bash` |
| **Runtime** | Portable Python + ROCm/CUDA on host | Docker (NVIDIA/CPU) or native ROCm |
| **Dashboard** | PowerShell hub + tray | Python hub (Docker or systemd) |
| **Data** | Inside repo folder (`windows/logs`, outputs) | `/var/lib/ai-studio` (default) |
| **Use case** | Desktop, USB portable, RX 6800 workstation | Headless server, LAN / VPS |

## Shared

| Path | Contents |
|------|----------|
| `shared/web/` | Dashboard HTML/CSS/JS, i18n (PL/EN) |
| `shared/hub/` | Hub API (Python/FastAPI) — used on Linux; Windows still uses `windows/Toolkit/Dashboard-Server.ps1` |

Edition badge in UI comes from `/api/status` → `hub.edition`: `windows` | `linux`.

## Install paths

**Windows** — clone repo, run from root:

```bat
Install.bat
Start.bat
```

**Linux** — one line:

```bash
curl -fsSL https://raw.githubusercontent.com/lobrzut/ai-studio/main/linux/bootstrap.sh | sudo bash
```

## GitHub

- Canonical repo: **`lobrzut/ai-studio`**
- Sibling repos (separate products): [brain](https://github.com/lobrzut/brain) (`:7860`), [netdash](https://github.com/lobrzut/netdash) (`:18787`) — see [HOMELAB-PROJECTS.md](https://github.com/lobrzut/brain/blob/main/docs/HOMELAB-PROJECTS.md)
- Former `ai-studio-portable` and `ai-studio-server` are consolidated here.

## Roadmap

- [x] Monorepo `shared/` + `windows/` + `linux/`
- [x] One-command Linux bootstrap
- [ ] Windows hub on shared Python (optional)
- [ ] ACE-Step Linux container
- [ ] Toolkit post-prod on Linux workers
- [ ] HTTPS / auth (Caddy)
