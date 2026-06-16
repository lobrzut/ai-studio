#Requires -Version 5.1
<#
.SYNOPSIS
  Demucs stem separation (htdemucs) na GPU ROCm. Drag & drop na Stems.bat.
.PARAMETER InputFile
  Plik audio (mp3/wav/flac/m4a/opus).
.PARAMETER Model
  htdemucs (default, 4-stem), htdemucs_ft (lepsze, wolniej), htdemucs_6s (6 stem + piano + guitar).
.PARAMETER TwoStems
  vocals = wyciaga tylko vocals + accompaniment (znacznie szybciej). Pomin dla pelnego 4-stem.
.EXAMPLE
  .\Stems.ps1 -InputFile track.mp3
  .\Stems.ps1 -InputFile track.mp3 -TwoStems vocals
  .\Stems.ps1 -InputFile track.mp3 -Model htdemucs_6s
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [ValidateSet('htdemucs','htdemucs_ft','htdemucs_6s','mdx_extra','mdx_extra_q')]
    [string]$Model = 'htdemucs',
    [ValidateSet('','vocals','drums','bass','other')]
    [string]$TwoStems = ''
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Host "ERROR: Plik nie istnieje: $InputFile" -ForegroundColor Red
    exit 1
}

# Sciezki: reuse Pythona i FFmpeg z ACE-Step
$AceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\ACE-Step')).Path
$PyExe   = Join-Path $AceRoot 'python\python.exe'
$FFDir   = Join-Path $AceRoot 'ffmpeg\bin'
if (-not (Test-Path $PyExe)) { Write-Host "ERROR: brak $PyExe (czy ACE-Step istnieje?)" -ForegroundColor Red; exit 1 }

$inFull  = (Resolve-Path -LiteralPath $InputFile).Path
$inName  = [System.IO.Path]::GetFileNameWithoutExtension($inFull)
$outRoot = Join-Path $PSScriptRoot 'Outputs\stems'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Demucs stem separation" -ForegroundColor Cyan
Write-Host " Input:    $inFull"
Write-Host " Model:    $Model$(if ($TwoStems) { ' (2-stems: '+$TwoStems+')' } else { ' (4-stems)' })"
Write-Host " Output:   $outRoot\$Model\$inName\"
Write-Host "============================================" -ForegroundColor Cyan

# FFmpeg na PATH (demucs uzywa go do dekodowania niewspieranych formatow przez torchaudio)
$env:PATH = $FFDir + ';' + $env:PATH
# ROCm env (zgodne z naszym ACE-Step setup)
$env:HSA_OVERRIDE_GFX_VERSION = '10.3.0'
$env:PYTORCH_HIP_ALLOC_CONF = 'expandable_segments:True'

$args = @('-m','demucs','-n',$Model,'-d','cuda','-o',$outRoot)
if ($TwoStems) { $args += @('--two-stems', $TwoStems) }
$args += $inFull

Write-Host ""
Write-Host "==> Uruchamiam demucs (pierwsze uzycie pobiera model ~80-300 MB)" -ForegroundColor Yellow
& $PyExe @args 2>&1 | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: demucs zwrocil exit $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Lista wynikowych plikow
$resultDir = Join-Path $outRoot "$Model\$inName"
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " GOTOWE.  Pliki w: $resultDir" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
if (Test-Path $resultDir) {
    Get-ChildItem $resultDir -Filter '*.wav' | ForEach-Object {
        $sz = [math]::Round($_.Length / 1MB, 1)
        Write-Host "    $($_.Name)  ($sz MB)" -ForegroundColor Gray
    }
}
