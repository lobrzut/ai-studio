#Requires -Version 5.1
<#
.SYNOPSIS
  Zatrzymuje caly stack (ACE, Comfy, hub) oraz proces tray.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'

$Root = $PSScriptRoot
. (Join-Path $Root 'Toolkit\Service-Control.ps1')

Write-Host (L 'stop_title') -ForegroundColor Cyan
Stop-StudioAll
Stop-TrayHost

if (Test-AnyStudioPortBusy) {
    Write-Host (L 'stop_warn_ports') -ForegroundColor Yellow
} else {
    Write-Host (L 'stop_ok') -ForegroundColor Green
}