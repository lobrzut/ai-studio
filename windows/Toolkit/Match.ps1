#Requires -Version 5.1
<#
.SYNOPSIS
  Matchering 2.0 — auto-master pod referencyjny utwor.
  Dopasowuje EQ + kompresje + LUFS twojego utworu do brzmienia referencyjnego (np. Perturbator).
.PARAMETER Target
  Twoj utwor (do remasterowania).
.PARAMETER Reference
  Referencyjny utwor (wzorzec brzmienia). Jesli pominiete, uzyje najnowszego z Studio\References\.
.EXAMPLE
  .\Match.ps1 -Target moj.mp3 -Reference perturbator.wav
  .\Match.ps1 -Target moj.mp3   # uzyje najnowszego z References\
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Target,
    [string]$Reference
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $Target)) { Write-Host "ERROR: target nie istnieje: $Target" -ForegroundColor Red; exit 1 }

# Reference: jesli nie podany -> najnowszy z References\
if (-not $Reference) {
    $refDir = Join-Path $PSScriptRoot 'References'
    if (-not (Test-Path $refDir)) { Write-Host "ERROR: brak Studio\References\ — wrzuc tam wav-y wzorcowe" -ForegroundColor Red; exit 1 }
    $ref = Get-ChildItem $refDir -File -Include '*.wav','*.flac','*.mp3' -Recurse | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $ref) { Write-Host "ERROR: brak audio w Studio\References\ (wrzuc wav/flac/mp3 do References\)" -ForegroundColor Red; exit 1 }
    $Reference = $ref.FullName
    Write-Host "    Reference auto: $($ref.Name)" -ForegroundColor Gray
} elseif (-not (Test-Path -LiteralPath $Reference)) {
    Write-Host "ERROR: reference nie istnieje: $Reference" -ForegroundColor Red; exit 1
}

$AceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\ACE-Step')).Path
$PyExe   = Join-Path $AceRoot 'python\python.exe'
if (-not (Test-Path $PyExe)) { Write-Host "ERROR: brak $PyExe"; exit 1 }

$tFull   = (Resolve-Path -LiteralPath $Target).Path
$rFull   = (Resolve-Path -LiteralPath $Reference).Path
$tName   = [System.IO.Path]::GetFileNameWithoutExtension($tFull)
$outDir  = Join-Path $PSScriptRoot 'Outputs\mastered'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
$out16   = Join-Path $outDir "${tName}_matched_16bit.wav"
$out24   = Join-Path $outDir "${tName}_matched_24bit.wav"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Matchering 2.0" -ForegroundColor Cyan
Write-Host " Target:    $tFull"
Write-Host " Reference: $rFull"
Write-Host " Output:    $out16  +  $out24"
Write-Host "============================================" -ForegroundColor Cyan

# Inline python wywolanie matchering
$pyScript = @"
import sys
import matchering as mg
mg.log(print_handler=print)
mg.process(
    target=sys.argv[1],
    reference=sys.argv[2],
    results=[
        mg.pcm16(sys.argv[3]),
        mg.pcm24(sys.argv[4]),
    ],
)
print('MATCHERING_DONE')
"@
$tmpPy = Join-Path $env:TEMP 'match_run.py'
Set-Content -LiteralPath $tmpPy -Value $pyScript -Encoding UTF8

# FFmpeg PATH dla matchering's audio decoder
$FFDir = Join-Path $AceRoot 'ffmpeg\bin'
$env:PATH = $FFDir + ';' + $env:PATH

& $PyExe $tmpPy $tFull $rFull $out16 $out24 2>&1 | ForEach-Object { Write-Host $_ }
Remove-Item $tmpPy -Force

if (Test-Path $out16) {
    $sz = [math]::Round((Get-Item $out16).Length / 1MB, 1)
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host " GOTOWE." -ForegroundColor Green
    Write-Host "   16-bit: $out16  ($sz MB)" -ForegroundColor Gray
    if (Test-Path $out24) {
        $sz24 = [math]::Round((Get-Item $out24).Length / 1MB, 1)
        Write-Host "   24-bit: $out24  ($sz24 MB)" -ForegroundColor Gray
    }
    Write-Host "============================================" -ForegroundColor Green
} else {
    Write-Host "ERROR: brak pliku wyjsciowego" -ForegroundColor Red
    exit 1
}
