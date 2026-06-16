# AI Studio Portable — Wiki Home

Welcome to the project wiki.

## What is this?

A portable Windows stack for local AI creation:

| Component | Port | Purpose |
|-----------|------|---------|
| Dashboard hub | 7880 | Central UI, service control, gallery, audio tools |
| ACE-Step | 7870 | Music generation (Gradio) |
| ComfyUI | 7871 | Image/video workflows |

## First run

1. Clone or copy the repository folder.
2. Run `Install.bat` (downloads runtimes, GPU profile, dependencies).
3. Run `Start.bat`.
4. Open `http://127.0.0.1:7880/`.

## What is included in Git?

This repository contains **launcher scripts, dashboard UI, and documentation**.

Large local artifacts are excluded:

- embedded Python runtimes
- model weights
- generated outputs and logs
- machine-specific GPU profile files

They are created on your machine by `Install.bat`.

## Troubleshooting

- **Services offline:** use **Start stack** on the dashboard or tray menu.
- **Gallery empty:** generate images in ComfyUI first; outputs land in `ComfyUI/ComfyUI/output`.
- **GPU meter wrong:** restart dashboard hub (`Restart-Dashboard.bat`).
- **Full audit:** run `Audit.ps1`.

## Security note

The dashboard binds to `127.0.0.1` only. Do not expose port `7880` to the public internet without adding authentication.
