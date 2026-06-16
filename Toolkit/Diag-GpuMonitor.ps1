#Requires -Version 5.1
Write-Host '=== Registry GPUs ===' -ForegroundColor Cyan
Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DriverDesc } |
    Select-Object DriverDesc, @{N='VRAM_GB';E={
        $v = $_.'HardwareInformation.qwMemorySize'
        if ($v) { [math]::Round($v/1GB, 2) } else { $null }
    }} | Format-Table -AutoSize

Write-Host '=== WMI ===' -ForegroundColor Cyan
Get-CimInstance Win32_VideoController | Select-Object Name, @{N='VRAM_GB';E={[math]::Round($_.AdapterRAM/1GB,2)}} | Format-Table -AutoSize

Write-Host '=== PDH VRAM ===' -ForegroundColor Cyan
Get-Counter '\GPU Adapter Memory(*)\Dedicated Usage' -ErrorAction SilentlyContinue |
    Select-Object -ExpandProperty CounterSamples |
    Select-Object InstanceName, @{N='GB';E={[math]::Round($_.CookedValue/1GB,2)}} | Format-Table -AutoSize

Write-Host '=== gpu_profile.env ===' -ForegroundColor Cyan
Get-Content (Join-Path (Split-Path $PSScriptRoot -Parent) 'ComfyUI\gpu_profile.env') -ErrorAction SilentlyContinue

Write-Host '=== ROCm tools ===' -ForegroundColor Cyan
$hip = Get-ChildItem 'C:\Program Files\AMD\ROCm' -Recurse -Filter hipInfo.exe -ErrorAction SilentlyContinue | Select-Object -First 1
if ($hip) { Write-Host $hip.FullName; & $hip.FullName 2>&1 | Select-Object -First 12 } else { Write-Host 'hipInfo: not found' }
Get-ChildItem 'C:\Program Files\AMD\ROCm' -Recurse -Filter 'amd-smi*.exe' -ErrorAction SilentlyContinue | Select-Object -First 3 FullName

Write-Host '=== ADL DLL ===' -ForegroundColor Cyan
@('C:\Windows\System32\atiadlxx.dll','C:\Windows\System32\atiadlxy.dll') | ForEach-Object { if (Test-Path $_) { Write-Host "OK $_" } else { Write-Host "MISSING $_" } }
