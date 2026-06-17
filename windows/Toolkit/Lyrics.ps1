#Requires -Version 5.1
<#
.SYNOPSIS
  OpenAI Whisper local: extract LRC/SRT/VTT/TXT lyrics z timestampami z audio.
.PARAMETER InputFile
  Plik audio (mp3/wav/flac/m4a/opus/ogg).
.PARAMETER Model
  Whisper model: tiny/base/small/medium/large-v3. Default: medium (~770 MB, dobra jakosc/szybkosc).
.PARAMETER Language
  Wymus jezyk (pl/en/de itd.). Pominiete = auto-detect.
.EXAMPLE
  .\Lyrics.ps1 -InputFile track.mp3 -Model large-v3 -Language pl
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [ValidateSet('','tiny','base','small','medium','large-v3','large-v2','large')]
    [string]$Model = '',
    [string]$Language = ''
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if (-not $Model) { $Model = 'medium' }

if (-not (Test-Path -LiteralPath $InputFile)) {
    Write-Host "ERROR: Plik nie istnieje: $InputFile" -ForegroundColor Red; exit 1
}

$AceRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\ACE-Step')).Path
$PyExe   = Join-Path $AceRoot 'python\python.exe'
$FFDir   = Join-Path $AceRoot 'ffmpeg\bin'
if (-not (Test-Path $PyExe)) { Write-Host "ERROR: brak $PyExe"; exit 1 }

$inFull  = (Resolve-Path -LiteralPath $InputFile).Path
$inName  = [System.IO.Path]::GetFileNameWithoutExtension($inFull)
$outDir  = Join-Path $PSScriptRoot 'Outputs\lyrics'
New-Item -ItemType Directory -Force -Path $outDir | Out-Null

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host " Whisper transcription" -ForegroundColor Cyan
Write-Host " Input:    $inFull"
Write-Host " Model:    $Model$(if ($Language) { " (lang: $Language)" } else { ' (auto-detect)' })"
Write-Host " Output:   $outDir\$inName.*"
Write-Host "============================================" -ForegroundColor Cyan

$env:PATH = $FFDir + ';' + $env:PATH
$env:HSA_OVERRIDE_GFX_VERSION = '10.3.0'
$env:PYTORCH_HIP_ALLOC_CONF = 'expandable_segments:True'

$wArgs = @('-m','whisper',$inFull,'--model',$Model,'--device','cuda',
           '--output_dir',$outDir,'--output_format','all','--word_timestamps','True')
if ($Language) { $wArgs += @('--language', $Language) }

Write-Host ""
Write-Host "==> Uruchamiam Whisper (pierwsze uzycie pobiera model)" -ForegroundColor Yellow
& $PyExe @wArgs 2>&1 | ForEach-Object { Write-Host $_ }

if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: whisper zwrocil exit $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

# Konwersja SRT -> LRC (whisper sam nie generuje LRC, format LRC jest popularny w odtwarzaczach muzyki)
$srt = Join-Path $outDir "$inName.srt"
$lrc = Join-Path $outDir "$inName.lrc"
if (Test-Path $srt) {
    $lrcLines = @()
    $cur = $null
    Get-Content $srt -Encoding UTF8 | ForEach-Object {
        if ($_ -match '^\s*\d+\s*$') { return }
        if ($_ -match '^(\d{2}):(\d{2}):(\d{2}),(\d{3})\s+-->') {
            $h=[int]$Matches[1]; $m=[int]$Matches[2]; $s=[int]$Matches[3]; $ms=[int]$Matches[4]
            $totalMin = $h*60 + $m
            $cur = "[{0:D2}:{1:D2}.{2:D2}]" -f $totalMin, $s, [int]($ms/10)
            return
        }
        if ($cur -and $_.Trim()) {
            $lrcLines += "$cur$($_.Trim())"
            $cur = $null
        }
    }
    Set-Content -LiteralPath $lrc -Value $lrcLines -Encoding UTF8
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host " GOTOWE.  Pliki w: $outDir" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
Get-ChildItem $outDir -Filter "$inName.*" | ForEach-Object {
    $sz = [math]::Round($_.Length / 1KB, 1)
    Write-Host "    $($_.Name)  ($sz KB)" -ForegroundColor Gray
}
