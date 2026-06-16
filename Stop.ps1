#Requires -Version 5.1
<#
.SYNOPSIS
  Zatrzymuje caly stack (ACE, Comfy, hub) oraz proces tray.
#>
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'

$Root = $PSScriptRoot
. (Join-Path $Root 'Toolkit\Service-Control.ps1')

Write-Host '==> Stop AI Studio (stack + tray)' -ForegroundColor Cyan
Stop-StudioAll
Stop-TrayHost

if (Test-AnyStudioPortBusy) {
    Write-Host 'WARN: nadal cos slucha na 7870/7871/7880 — sprobuj ponownie lub reboot.' -ForegroundColor Yellow
} else {
    Write-Host 'OK: stack wylaczony. Bez ikony tray nic nie dziala.' -ForegroundColor Green
}
