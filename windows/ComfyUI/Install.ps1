#Requires -Version 5.1
<#
.SYNOPSIS
  ComfyUI portable installer z natywnym wsparciem ACE-Step 1.5 (Windows + AMD ROCm).
.DESCRIPTION
  Bootstrap: embeddable Python 3.12 + MinGit + klon ComfyUI + ROCm nightly stack
  (gfx103X dla RDNA2) + FFmpeg + ACE-Step 1.5 All-in-One model.
  Port 7871 (zeby nie kolidowac z ACE-Step Gradio na 7870 ani Brain na 7860).
#>
[CmdletBinding()]
param(
    [ValidateSet('auto','amd','nvidia','cpu')]
    [string]$GpuVendor = 'auto',
    [string]$HsaOverride,
    [switch]$Force,
    [switch]$DesktopShortcuts,
    [switch]$SkipModel  # przyspieszone debugowanie bez pobierania modelu
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Pinned versions ---
$PyVer       = '3.12.7'
$MinGitTag   = 'v2.47.0.windows.2'
$MinGitFile  = 'MinGit-2.47.0.2-64-bit.zip'
$ComfyRepo   = 'https://github.com/comfyanonymous/ComfyUI.git'
$ManagerRepo = 'https://github.com/ltdrdata/ComfyUI-Manager.git'
$CudaIndex   = 'https://download.pytorch.org/whl/cu124'
$CpuIndex    = 'https://download.pytorch.org/whl/cpu'
$RocmBase    = 'https://repo.radeon.com/rocm/windows/rocm-rel-7.2'
$RocmNightlyGfx103X    = 'https://rocm.nightlies.amd.com/v2-staging/gfx103X-dgpu'
$RocmNightlyGfx103XVer = '7.12.0a20260204'
$FFmpegUrl  = 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-win64-gpl-shared-7.1.zip'
$AceStepModelUrl = 'https://huggingface.co/Comfy-Org/ace_step_1.5_ComfyUI_files/resolve/main/checkpoints/ace_step_1.5_turbo_aio.safetensors'

# --- Layout ---
$Root        = $PSScriptRoot
$PyDir       = Join-Path $Root 'python'
$PyExe       = Join-Path $PyDir 'python.exe'
$GitDir      = Join-Path $Root 'PortableGit'
$GitExe      = Join-Path $GitDir 'cmd\git.exe'
$ComfyDir    = Join-Path $Root 'ComfyUI'
$ModelsDir   = Join-Path $ComfyDir 'models'
$CheckpointsDir = Join-Path $ModelsDir 'checkpoints'
$FFmpegDir   = Join-Path $Root 'ffmpeg'
$Profile     = Join-Path $Root 'gpu_profile.env'

function Write-Step($m)  { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Info($m)  { Write-Host "    $m" -ForegroundColor Gray }
function Write-Ok($m)    { Write-Host "    OK: $m" -ForegroundColor Green }
function Write-Warn2($m) { Write-Host "    !! $m" -ForegroundColor Yellow }
function Fail($m)        { Write-Host "ERROR: $m" -ForegroundColor Red; if ($Host.Name -eq 'ConsoleHost') { Read-Host 'Enter aby zamknac' }; exit 1 }

function Download-File([string]$Url, [string]$Dest) {
    Write-Info "Pobieram: $Url"
    $tmp = "$Dest.partial"
    try {
        $client = New-Object System.Net.WebClient
        $client.Headers.Add('User-Agent','ComfyUI-Portable-Installer/1.0')
        $client.DownloadFile($Url, $tmp)
        if (Test-Path $Dest) { Remove-Item -LiteralPath $Dest -Force }
        Move-Item -LiteralPath $tmp -Destination $Dest
    } catch {
        if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force }
        throw
    }
}

function Detect-Gpu {
    $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -and ($_.Name -notmatch 'Basic Display|Remote Display|Idd|Virtual|Mirage|Parsec|Citrix') }
    foreach ($g in $gpus) {
        if ($g.Name -match 'NVIDIA|GeForce|RTX|GTX|Quadro|Tesla|Titan') {
            return @{ Vendor='nvidia'; Name=$g.Name; HsaOverride=''; Gfx='' }
        }
    }
    foreach ($g in $gpus) {
        $n = $g.Name
        if ($n -notmatch 'Radeon|AMD|FirePro') { continue }
        $hsa = ''; $gfx = 'unknown'
        switch -Regex ($n) {
            'RX\s*9070|RX\s*9060'                                { $hsa='12.0.1'; $gfx='gfx1201' }
            'RX\s*7900|W7900|W7800|PRO\s*W7900|PRO\s*W7800'       { $hsa='11.0.0'; $gfx='gfx1100' }
            'RX\s*7800|RX\s*7700'                                  { $hsa='11.0.1'; $gfx='gfx1101' }
            'RX\s*7600'                                            { $hsa='11.0.2'; $gfx='gfx1102' }
            'RX\s*6900|RX\s*6800|RX\s*6750|RX\s*6700|W6800'       { $hsa='10.3.0'; $gfx='gfx1030' }
            'RX\s*6650|RX\s*6600'                                  { $hsa='10.3.0'; $gfx='gfx1032' }
            'RX\s*6500|RX\s*6400'                                  { $hsa='10.3.0'; $gfx='gfx1034' }
            default                                                { $hsa='10.3.0' }
        }
        return @{ Vendor='amd'; Name=$n; HsaOverride=$hsa; Gfx=$gfx }
    }
    return @{ Vendor='cpu'; Name='No supported discrete GPU detected'; HsaOverride=''; Gfx='' }
}

