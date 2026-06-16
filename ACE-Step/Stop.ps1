[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'

$Root   = $PSScriptRoot
$PyExe  = Join-Path $Root 'python\python.exe'
$Port   = 7870
$killed = New-Object System.Collections.Generic.HashSet[int]

# 1) Procesy nasluchujace na porcie
Get-NetTCPConnection -LocalPort $Port -State Listen | ForEach-Object {
    if ($_.OwningProcess -and $killed.Add([int]$_.OwningProcess)) {
        Write-Host ("Stop port {0}: PID {1}" -f $Port, $_.OwningProcess)
        Stop-Process -Id $_.OwningProcess -Force
    }
}

# 2) Wszystkie python.exe z naszego folderu
Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" | ForEach-Object {
    if ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) {
        if ($killed.Add([int]$_.ProcessId)) {
            Write-Host ("Stop portable python: PID {0}" -f $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force
        }
    }
}

# 3) Okno cmd z tytulem launchera
Get-CimInstance Win32_Process -Filter "Name = 'cmd.exe'" | ForEach-Object {
    if ($_.CommandLine -and $_.CommandLine -match 'Start\.bat') {
        if ($killed.Add([int]$_.ProcessId)) {
            Write-Host ("Stop launcher cmd: PID {0}" -f $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force
        }
    }
}

if ($killed.Count -eq 0) {
    Write-Host "ACE-Step nie byl uruchomiony."
} else {
    Write-Host ("Zatrzymano {0} procesow." -f $killed.Count) -ForegroundColor Green
}
Start-Sleep -Seconds 1
