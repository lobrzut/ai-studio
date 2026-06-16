# AI Studio Portable — Inventory

Portable folder layout for copy-to-USB / another PC.

## Structure

```
AIStudio-Portable/
├── Install.bat / Start.bat / Stop.bat / Open-Dashboard.bat
├── ComfyUI/           Install/start wrappers (ComfyUI app installed locally)
├── ACE-Step/          Install/start wrappers (ACE-Step app installed locally)
└── Toolkit/           Dashboard hub + audio post-production scripts
```

## Ports

| Service | Port |
|---------|------|
| ACE-Step Gradio | 7870 |
| ComfyUI | 7871 |
| Dashboard hub | 7880 |

## What Install.bat creates locally (not in Git)

- Embedded Python runtimes (`*/python/`)
- ComfyUI application tree (`ComfyUI/ComfyUI/`)
- ACE-Step application tree (`ACE-Step/ACE-Step-1.5/`)
- Model weights and generated outputs
- GPU profile files (`gpu_profile.env`)

## ComfyUI-Manager

Default `security_level = weak` in `ComfyUI\ComfyUI\user\__manager\config.ini` (full local node install).

## Models

Separate directories (not shared):

- `ACE-Step\ACE-Step-1.5\checkpoints\`
- `ComfyUI\ComfyUI\models\`
