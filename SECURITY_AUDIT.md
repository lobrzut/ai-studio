# Security Audit (Pre-GitHub)

Date: 2026-06-16
Project: `AIStudio-Portable`

## Scope

Reviewed:

- Top-level scripts (`*.ps1`, `*.bat`)
- `Toolkit` dashboard and helper scripts
- Local `.env`-style files used by this project

Excluded from deep content review:

- Embedded third-party Python packages/docs under `ACE-Step/python` and `ComfyUI/python`
- Large runtime-generated folders (`logs`, outputs, model directories)

## Findings

### 1) Hardcoded secrets in project scripts

- **Result:** No hardcoded API keys, bearer tokens, private keys, or password assignments found in project-owned scripts.
- **Risk:** Low.

### 2) Machine-specific data present locally

- Found local hardware profile files:
  - `ACE-Step/gpu_profile.env`
  - `ComfyUI/gpu_profile.env`
  - `Toolkit/gpu-idle.env`
- These are not credentials, but they are local environment details and should not be committed.

### 3) High-volume local artifacts that must not be pushed

- Runtime logs in `logs/`
- Generated outputs in `Toolkit/Outputs`, `Toolkit/References`, `ComfyUI/ComfyUI/output`
- Large model/runtime folders and embedded Python environments

## Actions Taken

- Added root `.gitignore` to exclude:
  - local logs
  - generated outputs
  - machine-specific `.env` profile files
  - embedded Python runtime folders
  - vendored app trees (`ACE-Step-ACE-Step-1.5`, `ComfyUI/ComfyUI`)
  - heavy model artifacts
  - personal one-off migration scripts

- Rewrote root `README.md` in English for GitHub publication.
- Added `LICENSE` (MIT), `docs/github/*` profile drafts.
- Added `Publish-First-Commit.ps1` (commit blocked until 16:00 local time).
- Added `Publish-GitHub-Profile.ps1` for `gh repo edit` after push.

## Residual Risk / Manual Checks

Before first public push, run these manual checks:

1. Inspect staged files:
   - `git status`
   - `git diff --staged`
2. Ensure no local paths/usernames appear in docs/scripts.
3. Ensure no binaries/models are staged.
4. If history already contains sensitive data, rewrite history before publishing.

## Recommended Publish Strategy

- Publish only source/control files first:
  - launcher scripts
  - toolkit scripts/UI
  - docs
- Keep machine/runtime artifacts local.
