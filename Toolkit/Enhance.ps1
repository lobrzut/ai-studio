#Requires -Version 5.1
<#
.SYNOPSIS
  Ulepszanie jakosci audio - 3 tryby: light (ffmpeg), medium (AI), heavy (ComfyUI).
.PARAMETER InputFile
  Plik wejsciowy (mp3/wav/flac/m4a/opus).
.PARAMETER Mode
  light | medium | heavy
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [ValidateSet('light', 'medium', 'heavy')]
    [string]$Mode = 'light'
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Toolkit = $PSScriptRoot
$AceRoot = (Resolve-Path (Join-Path $Toolkit '..\ACE-Step')).Path
$PyExe   = Join-Path $AceRoot 'python\python.exe'
$FFDir   = Join-Path $AceRoot 'ffmpeg\bin'

function Get-FfmpegPath {
    $ffmpeg = Join-Path $AceRoot 'python\ffmpeg.exe'
    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        $ffmpeg = Join-Path $AceRoot 'ffmpeg\bin\ffmpeg.exe'
    }
    if (-not (Test-Path -LiteralPath $ffmpeg)) {
        Write-Host 'ERROR: brak ffmpeg.exe w ACE-Step' -ForegroundColor Red
        exit 1
    }
    return $ffmpeg
}

function Show-Done([string]$path) {
    $sz = 0
    if (Test-Path -LiteralPath $path) {
        $sz = [math]::Round((Get-Item -LiteralPath $path).Length / 1MB, 2)
    }
    Write-Host ''
    Write-Host '============================================' -ForegroundColor Green
    Write-Host (' GOTOWE.  ' + $path + '  (' + $sz + ' MB)') -ForegroundColor Green
    Write-Host '============================================' -ForegroundColor Green
}

function Test-PortListen([int]$port) {
    [bool](Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Invoke-EnhanceLight {
    param([string]$InFull, [string]$InName, [string]$InExt, [string]$OutRoot)
    $ffmpeg = Get-FfmpegPath
    $env:PATH = $FFDir + ';' + $env:PATH

    $outExt = if ($InExt -in '.wav', '.flac') { $InExt } else { '.wav' }
    $outFile = Join-Path $OutRoot ($InName + '_enhanced_light' + $outExt)

    # Bez firequalizer (entry ma przecinki/średniki — ffmpeg rozdziela je jako osobne filtry).
    $af = @(
        'highpass=f=35'
        'afftdn=nr=12:nf=-25'
        'equalizer=f=120:t=q:w=1.2:g=1'
        'equalizer=f=2500:t=q:w=1.5:g=2.5'
        'equalizer=f=8000:t=q:w=1.2:g=1'
        'acompressor=threshold=-20dB:ratio=2.5:attack=8:release=80:makeup=2'
        'alimiter=limit=0.95:attack=5:release=50'
    ) -join ','

    $encArgs = switch ($outExt) {
        '.flac' { @('-c:a', 'flac', '-compression_level', '5') }
        default { @('-c:a', 'pcm_s16le') }
    }

    Write-Host ''
    Write-Host '==> ffmpeg: odszumienie + EQ + kompresja (lekki)' -ForegroundColor Yellow
    $ffArgs = @('-hide_banner', '-nostats', '-y', '-i', $InFull, '-af', $af) + $encArgs + @($outFile)
    & $ffmpeg @ffArgs 2>&1 | ForEach-Object { Write-Host $_ }

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outFile)) {
        Write-Host ('ERROR: ffmpeg exit ' + $LASTEXITCODE) -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Show-Done $outFile
}

function Invoke-EnhanceMediumFfmpeg {
    param([string]$InFull, [string]$InName, [string]$InExt, [string]$OutRoot)
    $ffmpeg = Get-FfmpegPath
    $env:PATH = $FFDir + ';' + $env:PATH

    $outExt = if ($InExt -in '.wav', '.flac') { $InExt } else { '.wav' }
    $outFile = Join-Path $OutRoot ($InName + '_enhanced_medium' + $outExt)

    $af = @(
        'highpass=f=40'
        'afftdn=nr=18:nf=-30'
        'equalizer=f=100:t=q:w=1.3:g=1.5'
        'equalizer=f=3000:t=q:w=1.4:g=3'
        'equalizer=f=10000:t=q:w=1.3:g=1.5'
        'acompressor=threshold=-18dB:ratio=3:attack=5:release=60:makeup=3'
        'alimiter=limit=0.92:attack=3:release=40'
        'loudnorm=I=-14:TP=-1:LRA=11'
    ) -join ','

    $encArgs = switch ($outExt) {
        '.flac' { @('-c:a', 'flac', '-compression_level', '5') }
        default { @('-c:a', 'pcm_s16le') }
    }

    Write-Host ''
    Write-Host '==> ffmpeg: mocniejsze odszumienie + EQ + loudnorm (medium)' -ForegroundColor Yellow
    $ffArgs = @('-hide_banner', '-nostats', '-y', '-i', $InFull, '-af', $af) + $encArgs + @($outFile)
    & $ffmpeg @ffArgs 2>&1 | ForEach-Object { Write-Host $_ }

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outFile)) {
        Write-Host ('ERROR: ffmpeg exit ' + $LASTEXITCODE) -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Show-Done $outFile
}

