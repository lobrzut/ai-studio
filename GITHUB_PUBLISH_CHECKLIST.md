# GitHub Publish Checklist

## Before 16:00 (preparation — done)

- [x] `.gitignore` excludes logs, runtimes, models, outputs, local `.env`
- [x] English `README.md`, `SECURITY_AUDIT.md`, `LICENSE`
- [x] GitHub description/wiki drafts in `docs/github/`
- [x] `Publish-First-Commit.ps1` (time-gated commit script)
- [x] `git init` in project folder

## After 16:00 — step 1: first commit

```powershell
cd <your-project-folder>
.\Publish-First-Commit.ps1
```

Preview only (any time):

```powershell
.\Publish-First-Commit.ps1 -DryRun
```

## After 16:00 — step 2: create remote and push

```powershell
git branch -M main
git remote add origin https://github.com/<user>/ai-studio-portable.git
git push -u origin main
```

Or with GitHub CLI:

```powershell
gh repo create ai-studio-portable --public --source=. --remote=origin --push
```

## After 16:00 — step 3: repository profile

```powershell
.\Publish-GitHub-Profile.ps1 -Repo "<user>/ai-studio-portable"
```

Manual copy/paste from:

- `docs/github/REPO_ABOUT.md` — description, topics, about text
- `docs/github/WIKI_HOME.md` — wiki home page
- `docs/github/PAGES_INDEX.md` — optional GitHub Pages landing

## Post-push verification

- [ ] No `logs/`, `python/`, `output/`, or `gpu_profile.env` in GitHub file tree
- [ ] README renders correctly
- [ ] Secret scanning enabled in repo settings
- [ ] Branch protection on `main` (optional)
