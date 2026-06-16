# AI Studio Portable — mapa narzedzi

Folder portable: **`AIStudio-Portable`** (korzen stacku).

## Entrypointy (korzen)

| Plik | Co robi |
|------|---------|
| `Install.bat` | Instalacja ComfyUI + ACE-Step + Manager |
| `Start.bat` | Oba serwery (7870 + 7871) |
| `Stop.bat` | Stop |
| `Open-Dashboard.bat` | Ten dashboard |

## Podfoldery

```
AIStudio-Portable/
├── ComfyUI/     Grafika, wideo, workflow, Manager (:7871)
├── ACE-Step/    Muzyka Gradio (:7870)
└── Toolkit/     Post-prod audio, Outputs/
```

## Workflow

1. `Start.bat` w korzeniu
2. ComfyUI do grafiki / http://127.0.0.1:7871
3. ACE-Step do muzyki / http://127.0.0.1:7870
4. Master / Stems / Match / Lyrics w Toolkit