function Ensure-Python {
    if (Test-Path $PyExe) {
        $v = & $PyExe -c "import sys; print('%d.%d.%d'%sys.version_info[:3])" 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) { Write-Ok "Python: $v"; return }
        Write-Warn2 "Istniejacy python/ uszkodzony — przebuduje."
        Remove-Item -LiteralPath $PyDir -Recurse -Force
    }
    Write-Step "Embeddable Python $PyVer"
    $zip = Join-Path $env:TEMP "python-$PyVer-embed-amd64.zip"
    if (-not (Test-Path $zip)) { Download-File "https://www.python.org/ftp/python/$PyVer/python-$PyVer-embed-amd64.zip" $zip }
    New-Item -ItemType Directory -Force -Path $PyDir | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $PyDir -Force
    $pth = Get-ChildItem -Path $PyDir -Filter 'python*._pth' | Select-Object -First 1
    if (-not $pth) { Fail "Brak python*._pth" }
    $lines = Get-Content -LiteralPath $pth.FullName
    $patched = $lines | ForEach-Object { if ($_ -match '^\s*#\s*import\s+site\s*$') { 'import site' } else { $_ } }
    Set-Content -LiteralPath $pth.FullName -Value $patched -Encoding ASCII
    $getPip = Join-Path $PyDir 'get-pip.py'
    Download-File 'https://bootstrap.pypa.io/get-pip.py' $getPip
    & $PyExe $getPip --no-warn-script-location
    if ($LASTEXITCODE -ne 0) { Fail "get-pip.py nie zadzialal." }
    Remove-Item -LiteralPath $getPip -Force
    & $PyExe -m pip install --upgrade pip setuptools wheel | Out-Null
    Write-Ok "Python + pip gotowe."
}

