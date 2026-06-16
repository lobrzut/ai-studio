#Requires -Version 5.1
<#
.SYNOPSIS
  Zwalnia GPU: zatrzymuje ComfyUI i ACE-Step (modele w VRAM), bez automatycznego restartu.
.PARAMETER RestartComfy
  Po zwolnieniu GPU uruchom ponownie tylko ComfyUI.
#>
[CmdletBinding()]
param(
    [switch]$RestartComfy,
    [switch]$Quiet,
    [int]$ApiTimeoutSec = 3
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Toolkit   = $PSScriptRoot
$Root      = Split-Path $Toolkit -Parent
$ComfyDir  = Join-Path $Root 'ComfyUI'
$LogDir    = Join-Path $Root 'logs'
$ComfyPort = 7871
$AcePort   = 7870

. (Join-Path $Toolkit 'Get-GpuStats.ps1')

function Write-Step($m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok($m)   { Write-Host "    OK: $m" -ForegroundColor Green }
function Write-Warn2($m) { Write-Host "    !! $m" -ForegroundColor Yellow }

function Show-Vram([string]$label) {
    try {
        $g = Measure-GpuStats $Root
        if ($g.available) {
            $pct = if ($g.vram_total_mb -gt 0) { [int][math]::Round(100 * $g.vram_used_mb / $g.vram_total_mb) } else { 0 }
            $u = if ($null -ne $g.util_pct) { $g.util_pct } else { '?' }
            Write-Host "    ${label}: VRAM $($g.vram_used_mb)/$($g.vram_total_mb) MB ($pct%), GPU load ${u}%" -ForegroundColor Gray
        }
    } catch { }
}

function Stop-ProcessTree([int]$ProcessId) {
    if ($ProcessId -le 4) { return }
    & taskkill.exe /PID $ProcessId /T /F 2>$null | Out-Null
    Start-Sleep -Milliseconds 300
    if (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue) {
        Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-HttpJson([string]$Method, [string]$Url, $Body = $null, [int]$TimeoutSec = 3) {
    try {
        $params = @{
            Uri             = $Url
            Method          = $Method
            TimeoutSec      = $TimeoutSec
            UseBasicParsing = $true
        }
        if ($Method -eq 'POST') {
            $params.ContentType = 'application/json'
            $params.Body = if ($null -ne $Body) { ($Body | ConvertTo-Json -Compress) } else { '{}' }
        }
        $null = Invoke-WebRequest @params
        return $true
    } catch {
        return $false
    }
}

function Stop-AiGpuStack {
    $killed = New-Object System.Collections.Generic.HashSet[int]

    Write-Step 'Przerwanie ComfyUI (interrupt + clear kolejki)'
    $base = "http://127.0.0.1:$ComfyPort"
    if (Invoke-HttpJson POST "$base/interrupt" @{} $ApiTimeoutSec) { Write-Ok '/interrupt' }
    if (Invoke-HttpJson POST "$base/queue" @{ clear = $true } $ApiTimeoutSec) { Write-Ok '/queue clear' }

    Write-Step 'Stop ComfyUI + ACE-Step (zwalnia VRAM)'
    foreach ($port in @($ComfyPort, $AcePort)) {
        Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.OwningProcess -and $killed.Add([int]$_.OwningProcess)) {
                Write-Host "    port $port -> PID $($_.OwningProcess)" -ForegroundColor Gray
                Stop-ProcessTree ([int]$_.OwningProcess)
            }
        }
    }

    Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        $exe = $_.ExecutablePath
        if (-not $exe) { return }
        if (-not $exe.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) { return }
        if ($killed.Add([int]$_.ProcessId)) {
            $tag = if ($exe -match 'ComfyUI') { 'ComfyUI' } elseif ($exe -match 'ACE-Step') { 'ACE-Step' } else { 'python' }
            Write-Host "    $tag PID $($_.ProcessId)" -ForegroundColor Gray
            Stop-ProcessTree ([int]$_.ProcessId)
        }
    }

    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.CommandLine -and $_.CommandLine -match 'Run-Service\.ps1' -and $_.CommandLine -match [regex]::Escape($Root)) {
            if ($killed.Add([int]$_.ProcessId)) {
                Write-Host "    launcher PID $($_.ProcessId)" -ForegroundColor Gray
                Stop-ProcessTree ([int]$_.ProcessId)
            }
        }
    }

    Start-Sleep -Seconds 2
    foreach ($port in @($ComfyPort, $AcePort)) {
        Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.OwningProcess -and $killed.Add([int]$_.OwningProcess)) {
                Write-Warn2 "Port $port nadal PID $($_.OwningProcess) - ponowny taskkill"
                Stop-ProcessTree ([int]$_.OwningProcess)
            }
        }
    }

    Start-Sleep -Seconds 2
    return $killed.Count
}

