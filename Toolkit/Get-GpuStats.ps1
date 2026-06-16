#Requires -Version 5.1
# Odczyt GPU przez Windows Performance Counters (AMD/NVIDIA). Uzywane przez Dashboard-Server.ps1.

function Read-GpuNameFromProfile([string]$Root) {
    foreach ($rel in @('ComfyUI\gpu_profile.env', 'ACE-Step\gpu_profile.env')) {
        $p = Join-Path $Root $rel
        if (-not (Test-Path -LiteralPath $p)) { continue }
        foreach ($line in Get-Content -LiteralPath $p -ErrorAction SilentlyContinue) {
            if ($line -match '^\s*GPU_NAME\s*=\s*(.+)\s*$') { return $matches[1].Trim() }
        }
    }
    return 'GPU'
}

function Get-VramTotalMb([string]$gpuName, [int]$usedMb) {
    if ($gpuName -match '6800|6700\s*XT|16\s*GB') { return 16384 }
    if ($gpuName -match '6900|7900\s*XTX|24\s*GB') { return 24576 }
    if ($gpuName -match '7900\s*XT|20\s*GB') { return 20480 }
    if ($usedMb -gt 0) { return [math]::Max(16384, $usedMb) }
    return 16384
}

function Measure-GpuStats([string]$Root) {
    $name = Read-GpuNameFromProfile $Root
    $out = @{
        available    = $false
        name         = $name
        util_pct     = $null
        vram_used_mb = $null
        vram_total_mb = (Get-VramTotalMb $name 0)
        source       = 'win_counters'
        updated_at   = (Get-Date).ToString('o')
    }

    try {
        $vramSamples = (Get-Counter -Counter '\GPU Adapter Memory(*)\Dedicated Usage' -ErrorAction Stop).CounterSamples
        if (-not $vramSamples -or $vramSamples.Count -eq 0) { return $out }

        $primary = $vramSamples | Sort-Object { $_.CookedValue } -Descending | Select-Object -First 1
        $usedMb = [int][math]::Round($primary.CookedValue / 1MB, 0)
        $out.vram_used_mb = $usedMb
        $out.vram_total_mb = Get-VramTotalMb $name $usedMb
        $out.available = $true

        $phys = '0'
        if ($primary.Path -match 'phys_(\d+)') { $phys = $matches[1] }

        $utilSamples = (Get-Counter -Counter '\GPU Engine(*)\Utilization Percentage' -ErrorAction SilentlyContinue).CounterSamples
        if ($utilSamples) {
            $physEsc = [regex]::Escape("phys_$phys")
            $physUtils = @($utilSamples | Where-Object {
                $_.Path -match $physEsc -and $_.Path -match 'engtype_(3[dD]|Compute|CCopy|Video Decode)'
            })
            if ($physUtils.Count -gt 0) {
                $maxUtil = ($physUtils | Measure-Object -Property CookedValue -Maximum).Maximum
                $out.util_pct = [int][math]::Round([double]$maxUtil, 0)
                if ($out.util_pct -lt 0) { $out.util_pct = 0 }
                if ($out.util_pct -gt 100) { $out.util_pct = 100 }
                $out.util_available = $true
            }
        }

        $stackScript = Join-Path $PSScriptRoot 'Get-StackStats.ps1'
        if (Test-Path -LiteralPath $stackScript) {
            . $stackScript
            $out.stack = Measure-StackStats $Root
        }
    } catch {
        $out.error = $_.Exception.Message
    }

    return $out
}
