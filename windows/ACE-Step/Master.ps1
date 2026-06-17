#Requires -Version 5.1
<#
.SYNOPSIS
  Audio mastering przez ffmpeg loudnorm (2-pass). Drag & drop na Master.bat.
.PARAMETER InputFile
  Plik wejsciowy (mp3/wav/flac/opus/m4a).
.PARAMETER TargetLufs
  Docelowy Integrated LUFS. Default -12 (klubowo). Spotify=-14, Apple=-16, loud war=-9.
.PARAMETER TargetPeak
  Maksymalny True Peak w dBFS. Default -1.
.PARAMETER TargetLra
  Docelowy Loudness Range. Default 4 (typowe dla EDM/synthwave).
.EXAMPLE
  .\Master.ps1 -InputFile track.mp3 -TargetLufs -10
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [double]$TargetLufs = -12,
    [double]$TargetPeak = -1,
    [double]$TargetLra  = 4
)

# ffmpeg pisze info do stderr — w PS 5.1 z 'Stop' to wywala. 'Continue' ignoruje stderr-jako-error.
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Host "ERROR: Plik nie istnieje: $InputFile" -ForegroundColor Red
    exit 1
}

$ffmpeg = Join-Path $PSScriptRoot 'python\ffmpeg.exe'
if (-not (Test-Path $ffmpeg)) {
    $ffmpeg = Join-Path $PSScriptRoot 'ffmpeg\bin\ffmpeg.exe'
    if (-not (Test-Path $ffmpeg)) { Write-Host "ERROR: brak ffmpeg.exe w python\ ani ffmpeg\bin\" -ForegroundColor Red; exit 1 }
}

$inFull   = (Resolve-Path -LiteralPath $InputFile).Path
$inDir    = Split-Path -Parent $inFull
$inName   = [System.IO.Path]::GetFileNameWithoutExtension($inFull)
$inExt    = [System.IO.Path]::GetExtension($inFull).ToLower()
$outFile  = Join-Path $inDir "${inName}_mastered$inExt"

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " ffmpeg loudnorm 2-pass mastering" -ForegroundColor Cyan
Write-Host " Input:    $inFull"
Write-Host " Target:   I=$TargetLufs LUFS, TP=$TargetPeak dBFS, LRA=$TargetLra LU"
Write-Host " Output:   $outFile"
Write-Host "============================================" -ForegroundColor Cyan

# --- Pass 1: pomiar
Write-Host ""
Write-Host "==> Pass 1 (analiza)" -ForegroundColor Yellow
$filter1 = "loudnorm=I=$($TargetLufs):TP=$($TargetPeak):LRA=$($TargetLra):print_format=json"
$pass1 = & $ffmpeg -hide_banner -nostats -i $inFull -af $filter1 -f null - 2>&1 | Out-String

# Wyciagamy JSON ze stderr — zwykle ostatni blok {...}
$matches = [regex]::Matches($pass1, '(?s)\{\s*"input_i"[^}]*\}')
if ($matches.Count -eq 0) {
    Write-Host "ERROR: nie wyciagnalem JSON z ffmpeg loudnorm pass1." -ForegroundColor Red
    Write-Host $pass1
    exit 2
}
$measured = $matches[$matches.Count - 1].Value | ConvertFrom-Json
Write-Host "    measured I:        $($measured.input_i) LUFS"
Write-Host "    measured TP:       $($measured.input_tp) dBFS"
Write-Host "    measured LRA:      $($measured.input_lra) LU"
Write-Host "    measured threshold:$($measured.input_thresh) LUFS"

# --- Pass 2: aplikacja z linear=true (najczystsze)
Write-Host ""
Write-Host "==> Pass 2 (mastering)" -ForegroundColor Yellow
$filter2 = "loudnorm=I=$($TargetLufs):TP=$($TargetPeak):LRA=$($TargetLra)" +
           ":measured_I=$($measured.input_i)" +
           ":measured_TP=$($measured.input_tp)" +
           ":measured_LRA=$($measured.input_lra)" +
           ":measured_thresh=$($measured.input_thresh)" +
           ":offset=$($measured.target_offset)" +
           ":linear=true:print_format=summary"

$encArgs = switch ($inExt) {
    '.mp3'  { @('-c:a','libmp3lame','-b:a','256k') }
    '.opus' { @('-c:a','libopus','-b:a','192k') }
    '.m4a'  { @('-c:a','aac','-b:a','256k') }
    '.aac'  { @('-c:a','aac','-b:a','256k') }
    '.flac' { @('-c:a','flac','-compression_level','5') }
    default { @('-c:a','pcm_s16le') }  # .wav i inne
}

$args = @('-hide_banner','-nostats','-y','-i',$inFull,'-af',$filter2) + $encArgs + @($outFile)
& $ffmpeg @args 2>&1 | Tee-Object -Variable pass2log | Out-Null

# --- Weryfikacja: zmierz wynikowy plik
Write-Host ""
Write-Host "==> Weryfikacja wyjsciowego pliku" -ForegroundColor Yellow
$verify = & $ffmpeg -hide_banner -nostats -i $outFile -af 'ebur128=peak=true' -f null - 2>&1 | Out-String
$summary = $verify -split "`n" | Where-Object {
    $_ -match 'Integrated loudness|^\s+I:|True peak|^\s+Peak:|^\s+LRA:'
} | Select-Object -Unique
foreach ($l in $summary) { Write-Host "    $($l.Trim())" -ForegroundColor Gray }

$outSize = [math]::Round((Get-Item -LiteralPath $outFile).Length / 1KB, 1)
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " GOTOWE.  Plik: $outFile  ($outSize KB)" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
