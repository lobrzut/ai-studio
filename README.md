# AI Studio

One project, two platform editions — **Windows** (portable desktop) and **Linux** (Debian server).

Shared dashboard UI and hub API; platform-specific installers and runtimes.

## Quick start

### Windows

From repo root (or after clone):

| File | Action |
|------|--------|
| `Install.bat` | First-time setup (ComfyUI + ACE-Step + Toolkit) |
| `Start.bat` | Tray + dashboard `:7880` |
| `Stop.bat` | Stop stack |
| `Open-Dashboard.bat` | Open `http://127.0.0.1:7880/` |

Implementation lives in `windows/` (ComfyUI, ACE-Step, Toolkit, PowerShell).

### Linux (one command)

On Debian / Ubuntu:

```bash
curl -fsSL https://raw.githubusercontent.com/lobrzut/ai-studio/main/linux/bootstrap.sh | sudo bash
```

Installs to `/opt/ai-studio` by default. Scripts in `linux/`.

## Repository layout

```
ai-studio/
├── Install.bat / Start.bat / …     # Windows entrypoints (wrappers)
├── shared/
│   ├── web/                        # Dashboard (PL/EN), i18n, gallery UI
│   └── hub/                        # Hub API (Python — Linux Docker / optional)
├── windows/                        # Windows portable stack
│   ├── ComfyUI/
│   ├── ACE-Step/
│   └── Toolkit/
├── linux/                          # Linux bootstrap, Docker, systemd
└── docs/
```

## Ports (both editions)

| Port | Service |
|------|---------|
| 7880 | Dashboard hub |
| 7871 | ComfyUI |
| 7870 | ACE-Step |

## Languages

Dashboard and scripts: **Polish** and **English** (PL/EN switcher in UI).

## Docs

- [`docs/PROJECT.md`](docs/PROJECT.md) — Windows vs Linux editions
- [`docs/SECURITY_AUDIT.md`](docs/SECURITY_AUDIT.md) — before publish
- [`linux/README.md`](linux/README.md) — Linux install details

## Legacy repo names

- `ai-studio-portable` → renamed to **`ai-studio`**
- `ai-studio-server` → merged into **`linux/`** (archived on GitHub)

## License

See [LICENSE](LICENSE).
