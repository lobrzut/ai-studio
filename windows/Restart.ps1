#Requires -Version 5.1
<#
.SYNOPSIS
  Zatrzymuje caly stack (7870, 7871, 7880) i uruchamia ponownie.
#>
[CmdletBinding()]
param(
    [int]$StopWaitSec = 5
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root = $PSScriptRoot
$stop = Join-Path $Root 'Stop.ps1'
$start = Join-Path $Root 'Start.ps1'

if (-not (Test-Path $stop)) { Write-Host "ERROR: brak $stop" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $start)) { Write-Host "ERROR: brak $start" -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host '============================================' -ForegroundColor Cyan
Write-Host ' AI Studio Portable - Restart' -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan

Write-Host ''
Write-Host '==> Stop stack' -ForegroundColor Yellow
& powershell -NoProfile -ExecutionPolicy Bypass -File $stop
Start-Sleep -Seconds $StopWaitSec

Write-Host ''
Write-Host '==> Start stack' -ForegroundColor Yellow
& powershell -NoProfile -ExecutionPolicy Bypass -File $start -NoBrowser -WithAi
exit $LASTEXITCODE
