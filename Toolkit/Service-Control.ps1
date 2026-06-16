#Requires -Version 5.1
# Start/Stop ACE (:7870), Comfy (:7871), hub (:7880). Caly stack zyje tylko gdy dziala tray.

function Get-StudioRoot {
    if ($PSScriptRoot -match 'Toolkit$') { return Split-Path $PSScriptRoot -Parent }
    return $PSScriptRoot
}

function Test-StudioPort([int]$Port) {
    return [bool](Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Test-PortableReady([string]$Dir) {
    (Test-Path (Join-Path $Dir 'python\python.exe')) -and (Test-Path (Join-Path $Dir 'gpu_profile.env'))
}

function Clear-ServiceLog([string]$path) {
    if (-not (Test-Path -LiteralPath $path)) { return }
    try { Remove-Item -LiteralPath $path -Force } catch {
        $bak = "$path.bak"
        if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force -EA SilentlyContinue }
        Rename-Item -LiteralPath $path -NewName (Split-Path -Leaf $bak) -Force -EA SilentlyContinue
    }
}

function Start-StudioService([Parameter(Mandatory)][ValidateSet('Ace', 'Comfy')][string]$Name) {
    $Root   = Get-StudioRoot
    $LogDir = Join-Path $Root 'logs'
    New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

    $cfg = if ($Name -eq 'Ace') {
        @{ Label = 'ACE-Step'; Dir = Join-Path $Root 'ACE-Step'; Port = 7870; Log = 'acestep' }
    } else {
        @{ Label = 'ComfyUI'; Dir = Join-Path $Root 'ComfyUI'; Port = 7871; Log = 'comfyui' }
    }

    if (-not (Test-PortableReady $cfg.Dir)) {
        throw "$($cfg.Label) nie zainstalowany. Uruchom Install.bat."
    }
    if (Test-StudioPort $cfg.Port) {
        return "$($cfg.Label) juz dziala (:$($cfg.Port))."
    }

    $run = Join-Path $cfg.Dir 'Run-Service.ps1'
    if (-not (Test-Path -LiteralPath $run)) { throw "Brak $run" }

    $outLog = Join-Path $LogDir "$($cfg.Log).stdout.log"
    $errLog = Join-Path $LogDir "$($cfg.Log).stderr.log"
    Clear-ServiceLog $outLog
    Clear-ServiceLog $errLog

    $p = Start-Process -FilePath 'powershell.exe' `
        -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $run) `
        -WorkingDirectory $cfg.Dir `
        -WindowStyle Hidden `
        -RedirectStandardOutput $outLog `
        -RedirectStandardError $errLog `
        -PassThru

    return "$($cfg.Label) startuje (launcher PID $($p.Id)). Port :$($cfg.Port) za 30-90 s. Log: logs\$($cfg.Log).stderr.log"
}

function Stop-StudioService([Parameter(Mandatory)][ValidateSet('Ace', 'Comfy')][string]$Name) {
    $Root = Get-StudioRoot
    $cfg = if ($Name -eq 'Ace') {
        @{ Label = 'ACE-Step'; Dir = Join-Path $Root 'ACE-Step'; Port = 7870 }
    } else {
        @{ Label = 'ComfyUI'; Dir = Join-Path $Root 'ComfyUI'; Port = 7871 }
    }

    $stopPs1 = Join-Path $cfg.Dir 'Stop.ps1'
    if (-not (Test-Path -LiteralPath $stopPs1)) { throw "Brak $stopPs1" }

    & powershell -NoProfile -ExecutionPolicy Bypass -File $stopPs1 | Out-Null
    Start-Sleep -Seconds 1

    if (Test-StudioPort $cfg.Port) {
        return "$($cfg.Label): port :$($cfg.Port) nadal zajety. Sprobuj Zwolnij GPU (hard) lub restart PC."
    }
    return "$($cfg.Label) zatrzymany (:$($cfg.Port) wolny)."
}

function Start-StudioServicesBoth {
    $m = @()
    if (-not (Test-StudioPort 7871)) { $m += (Start-StudioService -Name Comfy) }
    else { $m += 'ComfyUI juz dziala.' }
    if (-not (Test-StudioPort 7870)) { $m += (Start-StudioService -Name Ace) }
    else { $m += 'ACE-Step juz dziala.' }
    return ($m -join ' ')
}

function Stop-StudioServicesBoth {
    $m = @()
    $m += (Stop-StudioService -Name Comfy)
    $m += (Stop-StudioService -Name Ace)
    return ($m -join ' ')
}

function Get-TrayLockPath {
    return Join-Path (Get-StudioRoot) '.run\tray.lock'
}

function Get-TrayLockPid {
    $path = Get-TrayLockPath
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $line = (Get-Content -LiteralPath $path -TotalCount 1 -ErrorAction SilentlyContinue)
    if ($line -match '^\d+$') { return [int]$line }
    return $null
}

function Test-TrayRunning {
    $lockPid = Get-TrayLockPid
    if (-not $lockPid) { return $false }
    return [bool](Get-Process -Id $lockPid -ErrorAction SilentlyContinue)
}

function Test-TrayHealthy {
    $lockPid = Get-TrayLockPid
    if (-not $lockPid) { return $false }
    if (-not (Get-Process -Id $lockPid -ErrorAction SilentlyContinue)) { return $false }
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$lockPid" -ErrorAction SilentlyContinue
    if (-not $p -or -not $p.CommandLine) { return $false }
    return ($p.CommandLine -match 'Dashboard-Tray\.ps1')
}

function Write-TrayLock {
    $runDir = Join-Path (Get-StudioRoot) '.run'
    New-Item -ItemType Directory -Force -Path $runDir | Out-Null
    Set-Content -LiteralPath (Get-TrayLockPath) -Value $PID -Encoding ASCII -NoNewline
}

function Remove-TrayLock {
    $path = Get-TrayLockPath
    if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue }
}

