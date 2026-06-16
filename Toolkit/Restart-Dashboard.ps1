#Requires -Version 5.1
# Zatrzymuje stary hub (port 7880 czesto PID 4 / http.sys) i uruchamia swiezy Dashboard-Server.ps1.
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Toolkit = $PSScriptRoot
$Root    = Split-Path $Toolkit -Parent
$Port    = 7880
$LogDir  = Join-Path $Root 'logs'
$Server  = Join-Path $Toolkit 'Dashboard-Server.ps1'

function Stop-DashboardProcesses {
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.CommandLine -and $_.CommandLine -match 'Dashboard-Server\.ps1' -and $_.CommandLine -match [regex]::Escape($Root)) {
                Write-Host "  Stop dashboard PID $($_.ProcessId)" -ForegroundColor Gray
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
}

function Test-PortListen([int]$p) {
    [bool](Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Test-HubUploadApi {
    try {
        $s = Invoke-RestMethod "http://127.0.0.1:$Port/api/status" -TimeoutSec 4
        $hubOk = ($null -ne $s.hub -and $s.hub.upload -eq $true -and $s.hub.api_version -ge 8)
        $comfyOutOk = ($null -ne $s.comfy_outputs) -and ($s.hub.features -contains 'comfy_outputs')
        return ($hubOk -and $comfyOutOk)
    } catch { return $false }
}

New-Item -ItemType Directory -Force -Path $LogDir, (Join-Path $Toolkit 'inbox') | Out-Null

Write-Host '==> Restart dashboard hub' -ForegroundColor Cyan
Stop-DashboardProcesses
Start-Sleep -Seconds 2

$deadline = (Get-Date).AddSeconds(15)
while ((Get-Date) -lt $deadline) {
    Stop-DashboardProcesses
    if (-not (Test-PortListen $Port)) { break }
    Start-Sleep -Seconds 1
}

if (Test-PortListen $Port) {
    Write-Host 'WARN: port 7880 nadal zajety — moze stary http.sys. Sprobuj Stop.bat + Start.bat.' -ForegroundColor Yellow
}

$outLog = Join-Path $LogDir 'dashboard.stdout.log'
$errLog = Join-Path $LogDir 'dashboard.stderr.log'
foreach ($log in @($outLog, $errLog)) {
    if (Test-Path -LiteralPath $log) {
        try { Remove-Item -LiteralPath $log -Force } catch {
            $bak = "$log.bak"
            if (Test-Path $bak) { Remove-Item $bak -Force -EA SilentlyContinue }
            Rename-Item -LiteralPath $log -NewName (Split-Path -Leaf $bak) -Force -EA SilentlyContinue
        }
    }
}

Start-Process -FilePath 'powershell.exe' -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $Server
) -WorkingDirectory $Toolkit -WindowStyle Hidden `
    -RedirectStandardOutput $outLog -RedirectStandardError $errLog | Out-Null

$ready = $false
$deadline = (Get-Date).AddSeconds(45)
while ((Get-Date) -lt $deadline) {
    if (Test-HubUploadApi) { $ready = $true; break }
    Start-Sleep -Seconds 2
}

if ($ready) {
    Write-Host 'OK: Dashboard hub (upload + Comfy output) — http://127.0.0.1:7880/' -ForegroundColor Green
    exit 0
}

Write-Host 'WARN: Hub dziala ale brak API upload — sprawdz logs\dashboard.stderr.log' -ForegroundColor Yellow
exit 1
