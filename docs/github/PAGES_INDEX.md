# AI Studio Portable

Portable local AI studio for Windows.

## Features

- **ComfyUI** — image and video workflows
- **ACE-Step** — music generation
- **Dashboard hub** — unified launcher at port `7880`
- **Audio toolkit** — master, stems, match, lyrics, enhance, silence scan
- **Comfy gallery** — browse `output/` folders and preview renders

## Quick start

```bat
Install.bat
Start.bat
```

Open: [http://127.0.0.1:7880/](http://127.0.0.1:7880/)

## Repository layout

| Path | Role |
|------|------|
| `Install.ps1` / `Start.ps1` | Root orchestration |
| `Toolkit/` | Dashboard UI and helper scripts |
| `ACE-Step/` | ACE-Step install/start wrappers |
| `ComfyUI/` | ComfyUI install/start wrappers |

## License

MIT — see `LICENSE`.