function Ensure-Git {
    if (Test-Path $GitExe) { Write-Ok "MinGit: $GitExe"; return }
    Write-Step "MinGit (portable)"
    $zip = Join-Path $env:TEMP $MinGitFile
    if (-not (Test-Path $zip)) { Download-File "https://github.com/git-for-windows/git/releases/download/$MinGitTag/$MinGitFile" $zip }
    if (Test-Path $GitDir) { Remove-Item -LiteralPath $GitDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $GitDir | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $GitDir -Force
    Write-Ok "MinGit gotowy."
}

function Patch-PythonPth {
    # Embeddable Python ignoruje PYTHONPATH gdy istnieje *._pth — dorzucamy ..\ComfyUI do sys.path
    $pth = Get-ChildItem -Path $PyDir -Filter 'python*._pth' | Select-Object -First 1
    if (-not $pth) { return }
    $c = Get-Content -LiteralPath $pth.FullName -Raw
    if ($c -match '\.\.\\ComfyUI') { return }  # juz dodane
    $c = $c -replace '(?m)^(\.)\s*$', "`$1`r`n..\ComfyUI"
    Set-Content -LiteralPath $pth.FullName -Value $c -NoNewline -Encoding ASCII
    Write-Ok "_pth: dodano ..\ComfyUI do sys.path"
}

function Ensure-ComfyUI {
    Write-Step "Repozytorium ComfyUI"
    if (Test-Path (Join-Path $ComfyDir '.git')) {
        Write-Info "ComfyUI/ istnieje — git pull..."
        Push-Location $ComfyDir
        try { & $GitExe pull --ff-only } finally { Pop-Location }
    } else {
        if (Test-Path $ComfyDir) {
            $items = Get-ChildItem -LiteralPath $ComfyDir -Force -ErrorAction SilentlyContinue
            if ($items) { Fail "$ComfyDir istnieje i nie jest puste." }
        }
        & $GitExe clone --depth 1 $ComfyRepo $ComfyDir
        if ($LASTEXITCODE -ne 0) { Fail "git clone ComfyUI nieudany." }
    }
    Write-Ok "ComfyUI gotowe: $ComfyDir"
}

function Ensure-ComfyUI-Manager {
    Write-Step "ComfyUI-Manager (custom_nodes)"
    $nodesDir = Join-Path $ComfyDir 'custom_nodes'
    $mgrDir   = Join-Path $nodesDir 'ComfyUI-Manager'
    New-Item -ItemType Directory -Force -Path $nodesDir | Out-Null

    if (Test-Path (Join-Path $mgrDir '.git')) {
        Write-Info "ComfyUI-Manager istnieje — git pull..."
        Push-Location $mgrDir
        try { & $GitExe pull --ff-only } finally { Pop-Location }
    } else {
        if (Test-Path $mgrDir) { Remove-Item -LiteralPath $mgrDir -Recurse -Force }
        & $GitExe clone --depth 1 $ManagerRepo $mgrDir
        if ($LASTEXITCODE -ne 0) { Fail "git clone ComfyUI-Manager nieudany." }
    }

    $req = Join-Path $mgrDir 'requirements.txt'
    if (Test-Path $req) {
        Write-Info "ComfyUI-Manager requirements.txt"
        & $PyExe -m pip install --no-cache-dir -r $req
        if ($LASTEXITCODE -ne 0) { Fail "ComfyUI-Manager deps nieudane." }
    }
    Write-Ok "ComfyUI-Manager: $mgrDir"
    Ensure-ManagerConfig
}

function Ensure-ComfyUI-ManagerCore {
    Write-Step 'ComfyUI Manager core (pip, --enable-manager)'
    $req = Join-Path $ComfyDir 'manager_requirements.txt'
    if (-not (Test-Path -LiteralPath $req)) {
        Write-Warn2 "Brak manager_requirements.txt - pomijam pip manager"
        return
    }
    & $PyExe -m pip install --no-cache-dir -r $req
    if ($LASTEXITCODE -ne 0) {
        Write-Warn2 'pip install comfyui_manager nieudany - missing nodes moze nie dzialac'
        return
    }
    $check = & $PyExe -c 'import comfyui_manager; print(comfyui_manager.__version__)' 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "comfyui_manager $check"
    } else {
        Write-Warn2 'import comfyui_manager nie dziala'
    }
}

