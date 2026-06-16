#Requires -Version 5.1
<#
.SYNOPSIS
  Create GitHub repo (if needed) and push main branch.
.PARAMETER Repo
  GitHub slug, default: lobrzut/ai-studio-portable
#>
[CmdletBinding()]
param(
    [string]$Repo = 'lobrzut/ai-studio-portable'
)

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) not found. Install: winget install GitHub.cli'
}

$authOk = $false
try {
    gh auth status *> $null
    $authOk = $LASTEXITCODE -eq 0
} catch { }

if (-not $authOk) {
    Write-Host 'Log in to GitHub (use account: lobrzut):' -ForegroundColor Yellow
    gh auth login -h github.com -p https -w -s repo,read:org
}

if (-not (git rev-parse --verify main 2>$null)) {
    git branch -M main
}

$remote = "https://github.com/$Repo.git"
$hasOrigin = git remote | Select-String -Pattern '^origin$' -Quiet
if ($hasOrigin) {
    git remote set-url origin $remote
} else {
    git remote add origin $remote
}

$exists = $false
try {
    gh repo view $Repo --json name -q .name | Out-Null
    $exists = $LASTEXITCODE -eq 0
} catch { }

if (-not $exists) {
    Write-Host "Creating public repo $Repo ..." -ForegroundColor Cyan
    gh repo create $Repo --public --source=. --remote=origin --description 'Portable Windows AI studio: ComfyUI workflows, ACE-Step music generation, and a local dashboard hub with audio post-production tools.'
}

Write-Host 'Pushing main ...' -ForegroundColor Cyan
git push -u origin main

$topics = 'comfyui,ace-step,windows,portable,powershell,local-ai,audio-processing,dashboard,amd-gpu,rocm'
gh repo edit $Repo --add-topic ($topics -split ',')

Write-Host ''
Write-Host "OK: https://github.com/$Repo" -ForegroundColor Green
