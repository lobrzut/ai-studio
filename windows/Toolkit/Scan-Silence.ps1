#Requires -Version 5.1
<#
.SYNOPSIS
  Wykrywa dlugie fragmenty ciszy w utworze (np. po ACE-Step) i podaje sekundy do Repaint.
.PARAMETER InputFile
  Plik audio (mp3/wav/flac).
.PARAMETER MinSilenceSec
  Raportuj cisze dluzsze niz ta wartosc (domyslnie 0.35 s).
.PARAMETER ThresholdDb
  Prog ciszy w dB (domyslnie -40).
.EXAMPLE
  .\Scan-Silence.ps1 -InputFile "..\ACE-Step\ACE-Step-1.5\gradio_outputs\utwor.mp3"
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [double]$MinSilenceSec = 0.35,
    [int]$ThresholdDb = -40,
    [switch]$SaveReport,
    [switch]$OpenAce
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Host ('ERROR: brak pliku: ' + $InputFile) -ForegroundColor Red
    exit 1
}

$AceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\ACE-Step')).Path
$ffmpeg = Join-Path $AceRoot 'python\ffmpeg.exe'
if (-not (Test-Path -LiteralPath $ffmpeg)) {
    $ffmpeg = Join-Path $AceRoot 'ffmpeg\bin\ffmpeg.exe'
}
if (-not (Test-Path -LiteralPath $ffmpeg)) {
    Write-Host 'ERROR: brak ffmpeg w ACE-Step' -ForegroundColor Red
    exit 1
}

$inFull = (Resolve-Path -LiteralPath $InputFile).Path
$inName = [IO.Path]::GetFileNameWithoutExtension($inFull)
$padSec = 0.15
$reportLines = New-Object System.Collections.Generic.List[string]

function Add-Line([string]$s) {
    $reportLines.Add($s) | Out-Null
    Write-Host $s
}

Add-Line ''
Add-Line '============================================'
Add-Line ' Napraw cisze - skan (do ACE Repaint)'
Add-Line (' Plik: ' + $inFull)
Add-Line (' Prog: ' + $ThresholdDb + ' dB, min: ' + $MinSilenceSec + ' s')
Add-Line '============================================'
Add-Line ''

$log = & $ffmpeg -hide_banner -i $inFull -af ('silencedetect=noise=' + $ThresholdDb + 'dB:d=' + $MinSilenceSec) -f null - 2>&1 | Out-String

$starts = [regex]::Matches($log, 'silence_start:\s*([\d.]+)')
$ends   = [regex]::Matches($log, 'silence_end:\s*([\d.]+)\s*\|\s*silence_duration:\s*([\d.]+)')

$outDir = Join-Path $PSScriptRoot 'Outputs\silence'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

if ($starts.Count -eq 0 -and $ends.Count -eq 0) {
    Add-Line 'Brak dlugich fragmentow ciszy przy tym progu.'
    Add-Line 'Jesli nadal slychac dziury: obniz prog (-45) lub min (0.2).'
} else {
    Add-Line ('Znalezione fragmenty ciszy: ' + $ends.Count)
    Add-Line ''
    Add-Line '  #   start    koniec   dlugosc   ACE Repaint (start -> end)'
    Add-Line ' ---  ------   ------   -------   ---------------------------'

    $i = 0
    foreach ($m in $ends) {
        $i++
        $endSec = [double]$m.Groups[1].Value
        $durSec = [double]$m.Groups[2].Value
        $startSec = [math]::Max(0, $endSec - $durSec)
        $rs = [math]::Max(0, $startSec - $padSec)
        $re = $endSec + $padSec
        $rsStr = '{0:F2}' -f $rs
        $reStr = '{0:F2}' -f $re
        Add-Line (' {0,3}  {1,6:F2}s  {2,6:F2}s  {3,6:F2}s   {4} -> {5}' -f $i, $startSec, $endSec, $durSec, $rsStr, $reStr)
    }
}

Add-Line ''
Add-Line 'Co dalej w ACE-Step (http://127.0.0.1:7870):'
Add-Line '  1. Wgraj ten plik jako zrodlo / Source audio'
Add-Line '  2. Tryb: Repaint (albo Send To Repaint)'
Add-Line '  3. Repainting start / end = sekundy z tabeli powyzej'
Add-Line '  4. Ten sam prompt / tekst co przy pierwszej generacji'
Add-Line ''
Add-Line 'Master / Match / Enhance nie uzupelnia brakujacej muzyki.'

if ($SaveReport) {
    $reportPath = Join-Path $outDir ($inName + '_repaint_' + (Get-Date -Format 'yyyyMMdd_HHmmss') + '.txt')
    $reportLines | Set-Content -LiteralPath $reportPath -Encoding UTF8
    Write-Host ''
    Write-Host ('Raport: ' + $reportPath) -ForegroundColor Green
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('/select,', $reportPath) } catch {}
}

if ($OpenAce) {
    Write-Host ''
    Write-Host 'Otwieram ACE-Step...' -ForegroundColor Cyan
    Start-Process 'http://127.0.0.1:7870/'
}

Write-Host ''
