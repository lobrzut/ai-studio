#Requires -Version 5.1
<#
.SYNOPSIS
  Creates the first safe Git commit after 16:00 local time.
.DESCRIPTION
  Stages only files allowed by .gitignore, verifies no secrets in staged set,
  then creates the initial commit. Does NOT push to remote.
.PARAMETER Force
  Skip the 16:00 time gate (for testing only).
.PARAMETER DryRun
  Show what would be committed without creating a commit.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Set-Location $Root

$now = Get-Date
$gate = Get-Date -Year $now.Year -Month $now.Month -Day $now.Day -Hour 16 -Minute 0 -Second 0
if (-not $Force -and $now -lt $gate) {
    $wait = $gate - $now
    Write-Host "First commit is scheduled after 16:00 (local)." -ForegroundColor Yellow
    Write-Host "Current time: $($now.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host "Opens at:     $($gate.ToString('yyyy-MM-dd HH:mm:ss'))" -ForegroundColor Gray
    Write-Host "Wait:         $([math]::Floor($wait.TotalMinutes)) min" -ForegroundColor Gray
    Write-Host ''
    Write-Host 'Everything is prepared. Re-run this script after 16:00.' -ForegroundColor Cyan
    exit 2
}

if (-not (Test-Path (Join-Path $Root '.git'))) {
    git init | Out-Null
}

git add .

$staged = git diff --cached --name-only
if (-not $staged) {
    Write-Host 'Nothing to commit (check .gitignore).' -ForegroundColor Yellow
    exit 1
}

$secretPatterns = @(
    'AKIA[0-9A-Z]{16}',
    'ghp_[A-Za-z0-9]{20,}',
    'github_pat_[A-Za-z0-9_]{20,}',
    'sk-[A-Za-z0-9]{20,}',
    '-----BEGIN [A-Z ]*PRIVATE KEY-----'
)
$stagedFiles = $staged | ForEach-Object { Join-Path $Root $_ }
$hits = @()
foreach ($f in $stagedFiles) {
    if (-not (Test-Path -LiteralPath $f -PathType Leaf)) { continue }
    $ext = [IO.Path]::GetExtension($f).ToLower()
    if ($ext -in '.png', '.jpg', '.jpeg', '.webp', '.gif', '.mp3', '.wav', '.safetensors', '.ckpt', '.pt', '.bin') { continue }
    $text = Get-Content -LiteralPath $f -Raw -ErrorAction SilentlyContinue
    if (-not $text) { continue }
    foreach ($pat in $secretPatterns) {
        if ($text -match $pat) {
            $hits += "$f matches $pat"
        }
    }
}
if ($hits.Count) {
    Write-Host 'BLOCKED: possible secrets in staged files:' -ForegroundColor Red
    $hits | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    exit 3
}

Write-Host ''
Write-Host "Staged files ($($staged.Count)):" -ForegroundColor Cyan
$staged | ForEach-Object { Write-Host "  $_" }

if ($DryRun) {
    Write-Host ''
    Write-Host 'Dry run — no commit created.' -ForegroundColor Yellow
    exit 0
}

$msg = @'
Initial public release: portable launcher, dashboard hub, and docs.

Includes Windows orchestration scripts, Toolkit dashboard UI, security audit,
and GitHub publishing guides. Local runtimes, models, outputs, and logs are
excluded via .gitignore.
'@

git commit -m $msg.Trim()

Write-Host ''
Write-Host 'OK: first commit created.' -ForegroundColor Green
Write-Host 'Next: create GitHub repo and push (see GITHUB_PUBLISH_CHECKLIST.md).' -ForegroundColor Gray
git log -1 --oneline
git status --short --branch
