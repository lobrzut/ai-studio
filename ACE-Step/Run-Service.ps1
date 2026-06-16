#Requires -Version 5.1
# Uruchamiany w tle przez ..\Start.ps1 (bez pause, bez otwierania przegladarki).
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

$env:HF_HOME = Join-Path $Root 'models'
$env:HUGGINGFACE_HUB_CACHE = Join-Path $Root 'models\hub'
$env:TRANSFORMERS_CACHE = Join-Path $Root 'models\transformers'
$env:MODELSCOPE_CACHE = Join-Path $Root 'models\modelscope'
$env:ACESTEP_LM_BACKEND = 'pt'
$env:ACESTEP_GENERATION_TIMEOUT = '1800'
$env:TORCH_COMPILE_BACKEND = 'eager'
$env:MIOPEN_FIND_MODE = 'FAST'
$env:TOKENIZERS_PARALLELISM = 'false'
$env:PYTORCH_HIP_ALLOC_CONF = 'expandable_segments:True'
$env:ACESTEP_ROCM_DTYPE = 'bfloat16'

if (-not $env:PORT)         { $env:PORT = '7870' }
if (-not $env:SERVER_NAME)  { $env:SERVER_NAME = '127.0.0.1' }

# ACESTEP_LAZY_INIT=1 w gpu_profile.env: UI online, modele na GPU dopiero przy pierwszej generacji (mniej VRAM na idle)
$initService = 'true'
if ($env:ACESTEP_LAZY_INIT -eq '1') { $initService = 'false' }

$Py = Join-Path $Root 'python\python.exe'
if (-not (Test-Path $Py)) { Write-Error "Brak $Py - uruchom Install.bat"; exit 1 }

Set-Location (Join-Path $Root 'ACE-Step-1.5')
& $Py -u acestep\acestep_v15_pipeline.py `
    --port $env:PORT --server-name $env:SERVER_NAME --language en `
    --config_path acestep-v15-turbo `
    --lm_model_path acestep-5Hz-lm-1.7B `
    --offload_to_cpu false `
    --init_service $initService `
    --backend pt
