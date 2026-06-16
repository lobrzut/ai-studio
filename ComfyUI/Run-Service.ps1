#Requires -Version 5.1
# Uruchamiany w tle przez ..\Start.ps1
$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
Set-Location $Root

if (Test-Path (Join-Path $Root 'gpu_profile.env')) {
    Get-Content (Join-Path $Root 'gpu_profile.env') | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
        $k, $v = $_ -split '=', 2
        [Environment]::SetEnvironmentVariable($k.Trim(), $v.Trim(), 'Process')
    }
}

$env:PYTORCH_HIP_ALLOC_CONF = 'expandable_segments:True'
$env:MIOPEN_FIND_MODE = 'FAST'
$env:TOKENIZERS_PARALLELISM = 'false'
if (-not $env:PORT)        { $env:PORT = '7871' }
if (-not $env:SERVER_NAME) { $env:SERVER_NAME = '127.0.0.1' }

$Py = Join-Path $Root 'python\python.exe'
if (-not (Test-Path $Py)) { Write-Error "Brak $Py - uruchom Install.bat"; exit 1 }

$env:PYTHONPATH = Join-Path $Root 'ComfyUI'
Set-Location (Join-Path $Root 'ComfyUI')

# ComfyUI 0.22+: missing nodes / install w nowym Managerze (pip comfyui_manager).
# Bez --enable-manager stary ComfyUI-Manager w custom_nodes czesto nie pokazuje missing nodes.
$mainArgs = @(
    '-u', 'main.py',
    '--listen', $env:SERVER_NAME,
    '--port', $env:PORT,
    '--enable-manager'
)
if ($env:COMFY_MANAGER_LEGACY_UI -eq '1') {
    $mainArgs += '--enable-manager-legacy-ui'
}
& $Py @mainArgs
