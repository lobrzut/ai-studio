# AI Studio Portable (Local)

> **Edition: Local** — Windows, single-folder, runs on `127.0.0.1`.  
> A separate **server** edition is planned (new repo); this project stays the portable desktop reference.

Portable local AI studio for image/video workflows and music generation:
- `ComfyUI` for visual workflows (image/video)
- `ACE-Step` for music generation
- `Toolkit` dashboard and audio post-production utilities

This project is designed to run **locally on Windows** from a single folder (no cloud dependency).

See [`docs/PROJECT.md`](docs/PROJECT.md) for Local vs planned Server edition.
## Quick Start

| File | What it does |
|------|---------------|
| `Install.bat` | First-time setup (GPU profile, Python runtime, dependencies, optional Enhance AI) |
| `Start.bat` | Starts dashboard tray/hub and local services |
| `Stop.bat` | Stops running services |
| `Restart.bat` | Full stop + start cycle |
| `Open-Dashboard.bat` | Opens dashboard hub at `http://127.0.0.1:7880/` |

## Main Components

```
AIStudio-Portable/
├── Install.bat / Start.bat / Stop.bat
├── ComfyUI/      ComfyUI runtime and custom nodes
├── ACE-Step/     ACE-Step runtime and app
├── Toolkit/      Dashboard UI + helper scripts
├── logs/         Runtime logs (local only)
└── Audit.ps1     Local health/audit script
```

## Typical Workflow

1. Run `Install.bat` (first machine setup only).
2. Run `Start.bat`.
3. Open `http://127.0.0.1:7880/`.
4. Launch ComfyUI / ACE-Step from the dashboard.

## Ports

- `7870` — ACE-Step
- `7871` — ComfyUI
- `7880` — Dashboard hub

## Languages (PL / EN)

The dashboard, tray menu, and main stack scripts (`Install.ps1`, `Start.ps1`, `Stop.ps1`) support **Polish** and **English**.

- Switch language in the dashboard header (**PL** / **EN** buttons).
- Or use **Language** entries in the tray context menu.
- Preference is stored in `Toolkit/locale.env` (local, not committed).

## Dashboard Preview

### Home

![Dashboard Home](docs/screenshots/dashboard-home.png)

### Gallery Modal

![Dashboard Gallery](docs/screenshots/dashboard-gallery.png)

### Lightbox Preview

![Dashboard Lightbox](docs/screenshots/dashboard-lightbox.png)

## Important Notes

- This repo should not include local runtime artifacts (logs, outputs, model weights, embedded Python folders).
- See `.gitignore` for the recommended exclusion list before publishing.
- Hardware profile files (`gpu_profile.env`, `gpu-idle.env`, `locale.env`) are machine-specific and should stay local.

## Security / Publishing

Before pushing to GitHub:

1. Review `SECURITY_AUDIT.md`.
2. Verify no local secrets or personal paths are staged.
3. Commit only source scripts/config/docs needed for reproducible setup.

### First commit helper

Create the first safe commit with:

```powershell
.\Publish-First-Commit.ps1
```

Dry-run (preview staged files anytime):

```powershell
.\Publish-First-Commit.ps1 -DryRun
```

Then create the GitHub repo and push — see `GITHUB_PUBLISH_CHECKLIST.md`.

To set repository description/topics (requires `gh` CLI):

```powershell
.\Publish-GitHub-Profile.ps1 -Repo "your-user/ai-studio-portable"
```

GitHub copy/paste texts: `docs/github/REPO_ABOUT.md`, `docs/github/WIKI_HOME.md`.
