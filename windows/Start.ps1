#Requires -Version 5.1

<#

.SYNOPSIS

  Uruchamia dashboard (tray + hub :7880 + przegladarka). ACE/Comfy z dashboardu lub menu tray.

#>

[CmdletBinding()]

param(

    [switch]$SkipInstall,

    [switch]$NoBrowser,

    [switch]$WithAi

)



$ErrorActionPreference = 'Stop'

[Console]::OutputEncoding = [System.Text.Encoding]::UTF8



$Root    = $PSScriptRoot

$AceDir  = Join-Path $Root 'ACE-Step'

$ComfyDir = Join-Path $Root 'ComfyUI'

$TrayPs1 = Join-Path $Root 'Toolkit\Dashboard-Tray.ps1'



. (Join-Path $Root 'Toolkit\Service-Control.ps1')



function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }



function Test-PortableReady([string]$Dir) {

    (Test-Path (Join-Path $Dir 'python\python.exe')) -and (Test-Path (Join-Path $Dir 'gpu_profile.env'))

}



function Ensure-Installed {

    if ($SkipInstall) { return }

    $needAce   = -not (Test-PortableReady $AceDir)

    $needComfy = -not (Test-PortableReady $ComfyDir)

    if (-not $needAce -and -not $needComfy) { return }

    Write-Step (L 'start_first_run')

    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Root 'Install.ps1')

    if ($LASTEXITCODE -ne 0) { throw (L 'start_install_fail') }

}



Write-Host ''

Write-Host '============================================' -ForegroundColor Cyan

Write-Host (' ' + (L 'start_title')) -ForegroundColor Cyan

Write-Host " Folder: $Root" -ForegroundColor Cyan

Write-Host '============================================' -ForegroundColor Cyan



Ensure-Installed

$ensureIco = Join-Path $Root 'Toolkit\Ensure-TrayIcon.ps1'
if (Test-Path -LiteralPath $ensureIco) {
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ensureIco | Out-Null
}

if (-not (Test-PortableReady $AceDir))   { throw (L 'start_ace_not_ready') }

if (-not (Test-PortableReady $ComfyDir)) { throw (L 'start_comfy_not_ready') }



$hubUrl = 'http://127.0.0.1:7880/'



if (Test-TrayHealthy) {
    Write-Host (L 'start_already_running') -ForegroundColor Yellow
    if (-not $NoBrowser) { Start-Process $hubUrl }
    exit 0
}

if (Test-TrayRunning -and -not (Test-TrayHealthy)) {
    Write-Host (L 'start_tray_broken') -ForegroundColor Yellow
    Stop-TrayHost
    Stop-StudioAll
    Start-Sleep -Seconds 2
}

$launchVbs = Join-Path $Root 'Toolkit\Launch-Tray.vbs'
$vbsArgs = @()
if (-not $NoBrowser) { $vbsArgs += 'OpenBrowser' }
if ($WithAi)         { $vbsArgs += 'AutoStartAi' }

if (Test-Path -LiteralPath $launchVbs) {
    $wscriptArgs = @('//B', $launchVbs)
    if ($vbsArgs.Count -gt 0) { $wscriptArgs += ($vbsArgs -join ' ') }
    Start-Process -FilePath 'wscript.exe' -ArgumentList $wscriptArgs -WindowStyle Hidden | Out-Null
} else {
    $trayArgs = @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Sta', '-WindowStyle', 'Minimized',
        '-File', $TrayPs1
    )
    if (-not $NoBrowser) { $trayArgs += '-OpenBrowser' }
    if ($WithAi)         { $trayArgs += '-AutoStartAi' }
    Start-Process -FilePath 'powershell.exe' -ArgumentList $trayArgs -WindowStyle Hidden | Out-Null
}

$trayOk = $false
$deadline = (Get-Date).AddSeconds(20)
while ((Get-Date) -lt $deadline) {
    if (Test-TrayHealthy) { $trayOk = $true; break }
    Start-Sleep -Milliseconds 800
}
if (-not $trayOk) {
    Write-Host (L 'start_tray_timeout') -ForegroundColor Yellow
    Write-Host (L 'start_tray_hint') -ForegroundColor Yellow
}



Write-Host ''

Write-Host (L 'start_ok') -ForegroundColor Green

Write-Host (L 'start_ai_hint') -ForegroundColor Gray

if ($WithAi) {

    Write-Host (L 'start_with_ai') -ForegroundColor Gray

}

Write-Host (L 'start_close_hint') -ForegroundColor Gray

Write-Host ''



exit 0

