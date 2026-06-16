#Requires -Version 5.1
# Uruchamiany z dashboardu - parametry z pliku JSON (bezpieczne spacje w sciezkach).
param(
    [Parameter(Mandatory = $true)]
    [string]$JobFile
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$jobDir = Split-Path -Parent $JobFile
if ($jobDir) { [void][System.IO.Directory]::CreateDirectory($jobDir) }
if (-not (Test-Path -LiteralPath $JobFile)) {
    Write-Host "ERROR: brak pliku job: $JobFile" -ForegroundColor Red
    Write-Host 'Uruchom Restart-Dashboard.bat i sprobuj ponownie.' -ForegroundColor Yellow
    exit 1
}

$job  = Get-Content -LiteralPath $JobFile -Raw -Encoding UTF8 | ConvertFrom-Json
$Root = [string]$job.root
$kind = [string]$job.kind
$path = [string]$job.path

if (-not $Root) { $Root = Split-Path $PSScriptRoot -Parent }
if (-not (Test-Path -LiteralPath $path)) {
    Write-Host "ERROR: plik nie istnieje: $path" -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host "=== AI Studio drop: $kind ===" -ForegroundColor Cyan
Write-Host " Plik: $path"
Write-Host ''

$Toolkit = Join-Path $Root 'Toolkit'
$exitCode = 0

switch ($kind) {
    'master' {
        $script = Join-Path $Root 'ACE-Step\Master.ps1'
        & $script -InputFile $path
        $exitCode = $LASTEXITCODE
    }
    'stems' {
        $script = Join-Path $Toolkit 'Stems.ps1'
        & $script -InputFile $path
        $exitCode = $LASTEXITCODE
    }
    'lyrics' {
        $script = Join-Path $Toolkit 'Lyrics.ps1'
        & $script -InputFile $path
        $exitCode = $LASTEXITCODE
    }
    'match' {
        $script = Join-Path $Toolkit 'Match.ps1'
        $ref = [string]$job.ref
        if ($ref) { & $script -Target $path -Reference $ref }
        else { & $script -Target $path }
        $exitCode = $LASTEXITCODE
    }
    'enhance' {
        $script = Join-Path $Toolkit 'Enhance.ps1'
        $mode = [string]$job.mode
        if (-not $mode) { $mode = 'light' }
        & $script -InputFile $path -Mode $mode
        $exitCode = $LASTEXITCODE
    }
    'silence' {
        $script = Join-Path $Toolkit 'Fix-Silence.ps1'
        & $script -InputFile $path
        $exitCode = $LASTEXITCODE
    }
    default {
        Write-Host "ERROR: nieznany kind: $kind" -ForegroundColor Red
        $exitCode = 1
    }
}

if ($exitCode -and $exitCode -ne 0) {
    Write-Host ''
    Write-Host "Zakonczono z kodem: $exitCode" -ForegroundColor Yellow
}

exit $exitCode
