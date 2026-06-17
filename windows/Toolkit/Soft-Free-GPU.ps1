#Requires -Version 5.1
<#
.SYNOPSIS
  Lagodnie zwalnia VRAM ComfyUI (proces zostaje, port :7871 online).
  POST /free { unload_models, free_memory } gdy kolejka jest pusta.
#>
[CmdletBinding()]
param(
    [switch]$Quiet,
    [switch]$Force,
    [int]$ComfyPort = 7871
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Toolkit = $PSScriptRoot
$Root    = Split-Path $Toolkit -Parent
. (Join-Path $Toolkit 'Get-GpuStats.ps1')

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "    OK: $m" -ForegroundColor Green }
function Write-Warn2($m) { Write-Host "    !! $m" -ForegroundColor Yellow }

function Show-Vram([string]$label) {
    $g = Measure-GpuStats $Root
    if ($g.available) {
        $pct = if ($g.vram_total_mb -gt 0) { [int][math]::Round(100 * $g.vram_used_mb / $g.vram_total_mb) } else { 0 }
        Write-Host "    ${label}: VRAM $($g.vram_used_mb)/$($g.vram_total_mb) MB ($pct%)" -ForegroundColor Gray
    }
}

$base = "http://127.0.0.1:$ComfyPort"
Write-Host ''
Write-Host 'ComfyUI soft free VRAM (serwis zostaje wlaczony)' -ForegroundColor Cyan
Show-Vram 'Przed'

try {
    $q = Invoke-RestMethod -Uri "$base/queue" -TimeoutSec 4
    $run = @($q.queue_running).Count
    $pend = @($q.queue_pending).Count
    if (($run -gt 0 -or $pend -gt 0) -and -not $Force) {
        Write-Warn2 "Kolejka zajeta (running=$run pending=$pend). Uzyj -Force lub poczekaj."
        exit 2
    }
    if ($Force -and ($run -gt 0 -or $pend -gt 0)) {
        Write-Warn2 'Force: clear kolejki + interrupt'
        Invoke-RestMethod -Method POST -Uri "$base/interrupt" -Body '{}' -ContentType 'application/json' -TimeoutSec 4 | Out-Null
        Invoke-RestMethod -Method POST -Uri "$base/queue" -Body '{"clear":true}' -ContentType 'application/json' -TimeoutSec 4 | Out-Null
        Start-Sleep -Seconds 1
    }
} catch {
    Write-Warn2 "ComfyUI nie odpowiada na :$ComfyPort - $($_.Exception.Message)"
    exit 1
}

Write-Step 'ComfyUI: unload_models + free_memory'
try {
    $body = '{"unload_models":true,"free_memory":true}'
    Invoke-RestMethod -Method POST -Uri "$base/free" -Body $body -ContentType 'application/json' -TimeoutSec 8 | Out-Null
    Write-Ok 'Zadanie zwolnienia VRAM wyslane (efekt za kilka s)'
} catch {
    Write-Warn2 $_.Exception.Message
    exit 1
}

Start-Sleep -Seconds 4
Show-Vram 'Po'
Write-Host ''
Write-Host 'ComfyUI nadal na http://127.0.0.1:'$ComfyPort' — pierwsza generacja po zwolnieniu zaladuje modele od nowa.' -ForegroundColor Green
if (-not $Quiet) { Read-Host 'Enter' }
