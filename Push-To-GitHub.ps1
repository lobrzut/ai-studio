#Requires -Version 5.1
param([string]$Repo = 'lobrzut/ai-studio')

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'Install GitHub CLI: winget install GitHub.cli'
}

$exists = $false
try {
    gh repo view $Repo *> $null
    $exists = $LASTEXITCODE -eq 0
} catch { }

if (-not $exists) {
    # Rename existing portable repo if present
    try {
        gh repo rename ai-studio --repo lobrzut/ai-studio-portable 2>$null
        $exists = $true
        $Repo = 'lobrzut/ai-studio'
    } catch { }
}

if (-not $exists) {
    gh repo create $Repo --public --source=. --remote=origin `
        --description 'AI Studio — Windows portable + Linux server (one repo): ComfyUI, ACE-Step, shared dashboard.'
}

git remote set-url origin "https://github.com/$Repo.git"
git push -u origin main

gh repo edit $Repo --description 'AI Studio monorepo: Windows (portable) + Linux (curl install). ComfyUI, ACE-Step, shared PL/EN dashboard.'

Write-Host "OK: https://github.com/$Repo" -ForegroundColor Green
Write-Host ''
Write-Host 'Linux one-liner:' -ForegroundColor Cyan
Write-Host "  curl -fsSL https://raw.githubusercontent.com/$Repo/main/linux/bootstrap.sh | sudo bash" -ForegroundColor White
Write-Host 'Windows:' -ForegroundColor Cyan
Write-Host '  Install.bat  then  Start.bat' -ForegroundColor White