function Ensure-ManagerConfig {
    # weak = pelna instalacja custom nodes / modeli z Managera (lokalne studio portable)
    Write-Step "ComfyUI-Manager config (security_level=weak)"
    $mgrDir = Join-Path $ComfyDir 'user\__manager'
    $configIni = Join-Path $mgrDir 'config.ini'
    New-Item -ItemType Directory -Force -Path $mgrDir | Out-Null

    if (-not (Test-Path $configIni)) {
        $template = @"
[default]
preview_method = none
git_exe =
use_uv = False
channel_url = https://raw.githubusercontent.com/ltdrdata/ComfyUI-Manager/main
share_option = all
bypass_ssl = False
file_logging = True
component_policy = workflow
update_policy = stable-comfyui
windows_selector_event_loop_policy = False
model_download_by_agent = False
downgrade_blacklist =
security_level = weak
always_lazy_install = False
network_mode = public
db_mode = cache

"@
        Set-Content -LiteralPath $configIni -Value $template -Encoding ASCII
        Write-Ok "Utworzono config.ini (security_level=weak)"
        return
    }

    $lines = Get-Content -LiteralPath $configIni
    $found = $false
    $out = foreach ($line in $lines) {
        if ($line -match '^\s*security_level\s*=') {
            $found = $true
            'security_level = weak'
        } else {
            $line
        }
    }
    if (-not $found) { $out += 'security_level = weak' }
    Set-Content -LiteralPath $configIni -Value $out -Encoding ASCII
    Write-Ok "security_level = weak"
}

