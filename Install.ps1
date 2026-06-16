#Requires -Version 5.1
<#
.SYNOPSIS
  AI Studio Portable — installer (ACE-Step + ComfyUI + Toolkit).
.DESCRIPTION
  Uruchom z dowolnego miejsca po skopiowaniu folderu AIStudio-Portable/ na nowy PC.
  Instaluje oba portable, ComfyUI-Manager, Enhance AI (resemble-enhance), synchronizuje profil GPU.
#>
[CmdletBinding()]
param(
    [ValidateSet('auto','amd','nvidia','cpu')]
    [string]$GpuVendor = 'auto',
    [string]$HsaOverride,
    [switch]$Force,
    [switch]$SkipModel,
    [switch]$SkipEnhanceAI,
    [switch]$NoAutoStart,
    [switch]$AceOnly,
    [switch]$ComfyOnly
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Root     = $PSScriptRoot
$AceDir    = Join-Path $Root 'ACE-Step'
$ComfyDir  = Join-Path $Root 'ComfyUI'
$ToolkitDir = Join-Path $Root 'Toolkit'

function Write-Step($m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Fail($m)       { Write-Host "ERROR: $m" -ForegroundColor Red; exit 1 }

Write-Host ''
Write-Host '============================================' -ForegroundColor Cyan
Write-Host ' AI Studio Portable — instalacja' -ForegroundColor Cyan
Write-Host " Folder: $Root" -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan

if (-not $ComfyOnly) {
    if (-not (Test-Path (Join-Path $AceDir 'Install.ps1'))) { Fail "Brak $AceDir\Install.ps1" }
    Write-Step 'ACE-Step'
    $aceArgs = @('-ExecutionPolicy','Bypass','-File',(Join-Path $AceDir 'Install.ps1'),
        '-GpuVendor',$GpuVendor)
    if ($HsaOverride) { $aceArgs += @('-HsaOverride',$HsaOverride) }
    if ($Force)       { $aceArgs += '-Force' }
    & powershell -NoProfile @aceArgs
    if ($LASTEXITCODE -ne 0) { Fail 'ACE-Step Install.ps1 nieudany.' }
}

if (-not $AceOnly) {
    if (-not (Test-Path (Join-Path $ComfyDir 'Install.ps1'))) { Fail "Brak $ComfyDir\Install.ps1" }
    Write-Step 'ComfyUI (+ ComfyUI-Manager)'
    $comfyArgs = @('-ExecutionPolicy','Bypass','-File',(Join-Path $ComfyDir 'Install.ps1'),
        '-GpuVendor',$GpuVendor)
    if ($HsaOverride) { $comfyArgs += @('-HsaOverride',$HsaOverride) }
    if ($Force)       { $comfyArgs += '-Force' }
    if ($SkipModel)   { $comfyArgs += '-SkipModel' }
    & powershell -NoProfile @comfyArgs
    if ($LASTEXITCODE -ne 0) { Fail 'ComfyUI Install.ps1 nieudany.' }
}

# Synchronizuj profil GPU (ACE jako zrodlo prawdy)
$aceProfile = Join-Path $AceDir 'gpu_profile.env'
if (Test-Path $aceProfile) {
    Copy-Item -LiteralPath $aceProfile -Destination (Join-Path $ComfyDir 'gpu_profile.env') -Force
    Write-Step 'Profil GPU zsynchronizowany do ComfyUI'
}

# Studio: foldery wyjsc
@(
    'Outputs/raw','Outputs/mastered','Outputs/stems','Outputs/voice-swapped','Outputs/covers','Outputs/lyrics','Outputs/videos',
    'Outputs/enhance/light','Outputs/enhance/medium','Outputs/enhance/comfy_queue','Outputs/enhance/comfy','Outputs/silence',
    'References','Tools','workflows','inbox','inbox\jobs'
) |
    ForEach-Object {
        $p = Join-Path $ToolkitDir $_
        if (-not (Test-Path $p)) { New-Item -ItemType Directory -Force -Path $p | Out-Null }
    }

if (-not $ComfyOnly -and -not $SkipEnhanceAI) {
    $enhPs1 = Join-Path $ToolkitDir 'Install-Enhance-AI.ps1'
    if (Test-Path -LiteralPath $enhPs1) {
        Write-Step 'Enhance AI (resemble-enhance, tryb medium)'
        $enhArgs = @('-ExecutionPolicy', 'Bypass', '-File', $enhPs1)
        if ($Force) { $enhArgs += '-Force' }
        & powershell -NoProfile @enhArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'UWAGA: Enhance AI nie zainstalowany — sredni tryb Enhance niedostepny do czasu naprawy pip.' -ForegroundColor Yellow
        }
    }
}

Write-Host ''
Write-Host '============================================' -ForegroundColor Green
Write-Host ' INSTALACJA ZAKONCZONA' -ForegroundColor Green
Write-Host '============================================' -ForegroundColor Green
Write-Host ''
Write-Host ' Install.bat NIE uruchamia ACE-Step ani ComfyUI.' -ForegroundColor Yellow
Write-Host ' Serwery startuje dopiero:  Start.bat' -ForegroundColor Yellow
Write-Host ' Pierwszy Start moze trwac 5-15 min (ladowanie modeli na GPU).' -ForegroundColor Gray
Write-Host ''

if (-not $NoAutoStart -and -not $AceOnly -and -not $ComfyOnly) {
    $startPs1 = Join-Path $Root 'Start.ps1'
    if (Test-Path -LiteralPath $startPs1) {
        $ans = Read-Host 'Uruchomic Start.bat teraz? (T = tak / N = pozniej)'
        if ($ans -match '^[tTyY]') {
            Write-Step 'Start stack (ACE + Comfy + dashboard)'
            & powershell -NoProfile -ExecutionPolicy Bypass -File $startPs1
            if ($LASTEXITCODE -eq 2) {
                Write-Host 'Start niekompletny — sprawdz logs\ (modele moga jeszcze ladowac).' -ForegroundColor Yellow
            }
        }
    }
}

Write-Host ''
Write-Host ' Adresy po Start.bat:' -ForegroundColor Green
Write-Host '  ACE-Step:  http://127.0.0.1:7870' -ForegroundColor Green
Write-Host '  ComfyUI:   http://127.0.0.1:7871' -ForegroundColor Green
Write-Host '  Dashboard: http://127.0.0.1:7880/' -ForegroundColor Green
Write-Host '============================================' -ForegroundColor Green
