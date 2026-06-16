#Requires -Version 5.1
<#
.SYNOPSIS
  Applies GitHub repository description/topics via gh CLI (after 16:00).
.PARAMETER Repo
  GitHub repo slug, e.g. "username/ai-studio-portable"
.PARAMETER Force
  Skip the 16:00 time gate.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Repo,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$now = Get-Date
$gate = Get-Date -Year $now.Year -Month $now.Month -Day $now.Day -Hour 16 -Minute 0 -Second 0
if (-not $Force -and $now -lt $gate) {
    Write-Host 'GitHub profile update is scheduled after 16:00. Re-run later.' -ForegroundColor Yellow
    exit 2
}

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw 'GitHub CLI (gh) not found. Install from https://cli.github.com/'
}

$desc = 'Portable Windows AI studio: ComfyUI workflows, ACE-Step music generation, and a local dashboard hub with audio post-production tools.'
$topics = 'comfyui,ace-step,windows,portable,powershell,local-ai,audio-processing,dashboard,amd-gpu,rocm'

gh repo edit $Repo --description $desc --add-topic ($topics -split ',')

Write-Host "OK: updated profile for $Repo" -ForegroundColor Green
Write-Host 'Wiki home: paste content from docs/github/WIKI_HOME.md' -ForegroundColor Gray
Write-Host 'Pages:     optional — see docs/github/PAGES_INDEX.md' -ForegroundColor Gray
