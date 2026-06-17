#Requires -Version 5.1
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'

$Root      = $PSScriptRoot
$AceDir    = Join-Path $Root 'ACE-Step'
$ComfyDir  = Join-Path $Root 'ComfyUI'
$Toolkit   = Join-Path $Root 'Toolkit'
$issues    = New-Object System.Collections.Generic.List[string]
$ok        = New-Object System.Collections.Generic.List[string]
$warn      = New-Object System.Collections.Generic.List[string]

function Check([string]$label, [bool]$pass, [string]$failMsg) {
    if ($pass) { [void]$ok.Add($label) } else { [void]$issues.Add("$label - $failMsg") }
}
function Warn([string]$label, [string]$msg) { [void]$warn.Add("$label - $msg") }
function Test-PortUp([int]$port) {
    [bool](Get-NetTCPConnection -LocalPort $port -State Listen -EA SilentlyContinue | Select-Object -First 1)
}

Write-Host ''
Write-Host '=== AI Studio Portable - pelny audyt ===' -ForegroundColor Cyan
Write-Host ''

# --- Pliki ---
Check 'Install/Start/Stop/Restart' (
    (Test-Path (Join-Path $Root 'Install.ps1')) -and
    (Test-Path (Join-Path $Root 'Start.ps1')) -and
    (Test-Path (Join-Path $Root 'Restart.ps1'))
) 'brak launcherow'
Check 'Dashboard hub' (Test-Path (Join-Path $Toolkit 'Dashboard-Server.ps1')) 'brak'
Check 'Dashboard UI' (Test-Path (Join-Path $Toolkit 'Dashboard.html')) 'brak'
Check 'ACE python' (Test-Path (Join-Path $AceDir 'python\python.exe')) 'Install.bat'
Check 'Comfy python' (Test-Path (Join-Path $ComfyDir 'python\python.exe')) 'Install.bat'
Check 'ComfyUI-Manager' (Test-Path (Join-Path $ComfyDir 'ComfyUI\custom_nodes\ComfyUI-Manager')) 'Install ComfyUI'

$mgrIni = Join-Path $ComfyDir 'ComfyUI\user\__manager\config.ini'
if (Test-Path $mgrIni) {
    $c = Get-Content $mgrIni -Raw
    if ($c -match 'security_level\s*=\s*weak') { Check 'Manager security=weak' $true '' }
    else { Warn 'Manager security' 'nie weak - edytuj config.ini lub Install' }
}

# --- Post-prod skrypty ---
@(
    @('Master.ps1', 'ACE-Step\Master.ps1'),
    @('Stems.ps1', 'Toolkit\Stems.ps1'),
    @('Match.ps1', 'Toolkit\Match.ps1'),
    @('Lyrics.ps1', 'Toolkit\Lyrics.ps1'),
    @('Enhance.ps1', 'Toolkit\Enhance.ps1'),
    @('Enhance-Medium.py', 'Toolkit\Enhance-Medium.py')
) | ForEach-Object { Check $_[0] (Test-Path (Join-Path $Root $_[1])) "brak $($_[1])" }

$resemble = & (Join-Path $AceDir 'python\python.exe') -c "import resemble_enhance" 2>$null
if ($LASTEXITCODE -eq 0) { Check 'Enhance AI (resemble)' $true '' }
else { Warn 'Enhance AI (resemble)' 'brak — uruchom Install.bat (albo Toolkit\Install-Enhance-AI.bat)' }

# --- Modele ---
$ckpt = Join-Path $ComfyDir 'ComfyUI\models\checkpoints\ace_step_1.5_turbo_aio.safetensors'
if (Test-Path $ckpt) {
    Check 'Comfy ACE checkpoint' ((Get-Item $ckpt).Length -gt 1GB) 'za maly'
} else { Warn 'Comfy checkpoint' 'brak - Install ComfyUI' }

# --- Porty runtime ---
foreach ($p in @(7870, 7871, 7880)) {
    $listen = Get-NetTCPConnection -LocalPort $p -State Listen -EA SilentlyContinue | Select-Object -First 1
    $name = switch ($p) { 7870 {'ACE-Step'} 7871 {'ComfyUI'} 7880 {'Dashboard'} }
    if ($listen) {
        Check "Port $p $name LISTEN" $true ''
        try {
            $r = Invoke-WebRequest "http://127.0.0.1:$p/" -UseBasicParsing -TimeoutSec 6
            Check "HTTP $p" ($r.StatusCode -ge 200 -and $r.StatusCode -lt 500) "status $($r.StatusCode)"
        } catch { Warn "HTTP $p" $_.Exception.Message }
    } else {
        Warn "Port $p $name" 'nie dziala (uruchom Start.bat)'
    }
}

# --- API dashboard ---
if (Test-PortUp 7880) {
    try {
        $st = Invoke-RestMethod 'http://127.0.0.1:7880/api/status' -TimeoutSec 5
        Check 'API /api/status' ($null -ne $st.ace -and $null -ne $st.comfy) 'bledna odpowiedz'
    } catch { Warn 'API status' $_.Exception.Message }
}

Check 'Drop API (upload/run)' ((Test-Path (Join-Path $Toolkit 'app.js')) -and (Select-String -Path (Join-Path $Toolkit 'Dashboard-Server.ps1') -Pattern '/api/upload' -Quiet)) 'brak endpointow'

Write-Host ''
Write-Host ('OK (' + $ok.Count + '):') -ForegroundColor Green
$ok | ForEach-Object { Write-Host ('  [+] ' + $_) }
if ($warn.Count) {
    Write-Host ''
    Write-Host ('UWAGI (' + $warn.Count + '):') -ForegroundColor Yellow
    $warn | ForEach-Object { Write-Host ('  [~] ' + $_) }
}
if ($issues.Count) {
    Write-Host ''
    Write-Host ('BLOKERY (' + $issues.Count + '):') -ForegroundColor Red
    $issues | ForEach-Object { Write-Host ('  [-] ' + $_) }
    exit 1
}
Write-Host ''
Write-Host 'Audyt: brak blockerow.' -ForegroundColor Green
Write-Host 'Dashboard drop: http://127.0.0.1:7880 — przeciagnij audio na kafelki post-prod.' -ForegroundColor Gray
Write-Host ''
exit 0
