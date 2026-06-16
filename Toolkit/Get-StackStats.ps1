#Requires -Version 5.1
# Zuzycie RAM/CPU (i VRAM per PID gdy dostepne) procesow AI Studio Portable.

function Get-StackProcessGpuVramMap {
    $map = @{}
    try {
        $samples = (Get-Counter -Counter '\GPU Process Memory(*)\Dedicated Usage' -ErrorAction Stop).CounterSamples
        foreach ($s in $samples) {
            if ($s.Path -match 'pid_(\d+)') {
                $pid = [int]$matches[1]
                $mb = [int][math]::Round($s.CookedValue / 1MB, 0)
                if ($map.ContainsKey($pid)) { $map[$pid] += $mb } else { $map[$pid] = $mb }
            }
        }
    } catch { }
    return $map
}

function Measure-StackStats([string]$Root) {
    $gpuVramByPid = Get-StackProcessGpuVramMap
    $aceDir  = Join-Path $Root 'ACE-Step'
    $comfyDir = Join-Path $Root 'ComfyUI'

    $ace  = @{ label = 'ACE-Step'; running = $false; ram_mb = 0; ram_private_mb = 0; vram_mb = $null; cpu_pct = $null; pids = @() }
    $comfy = @{ label = 'ComfyUI'; running = $false; ram_mb = 0; ram_private_mb = 0; vram_mb = $null; cpu_pct = $null; pids = @() }
    $launchers = @{ ram_mb = 0; count = 0 }

    $totalRam = 0
    $totalPrivate = 0
    $totalVram = 0
    $vramKnown = $false
    $cpuSum = 0.0
    $cpuCount = 0

    $procs = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -in @('python.exe', 'powershell.exe') -and $_.ExecutablePath -and
            ($_.ExecutablePath.StartsWith($Root, [StringComparison]::OrdinalIgnoreCase) -or
             ($_.CommandLine -and $_.CommandLine -match [regex]::Escape($Root)))
        }

    foreach ($cim in $procs) {
        $p = Get-Process -Id $cim.ProcessId -ErrorAction SilentlyContinue
        if (-not $p) { continue }

        $ws = [int][math]::Round($p.WorkingSet64 / 1MB, 0)
        $pm = [int][math]::Round($p.PrivateMemorySize64 / 1MB, 0)
        $vram = $null
        if ($gpuVramByPid.ContainsKey($p.Id)) {
            $vram = $gpuVramByPid[$p.Id]
            $totalVram += $vram
            $vramKnown = $true
        }

        $cpuPct = $null
        try {
            $perf = Get-CimInstance Win32_PerfFormattedData_PerfProc_Process -Filter "IDProcess=$($p.Id)" -ErrorAction Stop |
                Select-Object -First 1
            if ($perf) {
                $cpuPct = [math]::Round([double]$perf.PercentProcessorTime, 1)
                $cpuSum += $cpuPct
                $cpuCount++
            }
        } catch { }

        $exe = $cim.ExecutablePath
        $cmd = $cim.CommandLine

        if ($cmd -and $cmd -match 'Run-Service\.ps1' -and $cmd -notmatch 'Dashboard-Server') {
            $launchers.ram_mb += $ws
            $launchers.count++
            continue
        }
        if ($cmd -and $cmd -match 'Dashboard-Server') { continue }

        if ($exe -and $exe.StartsWith($aceDir, [StringComparison]::OrdinalIgnoreCase)) {
            $ace.running = $true
            $ace.ram_mb += $ws
            $ace.ram_private_mb += $pm
            if ($null -ne $vram) { if ($null -eq $ace.vram_mb) { $ace.vram_mb = 0 }; $ace.vram_mb += $vram }
            if ($null -ne $cpuPct) { if ($null -eq $ace.cpu_pct) { $ace.cpu_pct = 0 }; $ace.cpu_pct += $cpuPct }
            $ace.pids += $p.Id
        } elseif ($exe -and $exe.StartsWith($comfyDir, [StringComparison]::OrdinalIgnoreCase)) {
            $comfy.running = $true
            $comfy.ram_mb += $ws
            $comfy.ram_private_mb += $pm
            if ($null -ne $vram) { if ($null -eq $comfy.vram_mb) { $comfy.vram_mb = 0 }; $comfy.vram_mb += $vram }
            if ($null -ne $cpuPct) { if ($null -eq $comfy.cpu_pct) { $comfy.cpu_pct = 0 }; $comfy.cpu_pct += $cpuPct }
            $comfy.pids += $p.Id
        } else {
            $totalRam += $ws
            $totalPrivate += $pm
        }
    }

    $totalRam += $ace.ram_mb + $comfy.ram_mb
    $totalPrivate += $ace.ram_private_mb + $comfy.ram_private_mb

    @{
        ram_mb           = $totalRam
        ram_private_mb   = $totalPrivate
        vram_mb          = if ($vramKnown) { $totalVram } else { $null }
        vram_available   = $vramKnown
        cpu_pct          = if ($cpuCount -gt 0) { [math]::Round($cpuSum, 1) } else { $null }
        ace              = $ace
        comfy            = $comfy
        launchers_mb     = $launchers.ram_mb
        process_count    = $ace.pids.Count + $comfy.pids.Count
        updated_at       = (Get-Date).ToString('o')
    }
}