function Get-ZombiePython([string]$RootPath) {
    Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.ExecutablePath -and $_.ExecutablePath.StartsWith($RootPath, [StringComparison]::OrdinalIgnoreCase)
        } |
        ForEach-Object {
            $p = Get-Process -Id $_.ProcessId -ErrorAction SilentlyContinue
            if (-not $p) { return }
            if ($p.WorkingSet64 -lt 2MB -and $p.PrivateMemorySize64 -gt 500MB) {
                [PSCustomObject]@{ Pid = $p.Id; WS = [int]($p.WorkingSet64 / 1MB); PM = [int]($p.PrivateMemorySize64 / 1MB) }
            }
        }
}

function Start-ComfyService {
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
    $run = Join-Path $ComfyDir 'Run-Service.ps1'
    if (-not (Test-Path -LiteralPath $run)) { throw "Brak $run" }
    $proc = Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $run) `
        -WorkingDirectory $ComfyDir `
        -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $LogDir 'comfyui.stdout.log') `
        -RedirectStandardError (Join-Path $LogDir 'comfyui.stderr.log') `
        -PassThru
    Write-Ok "ComfyUI startuje (launcher PID $($proc.Id))"
}

Write-Host ''
Write-Host '============================================' -ForegroundColor Magenta
Write-Host ' AI Studio - zwolnij GPU (Comfy + ACE)' -ForegroundColor Magenta
Write-Host '============================================' -ForegroundColor Magenta

Show-Vram 'Przed'
$n = Stop-AiGpuStack
if ($n -eq 0) { Write-Warn2 'Brak procesow AI Studio.' }
else { Write-Ok "Zatrzymano $n procesow." }

Show-Vram 'Po'

$comfyStill = [bool](Get-NetTCPConnection -LocalPort $ComfyPort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
$aceStill   = [bool](Get-NetTCPConnection -LocalPort $AcePort -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
$zombies    = @(Get-ZombiePython $Root)
if ($zombies.Count -gt 0) {
    $zList = ($zombies | ForEach-Object { "PID $($_.Pid)" }) -join ', '
    Write-Warn2 "Zombie python: $zList (uzyj Stop.bat lub restart PC)"
}
if ($comfyStill -or $aceStill) {
    Write-Warn2 "Porty zajete: Comfy=$comfyStill ACE=$aceStill - uruchom Stop.bat"
}

if ($RestartComfy) {
    Write-Step 'Restart ComfyUI'
    Start-ComfyService
} else {
    Write-Host ''
    Write-Host 'Comfy i ACE wylaczone. VRAM powinno spasc w ciagu kilku sekund.' -ForegroundColor Green
    Write-Host 'Ponowny start: Start stack (nie klikaj Restart Comfy jesli chcesz tylko zwolnic GPU).' -ForegroundColor Gray
}

Write-Host ''
if (-not $Quiet -and $Host.Name -eq 'ConsoleHost') {
    Read-Host 'Nacisnij Enter'
}