function Invoke-EnhanceMedium {
    param([string]$InFull, [string]$InName, [string]$InExt, [string]$OutRoot)
    if (-not (Test-Path -LiteralPath $PyExe)) {
        Write-Host ('ERROR: brak ' + $PyExe) -ForegroundColor Red
        exit 1
    }

    $env:HSA_OVERRIDE_GFX_VERSION = '10.3.0'
    $env:PYTORCH_HIP_ALLOC_CONF = 'expandable_segments:True'
    $env:PATH = $FFDir + ';' + $env:PATH

    $stubDir = Join-Path $Toolkit 'deepspeed_stub'
    $importPy = @"
import sys
sys.path.insert(0, r'$stubDir')
from resemble_enhance.enhancer.inference import denoise, enhance
"@

    $importOut = & $PyExe -c $importPy 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host 'UWAGA: Resemble AI niedostepne - uzywam ffmpeg (medium).' -ForegroundColor Yellow
        if ($importOut) { $importOut | Select-Object -First 3 | ForEach-Object { Write-Host ('  ' + $_) -ForegroundColor DarkGray } }
        Write-Host 'Pelne AI: Toolkit\Install-Enhance-AI.bat' -ForegroundColor Gray
        Write-Host ''
        Invoke-EnhanceMediumFfmpeg -InFull $InFull -InName $InName -InExt $inExt -OutRoot $outRoot
        return
    }

    $pyScript = Join-Path $Toolkit 'Enhance-Medium.py'
    $outFile  = Join-Path $OutRoot ($InName + '_enhanced_ai.wav')

    Write-Host ''
    Write-Host '==> Resemble Enhance (AI - pierwsze uzycie pobiera modele)' -ForegroundColor Yellow
    & $PyExe $pyScript $InFull $outFile 2>&1 | ForEach-Object { Write-Host $_ }

    if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $outFile)) {
        Write-Host ('ERROR: Enhance-Medium exit ' + $LASTEXITCODE) -ForegroundColor Red
        exit $LASTEXITCODE
    }
    Show-Done $outFile
}

function Invoke-EnhanceHeavy {
    param([string]$InFull)
    $queueDir = Join-Path $Toolkit 'Outputs\enhance\comfy_queue'
    New-Item -ItemType Directory -Force -Path $queueDir | Out-Null
    $dest = Join-Path $queueDir ([IO.Path]::GetFileName($InFull))
    Copy-Item -LiteralPath $InFull -Destination $dest -Force

    $guide = Join-Path $Toolkit 'workflows\ENHANCE-COMFYUI.md'
    Write-Host ''
    Write-Host '==> Tryb ComfyUI (reczny workflow)' -ForegroundColor Yellow
    Write-Host ('    Plik: ' + $dest)
    Write-Host ('    Instrukcja: ' + $guide)
    Write-Host ''

    if (Test-PortListen 7871) {
        Start-Process 'http://127.0.0.1:7871/'
        Write-Host '    Otworzono ComfyUI.' -ForegroundColor Gray
    } else {
        Write-Host '    ComfyUI offline - uruchom Start.bat' -ForegroundColor Yellow
    }

    if (Test-Path -LiteralPath $guide) { Start-Process -FilePath $guide }
    Show-Done $dest
}

if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Host ('ERROR: Plik nie istnieje: ' + $InputFile) -ForegroundColor Red
    exit 1
}

$inFull  = (Resolve-Path -LiteralPath $InputFile).Path
$inName  = [IO.Path]::GetFileNameWithoutExtension($inFull)
$inExt   = [IO.Path]::GetExtension($inFull).ToLower()
$outRoot = Join-Path $Toolkit ('Outputs\enhance\' + $Mode)
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

Write-Host ''
Write-Host '============================================' -ForegroundColor Cyan
Write-Host (' Enhance - tryb: ' + $Mode) -ForegroundColor Cyan
Write-Host (' Input:  ' + $inFull)
Write-Host (' Output: ' + $outRoot)
Write-Host '============================================' -ForegroundColor Cyan

switch ($Mode) {
    'light'  { Invoke-EnhanceLight -InFull $inFull -InName $inName -InExt $inExt -OutRoot $outRoot }
    'medium' { Invoke-EnhanceMedium -InFull $inFull -InName $inName -InExt $inExt -OutRoot $outRoot }
    'heavy'  { Invoke-EnhanceHeavy -InFull $inFull }
}
