[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'SilentlyContinue'
$Root   = $PSScriptRoot
$Port   = 7871
$killed = New-Object System.Collections.Generic.HashSet[int]
Get-NetTCPConnection -LocalPort $Port -State Listen | ForEach-Object {
    if ($_.OwningProcess -and $killed.Add([int]$_.OwningProcess)) {
        Write-Host ("Stop port {0}: PID {1}" -f $Port, $_.OwningProcess)
        Stop-Process -Id $_.OwningProcess -Force
    }
}
Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" | ForEach-Object {
    if ($_.ExecutablePath -and $_.ExecutablePath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase)) {
        if ($killed.Add([int]$_.ProcessId)) {
            Write-Host ("Stop portable python: PID {0}" -f $_.ProcessId)
            Stop-Process -Id $_.ProcessId -Force
        }
    }
}
if ($killed.Count -eq 0) { Write-Host "ComfyUI nie byl uruchomiony." }
else { Write-Host ("Zatrzymano {0} procesow." -f $killed.Count) -ForegroundColor Green }
Start-Sleep -Seconds 1