function Ensure-FFmpeg {
    $marker = Join-Path $PyDir 'ffmpeg.exe'
    if (Test-Path $marker) { Write-Ok "FFmpeg juz w python\"; return }
    Write-Step "FFmpeg n7.1 shared (BtbN)"
    $zip = Join-Path $env:TEMP 'ffmpeg-n71-shared.zip'
    if (-not (Test-Path $zip)) { Download-File $FFmpegUrl $zip }
    $tmp = Join-Path $env:TEMP 'ffmpeg-extract-comfy'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (Test-Path $FFmpegDir) { Remove-Item $FFmpegDir -Recurse -Force }
    Move-Item -LiteralPath $inner.FullName -Destination $FFmpegDir
    $bin = Join-Path $FFmpegDir 'bin'
    foreach ($exe in 'ffmpeg.exe','ffprobe.exe','ffplay.exe') {
        $p = Join-Path $bin $exe
        if (Test-Path $p) { Copy-Item $p -Destination $PyDir -Force }
    }
    Get-ChildItem $bin -Filter '*.dll' | ForEach-Object { Copy-Item $_.FullName -Destination $PyDir -Force }
    Write-Ok "FFmpeg gotowy."
}

function Get-InstalledTorchBackend {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        $info = (& $PyExe -m pip show torch 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0 -or -not $info -or $info -match 'not found') { return $null }
        if ($info -match 'Version:\s*\S*?\+rocm')   { return 'amd' }
        if ($info -match 'Version:\s*\S*?\+cu\d+') { return 'nvidia' }
        if ($info -match 'Version:\s*\S*?\+cpu')   { return 'cpu' }
        return 'unknown'
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Install-Stack($gpu) {
    $current = Get-InstalledTorchBackend
    if ($current -and $current -ne $gpu.Vendor) {
        Write-Warn2 "Wykryto torch ($current) niezgodny z GPU ($($gpu.Vendor)) — przebuduje."
        & $PyExe -m pip uninstall -y torch torchaudio torchvision 2>$null | Out-Null
    } elseif ($current -eq $gpu.Vendor -and -not $Force) {
        Write-Info "torch+$current juz zainstalowany — pomijam ROCm SDK + PyTorch + ComfyUI deps."
        return
    }

    switch ($gpu.Vendor) {
        'amd' {
            $isRdna2 = $gpu.Gfx -match '^gfx103[012]$'
            if ($isRdna2) {
                Write-Step "ROCm nightly (gfx103X-dgpu) + PyTorch 2.10"
                $v = $RocmNightlyGfx103XVer
                $base = $RocmNightlyGfx103X
                $sdk = @(
                    "$base/rocm-$v.tar.gz",
                    "$base/rocm_sdk_core-$v-py3-none-win_amd64.whl",
                    "$base/rocm_sdk_devel-$v-py3-none-win_amd64.whl",
                    "$base/rocm_sdk_libraries_gfx103x_dgpu-$v-py3-none-win_amd64.whl"
                )
                $torchWheels = @(
                    "$base/torch-2.10.0%2Brocm$v-cp312-cp312-win_amd64.whl",
                    "$base/torchaudio-2.10.0%2Brocm$v-cp312-cp312-win_amd64.whl",
                    "$base/torchvision-0.25.0%2Brocm$v-cp312-cp312-win_amd64.whl"
                )
            } else {
                Write-Step "ROCm 7.2 SDK + PyTorch (RDNA3/4)"
                $sdk = @(
                    "$RocmBase/rocm_sdk_core-7.2.0.dev0-py3-none-win_amd64.whl",
                    "$RocmBase/rocm_sdk_devel-7.2.0.dev0-py3-none-win_amd64.whl",
                    "$RocmBase/rocm_sdk_libraries_custom-7.2.0.dev0-py3-none-win_amd64.whl",
                    "$RocmBase/rocm-7.2.0.dev0.tar.gz"
                )
                $torchWheels = @(
                    "$RocmBase/torch-2.9.1+rocmsdk20260116-cp312-cp312-win_amd64.whl",
                    "$RocmBase/torchaudio-2.9.1+rocmsdk20260116-cp312-cp312-win_amd64.whl",
                    "$RocmBase/torchvision-0.24.1+rocmsdk20260116-cp312-cp312-win_amd64.whl"
                )
            }
            & $PyExe -m pip install --no-cache-dir @sdk
            if ($LASTEXITCODE -ne 0) { Fail "ROCm SDK install nieudany." }
            & $PyExe -m pip install --no-cache-dir @torchWheels
            if ($LASTEXITCODE -ne 0) { Fail "PyTorch ROCm install nieudany." }
        }
        'nvidia' {
            Write-Step "PyTorch CUDA 12.4"
            & $PyExe -m pip install --no-cache-dir torch torchaudio torchvision --index-url $CudaIndex
            if ($LASTEXITCODE -ne 0) { Fail "PyTorch CUDA install nieudany." }
        }
        'cpu' {
            Write-Warn2 "Tryb CPU — ComfyUI dziala ale generacja muzyki BARDZO wolno."
            & $PyExe -m pip install --no-cache-dir torch torchaudio torchvision --index-url $CpuIndex
            if ($LASTEXITCODE -ne 0) { Fail "PyTorch CPU install nieudany." }
        }
    }

    # ComfyUI requirements
    Write-Step "ComfyUI dependencies (requirements.txt)"
    $req = Join-Path $ComfyDir 'requirements.txt'
    if (-not (Test-Path $req)) { Fail "Brak $req" }
    & $PyExe -m pip install --no-cache-dir -r $req
    if ($LASTEXITCODE -ne 0) { Fail "ComfyUI deps install nieudany." }

    # Extras potrzebne dla ACE-Step audio
    & $PyExe -m pip install --no-cache-dir hf_xet
    Write-Ok "Stos PyTorch + ComfyUI ($($gpu.Vendor)) zainstalowany."
}

function Patch-TorchaudioSave {
    # Identyczny patch jak w ACE-Step-Portable: bypass save_with_torchcodec na soundfile/subprocess ffmpeg.
    $f = Join-Path $PyDir 'Lib\site-packages\torchaudio\_torchcodec.py'
    if (-not (Test-Path $f)) { Write-Info "torchaudio: plik nie istnieje (pomijam)"; return }
    $content = Get-Content -LiteralPath $f -Raw
    if ($content -match 'PATCH dla ROCm Windows: torchcodec/FFmpeg') { Write-Ok "torchaudio: juz zapatchowane"; return }
    if ($content -notmatch [regex]::Escape('# Import torchcodec here to provide clear error if not available')) {
        Write-Warn2 "torchaudio: struktura zmieniona — pomijam patch"
        return
    }
    $py = @'
import sys, re, io
path = sys.argv[1]
src = io.open(path, 'r', encoding='utf-8').read()
new_body = """    # === PATCH dla ROCm Windows: torchcodec/FFmpeg ABI nie zgadza sie z dostepnym BtbN buildem. ===
    import os as _os
    import subprocess as _sp
    import tempfile as _tf
    from pathlib import Path as _Path
    import soundfile as _sf

    if not isinstance(src, torch.Tensor):
        raise ValueError(f"Expected src to be a torch.Tensor, got {type(src)}")
    if src.dtype != torch.float32:
        src = src.float()
    if sample_rate <= 0:
        raise ValueError(f"sample_rate must be positive, got {sample_rate}")
    if src.ndim == 1:
        data = src.detach().cpu().numpy()
    elif src.ndim == 2:
        if channels_first:
            data = src.detach().cpu().numpy().T
        else:
            data = src.detach().cpu().numpy()
    else:
        raise ValueError(f"Expected 1D or 2D tensor, got {src.ndim}D tensor")
    uri_str = str(uri)
    ext = _Path(uri_str).suffix.lower().lstrip('.')
    fmt = (format or ext or 'wav').lower()
    soundfile_formats = {'wav', 'flac', 'ogg', 'aiff', 'aif', 'au'}
    ffmpeg_formats = {'mp3', 'aac', 'opus', 'm4a', 'mp4'}
    if fmt in soundfile_formats:
        sf_fmt = 'AIFF' if fmt in {'aif', 'aiff'} else fmt.upper()
        _sf.write(uri_str, data, int(sample_rate), format=sf_fmt)
        return
    if fmt in ffmpeg_formats:
        with _tf.NamedTemporaryFile(suffix='.wav', delete=False) as _t:
            _tmp = _t.name
        try:
            _sf.write(_tmp, data, int(sample_rate), format='WAV', subtype='FLOAT')
            codec_map = {'mp3': 'libmp3lame', 'aac': 'aac', 'opus': 'libopus', 'm4a': 'aac', 'mp4': 'aac'}
            cmd = ['ffmpeg', '-y', '-hide_banner', '-loglevel', 'error',
                   '-i', _tmp, '-codec:a', codec_map[fmt]]
            if compression is not None and isinstance(compression, (int, float)):
                cmd += ['-b:a', str(int(compression))]
            cmd.append(uri_str)
            _sp.run(cmd, check=True, capture_output=True, timeout=300)
        finally:
            try:
                _os.unlink(_tmp)
            except OSError:
                pass
        return
    _sf.write(uri_str, data, int(sample_rate))
"""
pattern = re.compile(
    r'(?P<head>def save_with_torchcodec\([^)]*\)[^:]*:\s*\n(?:[ \t]+"""[\s\S]*?"""\s*\n)?)'
    r'(?:[ \t]+# Import torchcodec here[\s\S]*?)(?=\n(?:def |@|\Z))',
    re.MULTILINE
)
m = pattern.search(src)
if not m:
    print("MATCH_FAIL", file=sys.stderr); sys.exit(2)
new_src = src[:m.start()] + m.group('head') + new_body + src[m.end():]
io.open(path, 'w', encoding='utf-8', newline='').write(new_src)
print("OK")
'@
    $tmpPy = Join-Path $env:TEMP 'patch_torchaudio_comfy.py'
    Set-Content -LiteralPath $tmpPy -Value $py -Encoding UTF8
    $out = & $PyExe $tmpPy $f 2>&1
    Remove-Item $tmpPy -Force
    if ($LASTEXITCODE -ne 0) { Write-Warn2 "torchaudio patch nieudany: $out"; return }
    Write-Ok "torchaudio: save_with_torchcodec -> soundfile/subprocess ffmpeg.exe"
}

function Patch-VectorQuantize {
    # vector_quantize_pytorch zwykle nie jest instalowane w ComfyUI base — pomin jesli brak
    $f = Join-Path $PyDir 'Lib\site-packages\vector_quantize_pytorch\lookup_free_quantization.py'
    if (-not (Test-Path $f)) { Write-Info "vqp: nie zainstalowane (ComfyUI go nie potrzebuje)"; return }
    $content = Get-Content -LiteralPath $f -Raw
    if ($content -match 'except ImportError:\s*\r?\n\s*dist_nn = None') { Write-Ok "vqp: juz zapatchowane"; return }
    $patched = $content -replace 'from torch\.distributed import nn as dist_nn',
        "try:`r`n    from torch.distributed import nn as dist_nn`r`nexcept ImportError:`r`n    dist_nn = None  # ROCm Windows"
    Set-Content -LiteralPath $f -Value $patched -NoNewline
    Write-Ok "vqp: shim torch.distributed.nn"
}

function Apply-CodePatches {
    Write-Step "Patche kodu (ROCm Windows)"
    Patch-TorchaudioSave
    Patch-VectorQuantize
}

function Ensure-AceStepModel {
    if ($SkipModel) { Write-Info "Pominieto pobieranie modelu (-SkipModel)"; return }
    $target = Join-Path $CheckpointsDir 'ace_step_1.5_turbo_aio.safetensors'
    if (Test-Path $target) {
        $sz = (Get-Item $target).Length
        if ($sz -gt 1GB) { Write-Ok "ACE-Step model juz pobrany ($([math]::Round($sz/1MB,0)) MB)"; return }
    }
    New-Item -ItemType Directory -Force -Path $CheckpointsDir | Out-Null
    Write-Step "ACE-Step 1.5 All-in-One model (~4-5 GB)"
    Download-File $AceStepModelUrl $target
    Write-Ok "Model pobrany: $target"
}

function SmokeTest($gpu) {
    Write-Step "Smoke-test PyTorch"
    if ($gpu.HsaOverride) { $env:HSA_OVERRIDE_GFX_VERSION = $gpu.HsaOverride }
    $out = & $PyExe -c "import torch; print('cuda_available=', torch.cuda.is_available()); print('hip=', getattr(torch.version,'hip',None)); print('device=', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'CPU')" 2>&1
    Write-Host $out
    if ($out -match 'cuda_available=\s*True') { Write-Ok "GPU widoczne." }
    elseif ($gpu.Vendor -eq 'cpu') { Write-Ok "OK (CPU)" }
    else { Write-Warn2 "GPU NIE widoczne. Sprawdz sterownik AMD." }
}

function Write-Launchers($gpu) {
    Write-Step "Wrappery Start/Stop + profil GPU"
    $profileText = @"
# Auto-wygenerowane przez Install.ps1
GPU_VENDOR=$($gpu.Vendor)
GPU_NAME=$($gpu.Name)
GPU_GFX=$($gpu.Gfx)
HSA_OVERRIDE_GFX_VERSION=$($gpu.HsaOverride)
"@
    Set-Content -LiteralPath $Profile -Value $profileText -Encoding ASCII

    $startBat = Join-Path $Root 'Start.bat'
    $startContent = @'
@echo off
setlocal enabledelayedexpansion
title ComfyUI Portable (ACE-Step 1.5)
cd /d "%~dp0"

REM === Wczytaj gpu_profile.env ===
if exist gpu_profile.env (
    for /f "usebackq tokens=1,* delims==" %%a in ("gpu_profile.env") do (
        set "_k=%%a"
        if not "!_k!"=="" if not "!_k:~0,1!"=="#" set "!_k!=%%b"
    )
)

REM === ROCm env ===
set PYTORCH_HIP_ALLOC_CONF=expandable_segments:True
set MIOPEN_FIND_MODE=FAST
set TOKENIZERS_PARALLELISM=false

REM === Server ===
if not defined PORT set PORT=7871
if not defined SERVER_NAME set SERVER_NAME=127.0.0.1

set PY=%~dp0python\python.exe
if not exist "%PY%" ( echo BRAK python\python.exe & pause & exit /b 1 )

echo ============================================
echo  ComfyUI Portable + ACE-Step 1.5
echo  GPU:    %GPU_NAME% [%GPU_VENDOR% / %GPU_GFX%]
echo  HSA:    %HSA_OVERRIDE_GFX_VERSION%
echo  URL:    http://%SERVER_NAME%:%PORT%
echo ============================================

REM Otworz przegladarke po 30s
start "" /b cmd /c "timeout /t 30 /nobreak >nul & start http://%SERVER_NAME%:%PORT%"

cd ComfyUI
REM Embeddable Python NIE dodaje CWD do sys.path automatycznie — wymuszamy
set PYTHONPATH=%~dp0ComfyUI
"%PY%" -u main.py --listen %SERVER_NAME% --port %PORT%

echo.
echo (Serwer zatrzymany.)
pause
endlocal
'@
    Set-Content -LiteralPath $startBat -Value $startContent -Encoding ASCII
    Write-Ok "Start.bat (port 7871)"

    $stopPs1 = Join-Path $Root 'Stop.ps1'
    $stopContent = @'
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
'@
    Set-Content -LiteralPath $stopPs1 -Value $stopContent -Encoding UTF8

    $stopBat = Join-Path $Root 'Stop.bat'
    Set-Content -LiteralPath $stopBat -Value @"
@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop.ps1"
timeout /t 2 /nobreak >nul
"@ -Encoding ASCII
    Write-Ok "Stop.bat / Stop.ps1"
}

# =============================================================================
Write-Host ''
Write-Host '============================================' -ForegroundColor Cyan
Write-Host ' ComfyUI Portable + ACE-Step 1.5 Installer' -ForegroundColor Cyan
Write-Host " Folder: $Root" -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan

$build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
Write-Info "Windows build: $build"

if ($Force -and (Test-Path $PyDir)) {
    Write-Warn2 "-Force: usuwam $PyDir"
    Remove-Item -LiteralPath $PyDir -Recurse -Force
}

Write-Step "Detekcja GPU"
$gpu = if ($GpuVendor -eq 'auto') { Detect-Gpu } else {
    @{ Vendor=$GpuVendor; Name="(wymuszone: $GpuVendor)"; HsaOverride=''; Gfx='' }
}
Write-Info "GPU: $($gpu.Name) [$($gpu.Vendor) / $($gpu.Gfx) / HSA=$($gpu.HsaOverride)]"
if ($HsaOverride) { $gpu.HsaOverride = $HsaOverride }

Ensure-Python
Ensure-Git
Ensure-ComfyUI
Patch-PythonPth
Install-Stack $gpu
Ensure-ComfyUI-Manager
Ensure-ComfyUI-ManagerCore
Ensure-FFmpeg
Apply-CodePatches
Ensure-AceStepModel
SmokeTest $gpu
Write-Launchers $gpu

Write-Host ''
Write-Host '============================================' -ForegroundColor Green
Write-Host ' GOTOWE.' -ForegroundColor Green
Write-Host '============================================' -ForegroundColor Green
Write-Host " >> Start: dwuklik 'Start.bat' (port 7871)"
Write-Host " >> Stop:  dwuklik 'Stop.bat'"
Write-Host " >> UI:    http://127.0.0.1:7871"
Write-Host ''
Write-Host ' Manager: po wczytaniu workflow -> menu Manager (sidebar) -> Install missing nodes.'
Write-Host ' Stary przycisk z custom_nodes moze byc pusty na ComfyUI 0.22+ bez --enable-manager.'
Write-Host ''
Write-Host " W ComfyUI: dodaj node 'Load Checkpoint' -> wybierz 'ace_step_1.5_turbo_aio.safetensors'."
Write-Host " Workflow szablon dla ACE-Step: docs.comfy.org/tutorials/audio/ace-step/ace-step-v1-5"