function Test-AnyStudioPortBusy {
    return (Test-StudioPort 7870) -or (Test-StudioPort 7871) -or (Test-StudioPort 7880)
}

function Stop-DashboardHub {
    $Root = Get-StudioRoot
    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.CommandLine -and $_.CommandLine -match 'Dashboard-Server\.ps1' -and $_.CommandLine -match [regex]::Escape($Root)) {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
    Get-NetTCPConnection -LocalPort 7880 -State Listen -ErrorAction SilentlyContinue |
        ForEach-Object {
            if ($_.OwningProcess) { Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue }
        }
    Start-Sleep -Seconds 1
}

function Stop-StudioPortListeners {
    $killed = New-Object System.Collections.Generic.HashSet[int]
    foreach ($port in @(7870, 7871, 7880)) {
        Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.OwningProcess -and $killed.Add([int]$_.OwningProcess)) {
                Stop-Process -Id $_.OwningProcess -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Stop-StudioOrphanProcesses {
    $Root = Get-StudioRoot
    $killed = New-Object System.Collections.Generic.HashSet[int]

    Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) {
            if ($killed.Add([int]$_.ProcessId)) {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Get-CimInstance Win32_Process -Filter "Name = 'powershell.exe'" -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.CommandLine -and $_.CommandLine -match 'Run-Service\.ps1' -and $_.CommandLine -match [regex]::Escape($Root)) {
            if ($killed.Add([int]$_.ProcessId)) {
                Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Stop-StudioAll {
    $ErrorActionPreference = 'SilentlyContinue'
    try { Stop-StudioService -Name Comfy } catch { }
    try { Stop-StudioService -Name Ace } catch { }
    Stop-DashboardHub
    Stop-StudioPortListeners
    Stop-StudioOrphanProcesses
    $runJson = Join-Path (Get-StudioRoot) '.run\last-start.json'
    if (Test-Path -LiteralPath $runJson) { Remove-Item -LiteralPath $runJson -Force }
    Start-Sleep -Seconds 1
}

function Stop-TrayHost {
    $lockPid = Get-TrayLockPid
    if ($lockPid -and $lockPid -ne $PID) {
        Stop-Process -Id $lockPid -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 500
    }
    Remove-TrayLock
}

function Repair-OrphanStackBeforeTray {
    $lockPid = Get-TrayLockPid
    if ($lockPid -and $lockPid -ne $PID) {
        if (Get-Process -Id $lockPid -ErrorAction SilentlyContinue) {
            Stop-Process -Id $lockPid -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 400
        }
        Remove-TrayLock
    }
    if (Test-AnyStudioPortBusy) {
        Stop-StudioAll
        Remove-TrayLock
        Start-Sleep -Seconds 2
    } else {
        Remove-TrayLock
    }
    return $true
}

function Start-StudioHub {
    $Root    = Get-StudioRoot
    $Toolkit = Join-Path $Root 'Toolkit'
    if (Test-StudioPort 7880) { return 'Dashboard hub juz dziala (:7880).' }
    $restart = Join-Path $Toolkit 'Restart-Dashboard.ps1'
    if (-not (Test-Path -LiteralPath $restart)) { throw "Brak $restart" }
    $env:AI_STUDIO_TRAY_OWNER = $PID
    & powershell -NoProfile -ExecutionPolicy Bypass -File $restart | Out-Null
    Remove-Item Env:AI_STUDIO_TRAY_OWNER -ErrorAction SilentlyContinue
    if (Test-StudioPort 7880) { return 'Dashboard hub uruchomiony (:7880).' }
    throw 'Dashboard hub nie wstal. Sprawdz logs\dashboard.stderr.log'
}

function Ensure-DashboardHub {
    if (-not (Test-TrayRunning)) {
        throw 'Brak ikony tray. Uruchom Open-Dashboard.bat lub Start.bat (stack zyje tylko z tray).'
    }
    return (Start-StudioHub)
}
