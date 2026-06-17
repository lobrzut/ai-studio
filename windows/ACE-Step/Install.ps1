#Requires -Version 5.1
<#
.SYNOPSIS
  ACE-Step 1.5 — portable installer (Windows, fully self-contained).

.DESCRIPTION
  - Wszystko siedzi w folderze tego skryptu (PSScriptRoot). Skopiuj folder na inny PC,
    uruchom Install.bat — skrypt sam wykryje GPU i doinstaluje wlasciwy stos.
  - Brak modyfikacji systemu: embeddable Python 3.12 + MinGit + site-packages w folderze.
    Bez admin / bez wpisow do PATH / bez rejestru.
  - Wspierane backendy: AMD ROCm 7.2 (RX 6000/7000/9000+), NVIDIA CUDA 12.4, CPU (slow).

.PARAMETER GpuVendor
  auto (default) | amd | nvidia | cpu — wymus konkretny backend.

.PARAMETER HsaOverride
  Wymus konkretne HSA_OVERRIDE_GFX_VERSION (np. 10.3.0 dla gfx1030, 11.0.0 dla gfx1100).

.PARAMETER Force
  Wyczysc python/ i postaw od zera (przy zmianie GPU lub uszkodzonej instalacji).

.PARAMETER DesktopShortcuts
  Dodatkowo polozy ikony Start/Stop na pulpicie. Skroty wskazuja na biezacy folder,
  wiec przy przeniesieniu folderu trzeba je odswiezyc (uruchom Install.ps1 jeszcze raz).

.NOTES
  Layout po instalacji:
    <Root>/python/             embeddable Python 3.12 + site-packages
    <Root>/PortableGit/        MinGit (do git clone/pull)
    <Root>/ACE-Step-1.5/       sklonowany upstream
    <Root>/models/             HF_HOME — modele (downloadowane przy 1. starcie)
    <Root>/gpu_profile.env     wynik detekcji GPU (czytany przez Start.bat)
    <Root>/Start.bat           uruchamia ACE-Step (auto-otwiera przegladarke)
    <Root>/Stop.bat            zabija proces
#>
[CmdletBinding()]
param(
    [ValidateSet('auto','amd','nvidia','cpu')]
    [string]$GpuVendor = 'auto',
    [string]$HsaOverride,
    [switch]$Force,
    [switch]$DesktopShortcuts
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# --- Pinned versions (bump tutaj jesli trzeba) ---------------------------------
$PyVer       = '3.12.7'
$MinGitTag   = 'v2.47.0.windows.2'
$MinGitFile  = 'MinGit-2.47.0.2-64-bit.zip'
$RepoUrl     = 'https://github.com/ace-step/ACE-Step-1.5.git'
$CudaIndex   = 'https://download.pytorch.org/whl/cu124'
$CpuIndex    = 'https://download.pytorch.org/whl/cpu'
# Oficjalne ROCm 7.2 wheels (gfx11xx/gfx12xx) — brak gfx10xx!
$RocmBase    = 'https://repo.radeon.com/rocm/windows/rocm-rel-7.2'
# Semi-oficjalne nightly AMD therock dla RDNA2 (gfx1030/1031/1032 = RX 6000)
$RocmNightlyGfx103X    = 'https://rocm.nightlies.amd.com/v2-staging/gfx103X-dgpu'
$RocmNightlyGfx103XVer = '7.12.0a20260204'   # bump tutaj jak wyjdzie nowsza
# FFmpeg shared (n7.1 stabilne ABI dla torchcodec na ROCm Windows)
$FFmpegUrl  = 'https://github.com/BtbN/FFmpeg-Builds/releases/download/latest/ffmpeg-n7.1-latest-win64-gpl-shared-7.1.zip'

# --- Layout --------------------------------------------------------------------
$Root      = $PSScriptRoot
$PyDir     = Join-Path $Root 'python'
$PyExe     = Join-Path $PyDir 'python.exe'
$GitDir    = Join-Path $Root 'PortableGit'
$GitExe    = Join-Path $GitDir 'cmd\git.exe'
$RepoDir   = Join-Path $Root 'ACE-Step-1.5'
$ModelsDir = Join-Path $Root 'models'
$FFmpegDir = Join-Path $Root 'ffmpeg'
$Profile   = Join-Path $Root 'gpu_profile.env'

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
        $client.Headers.Add('User-Agent','ACE-Step-Portable-Installer/1.0')
        $client.DownloadFile($Url, $tmp)
        if (Test-Path $Dest) { Remove-Item -LiteralPath $Dest -Force }
        Move-Item -LiteralPath $tmp -Destination $Dest
    } catch {
        if (Test-Path $tmp) { Remove-Item -LiteralPath $tmp -Force }
        throw
    }
}

# -----------------------------------------------------------------------------
# 0. GPU detection
# -----------------------------------------------------------------------------
function Detect-Gpu {
    $gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -and ($_.Name -notmatch 'Basic Display|Remote Display|Idd|Virtual|Mirage|Parsec|Citrix') }

    # NVIDIA pierwsza (gdy w systemie sa obie karty)
    foreach ($g in $gpus) {
        if ($g.Name -match 'NVIDIA|GeForce|RTX|GTX|Quadro|Tesla|Titan') {
            return @{ Vendor='nvidia'; Name=$g.Name; HsaOverride=''; Gfx='' }
        }
    }
    foreach ($g in $gpus) {
        $n = $g.Name
        if ($n -notmatch 'Radeon|AMD|FirePro') { continue }

        # Mapowanie na HSA_OVERRIDE_GFX_VERSION
        $hsa = ''; $gfx = 'unknown'
        switch -Regex ($n) {
            'RX\s*9070|RX\s*9060'                                { $hsa='12.0.1'; $gfx='gfx1201' }   # RDNA4
            'RX\s*7900|W7900|W7800|PRO\s*W7900|PRO\s*W7800'       { $hsa='11.0.0'; $gfx='gfx1100' }   # RDNA3 high
            'RX\s*7800|RX\s*7700'                                  { $hsa='11.0.1'; $gfx='gfx1101' }
            'RX\s*7600'                                            { $hsa='11.0.2'; $gfx='gfx1102' }
            'RX\s*6900|RX\s*6800|RX\s*6750|RX\s*6700|W6800'       { $hsa='10.3.0'; $gfx='gfx1030' }   # RDNA2 high (RX 6800!)
            'RX\s*6650|RX\s*6600'                                  { $hsa='10.3.0'; $gfx='gfx1032' }
            'RX\s*6500|RX\s*6400'                                  { $hsa='10.3.0'; $gfx='gfx1034' }   # niewspierane oficjalnie
            default                                                { $hsa='10.3.0' }
        }
        return @{ Vendor='amd'; Name=$n; HsaOverride=$hsa; Gfx=$gfx }
    }
    foreach ($g in $gpus) {
        if ($g.Name -match 'Arc\s+[AB]\d{3}|Intel.*Arc') {
            return @{ Vendor='intel'; Name=$g.Name; HsaOverride=''; Gfx='' }
        }
    }
    return @{ Vendor='cpu'; Name='No supported discrete GPU detected'; HsaOverride=''; Gfx='' }
}

# -----------------------------------------------------------------------------
# 1. Embeddable Python 3.12
# -----------------------------------------------------------------------------
function Ensure-Python {
    if (Test-Path $PyExe) {
        $v = & $PyExe -c "import sys; print('%d.%d.%d'%sys.version_info[:3])" 2>$null
        if ($LASTEXITCODE -eq 0 -and $v) { Write-Ok "Python: $v ($PyExe)"; return }
        Write-Warn2 "Istniejacy python/ uszkodzony — przebuduje."
        Remove-Item -LiteralPath $PyDir -Recurse -Force
    }

    Write-Step "Embeddable Python $PyVer"
    $zip = Join-Path $env:TEMP "python-$PyVer-embed-amd64.zip"
    if (-not (Test-Path $zip)) {
        Download-File "https://www.python.org/ftp/python/$PyVer/python-$PyVer-embed-amd64.zip" $zip
    }
    New-Item -ItemType Directory -Force -Path $PyDir | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $PyDir -Force

    # Odkomentuj 'import site' w *._pth zeby pip i pakiety dzialaly
    $pth = Get-ChildItem -Path $PyDir -Filter 'python*._pth' | Select-Object -First 1
    if (-not $pth) { Fail "Brak python*._pth po rozpakowaniu — uszkodzony zip." }
    $lines = Get-Content -LiteralPath $pth.FullName
    $patched = $lines | ForEach-Object {
        if ($_ -match '^\s*#\s*import\s+site\s*$') { 'import site' } else { $_ }
    }
    Set-Content -LiteralPath $pth.FullName -Value $patched -Encoding ASCII

    # Bootstrap pip
    $getPip = Join-Path $PyDir 'get-pip.py'
    Download-File 'https://bootstrap.pypa.io/get-pip.py' $getPip
    & $PyExe $getPip --no-warn-script-location
    if ($LASTEXITCODE -ne 0) { Fail "get-pip.py nie zadzialal." }
    Remove-Item -LiteralPath $getPip -Force

    & $PyExe -m pip install --upgrade pip setuptools wheel | Out-Null
    Write-Ok "Python + pip gotowe."
}

# -----------------------------------------------------------------------------
# 2. MinGit
# -----------------------------------------------------------------------------
function Ensure-Git {
    if (Test-Path $GitExe) { Write-Ok "MinGit: $GitExe"; return }
    Write-Step "MinGit (portable)"
    $zip = Join-Path $env:TEMP $MinGitFile
    if (-not (Test-Path $zip)) {
        Download-File "https://github.com/git-for-windows/git/releases/download/$MinGitTag/$MinGitFile" $zip
    }
    if (Test-Path $GitDir) { Remove-Item -LiteralPath $GitDir -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $GitDir | Out-Null
    Expand-Archive -LiteralPath $zip -DestinationPath $GitDir -Force
    if (-not (Test-Path $GitExe)) { Fail "MinGit rozpakowany ale brak $GitExe." }
    Write-Ok "MinGit gotowy."
}

# -----------------------------------------------------------------------------
# 3. Repo
# -----------------------------------------------------------------------------
function Ensure-Repo {
    Write-Step "Repozytorium ACE-Step 1.5"
    if (Test-Path (Join-Path $RepoDir '.git')) {
        Write-Info "Repo istnieje — git pull --ff-only..."
        Push-Location $RepoDir
        try { & $GitExe pull --ff-only } finally { Pop-Location }
    } else {
        if (Test-Path $RepoDir) {
            $items = Get-ChildItem -LiteralPath $RepoDir -Force -ErrorAction SilentlyContinue
            if ($items) { Fail "$RepoDir istnieje i nie jest puste." }
        }
        & $GitExe clone --depth 1 $RepoUrl $RepoDir
        if ($LASTEXITCODE -ne 0) { Fail "git clone nie powiodl sie." }
    }
    Write-Ok "Repo gotowe: $RepoDir"
}

# -----------------------------------------------------------------------------
# 4. PyTorch stack per backend
# -----------------------------------------------------------------------------
function Get-InstalledTorchBackend {
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'SilentlyContinue'
    try {
        $info = (& $PyExe -m pip show torch 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0 -or -not $info -or $info -match 'not found') { return $null }
        if ($info -match 'Version:\s*\S*?\+rocm')     { return 'amd' }   # +rocmsdk lub +rocm7.x
        if ($info -match 'Version:\s*\S*?\+cu\d+')   { return 'nvidia' }
        if ($info -match 'Version:\s*\S*?\+cpu')     { return 'cpu' }
        return 'unknown'
    } finally {
        $ErrorActionPreference = $prev
    }
}

function Install-Stack($gpu) {
    $current = Get-InstalledTorchBackend
    if ($current -and $current -ne $gpu.Vendor) {
        Write-Warn2 "Wykryto torch ($current) niezgodny z GPU ($($gpu.Vendor)) — przebuduje site-packages."
        & $PyExe -m pip uninstall -y torch torchaudio torchvision 2>$null | Out-Null
    } elseif ($current -eq $gpu.Vendor -and -not $Force) {
        Write-Info "torch+$current juz zainstalowany — pomijam ROCm SDK + PyTorch wheels + requirements."
        return   # skip pelnego switcha (kola juz w site-packages)
    }

    switch ($gpu.Vendor) {
        'amd' {
            # Wybierz wlasciwy zestaw kol wg generacji GPU
            $isRdna2 = $gpu.Gfx -match '^gfx103[012]$'
            if ($isRdna2) {
                Write-Step "ROCm nightly (gfx103X-dgpu) — PyTorch 2.10 + ROCm 7.12 (semi-oficjalne therock buildy dla RX 6000)"
                $v = $RocmNightlyGfx103XVer
                $base = $RocmNightlyGfx103X
                $sdk = @(
                    "$base/rocm-$v.tar.gz",
                    "$base/rocm_sdk_core-$v-py3-none-win_amd64.whl",
                    "$base/rocm_sdk_devel-$v-py3-none-win_amd64.whl",
                    "$base/rocm_sdk_libraries_gfx103x_dgpu-$v-py3-none-win_amd64.whl"
                )
                # UWAGA: '+' w URL musi byc %2B (S3 nie traktuje go jako separator)
                $torchWheels = @(
                    "$base/torch-2.10.0%2Brocm$v-cp312-cp312-win_amd64.whl",
                    "$base/torchaudio-2.10.0%2Brocm$v-cp312-cp312-win_amd64.whl",
                    "$base/torchvision-0.25.0%2Brocm$v-cp312-cp312-win_amd64.whl"
                )
            } else {
                Write-Step "ROCm 7.2 SDK (5-8 GB) + PyTorch ROCm (RDNA3/4)"
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
            if ($LASTEXITCODE -ne 0) { Fail "Instalacja ROCm SDK nieudana." }
            & $PyExe -m pip install --no-cache-dir @torchWheels
            if ($LASTEXITCODE -ne 0) { Fail "Instalacja PyTorch ROCm nieudana." }

            $req = Join-Path $RepoDir 'requirements-rocm.txt'
            if (-not (Test-Path $req)) { Fail "Brak $req w sklonowanym repo." }
            & $PyExe -m pip install --no-cache-dir -r $req
            if ($LASTEXITCODE -ne 0) { Fail "Instalacja requirements-rocm.txt nieudana." }

            # torchcodec wymagany przez torchaudio.save (mimo patcha — pakiet sam ma byc obecny)
            & $PyExe -m pip install --no-cache-dir torchcodec
            if ($LASTEXITCODE -ne 0) { Write-Warn2 "torchcodec install nieudany (kontynuuje — patch torchaudio i tak omija)." }

            # hf_xet — przyspieszenie pobierania modeli z HuggingFace 5x (Xet Storage backend)
            & $PyExe -m pip install --no-cache-dir hf_xet
            if ($LASTEXITCODE -ne 0) { Write-Warn2 "hf_xet install nieudany (downloady beda wolniejsze ale dzialaja)." }

            # Studio post-processing toolkit (uzywany przez ../Studio/{Stems,Match,Lyrics}.bat)
            Write-Step "Studio toolkit: demucs (stem separation) + matchering (auto-master) + openai-whisper (lyrics)"
            & $PyExe -m pip install --no-cache-dir demucs matchering openai-whisper
            if ($LASTEXITCODE -ne 0) { Write-Warn2 "Studio toolkit install nieudany (Studio\*.bat moga nie dzialac)." }
        }
        'nvidia' {
            Write-Step "PyTorch CUDA 12.4"
            & $PyExe -m pip install --no-cache-dir torch torchaudio torchvision --index-url $CudaIndex
            if ($LASTEXITCODE -ne 0) { Fail "Instalacja PyTorch CUDA nieudana." }
            $req = Join-Path $RepoDir 'requirements.txt'
            if (-not (Test-Path $req)) {
                Write-Warn2 "Brak requirements.txt — uzywam pyproject (pip install -e .)."
                & $PyExe -m pip install --no-cache-dir -e $RepoDir
            } else {
                & $PyExe -m pip install --no-cache-dir -r $req
            }
            if ($LASTEXITCODE -ne 0) { Fail "Instalacja zaleznosci nieudana." }
        }
        'cpu' {
            Write-Warn2 "Tryb CPU — ACE-Step bedzie BARDZO wolne (kilkadziesiat minut na utwor)."
            & $PyExe -m pip install --no-cache-dir torch torchaudio torchvision --index-url $CpuIndex
            if ($LASTEXITCODE -ne 0) { Fail "Instalacja PyTorch CPU nieudana." }
            $req = Join-Path $RepoDir 'requirements.txt'
            if (Test-Path $req) {
                & $PyExe -m pip install --no-cache-dir -r $req
            } else {
                & $PyExe -m pip install --no-cache-dir -e $RepoDir
            }
            if ($LASTEXITCODE -ne 0) { Fail "Instalacja zaleznosci nieudana." }
        }
        default { Fail "Nieobslugiwany backend: $($gpu.Vendor)" }
    }
    Write-Ok "Stos PyTorch ($($gpu.Vendor)) zainstalowany."
}

# -----------------------------------------------------------------------------
# 5. Smoke test
# -----------------------------------------------------------------------------
function SmokeTest($gpu) {
    Write-Step "Smoke-test PyTorch"
    $env:HSA_OVERRIDE_GFX_VERSION = $gpu.HsaOverride
    $out = & $PyExe -c @"
import torch
ok = torch.cuda.is_available()
hip = getattr(torch.version,'hip',None)
cu = getattr(torch.version,'cuda',None)
name = torch.cuda.get_device_name(0) if ok else 'CPU'
print(f'cuda_available={ok}')
print(f'hip={hip}')
print(f'cuda={cu}')
print(f'device={name}')
"@ 2>&1
    Write-Host $out
    if ($out -match 'cuda_available=True') {
        Write-Ok "GPU widoczne dla PyTorch."
    } elseif ($gpu.Vendor -eq 'cpu') {
        Write-Ok "OK (tryb CPU)."
    } else {
        Write-Warn2 "GPU NIE widoczne. Przyczyny: stary sterownik, niewspierane gfx, restart wymagany."
    }
}

# -----------------------------------------------------------------------------
# 5b. FFmpeg shared (n7.1) + skopiowanie ffmpeg.exe / DLLs do python\
#     Potrzebne dla: (a) audio_utils._save_mp3 subprocess ffmpeg, (b) torchcodec.
# -----------------------------------------------------------------------------
function Ensure-FFmpeg {
    $marker = Join-Path $PyDir 'ffmpeg.exe'
    if (Test-Path $marker) { Write-Ok "FFmpeg juz w python\ ($marker)"; return }

    Write-Step "FFmpeg n7.1 shared (BtbN) — download + setup"
    $zip = Join-Path $env:TEMP 'ffmpeg-n71-shared.zip'
    if (-not (Test-Path $zip)) { Download-File $FFmpegUrl $zip }

    $tmp = Join-Path $env:TEMP 'ffmpeg-extract'
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    Expand-Archive -LiteralPath $zip -DestinationPath $tmp -Force
    $inner = Get-ChildItem $tmp -Directory | Select-Object -First 1
    if (-not $inner) { Fail "Pusta zawartosc zipa FFmpeg." }

    if (Test-Path $FFmpegDir) { Remove-Item $FFmpegDir -Recurse -Force }
    Move-Item -LiteralPath $inner.FullName -Destination $FFmpegDir

    # ffmpeg.exe / ffprobe.exe / ffplay.exe oraz wszystkie DLLs -> python\ (Windows szuka tam DLL-i procesu)
    $bin = Join-Path $FFmpegDir 'bin'
    foreach ($exe in 'ffmpeg.exe','ffprobe.exe','ffplay.exe') {
        $p = Join-Path $bin $exe
        if (Test-Path $p) { Copy-Item $p -Destination $PyDir -Force }
    }
    # DLLs do python\ ORAZ obok torchcodec\libtorchcodec_core*.dll (zaleznosci runtime)
    $tc = Join-Path $PyDir 'Lib\site-packages\torchcodec'
    Get-ChildItem $bin -Filter '*.dll' | ForEach-Object {
        Copy-Item $_.FullName -Destination $PyDir -Force
        if (Test-Path $tc) { Copy-Item $_.FullName -Destination $tc -Force }
    }
    Write-Ok "FFmpeg gotowy ($FFmpegDir + DLLs w python\)."
}

# -----------------------------------------------------------------------------
# 5c. Code patches — wymagane na ROCm Windows.
#     Idempotentne: kazda funkcja sama wykrywa czy juz nalozona.
# -----------------------------------------------------------------------------
function Patch-VectorQuantize {
    # vector_quantize_pytorch importuje torch.distributed.nn na top-level — ROCm Windows bez distributed.
    $f = Join-Path $PyDir 'Lib\site-packages\vector_quantize_pytorch\lookup_free_quantization.py'
    if (-not (Test-Path $f)) { Write-Info "vqp: plik nie istnieje (pomijam)"; return }
    $content = Get-Content -LiteralPath $f -Raw
    if ($content -match 'except ImportError:\s*\r?\n\s*dist_nn = None') { Write-Ok "vqp: juz zapatchowane"; return }
    $patched = $content -replace 'from torch\.distributed import nn as dist_nn',
        "try:`r`n    from torch.distributed import nn as dist_nn`r`nexcept ImportError:`r`n    dist_nn = None  # ROCm Windows: brak torch.distributed.nn"
    Set-Content -LiteralPath $f -Value $patched -NoNewline
    Write-Ok "vqp: nalozony shim torch.distributed.nn"
}

function Patch-TorchaudioSave {
    # torchaudio.save -> save_with_torchcodec, ktore wymaga torchcodec dzialajacego z FFmpeg.
    # Na ROCm Windows torchcodec ABI nie zgadza sie z dostepnym FFmpeg -> bypass na soundfile/subprocess ffmpeg.exe.
    $f = Join-Path $PyDir 'Lib\site-packages\torchaudio\_torchcodec.py'
    if (-not (Test-Path $f)) { Write-Info "torchaudio: plik nie istnieje (pomijam)"; return }
    $content = Get-Content -LiteralPath $f -Raw
    if ($content -match 'PATCH dla ROCm Windows: torchcodec/FFmpeg') { Write-Ok "torchaudio: juz zapatchowane"; return }

    $oldBody = @'
    # Import torchcodec here to provide clear error if not available
    try:
        from torchcodec.encoders import AudioEncoder
'@
    if ($content -notmatch [regex]::Escape('# Import torchcodec here to provide clear error if not available')) {
        Write-Warn2 "torchaudio: oryginalna struktura zmieniona — pomijam patch (sprawdz ręcznie)."
        return
    }
    # Patch przez Python (regex multilinowy w PS jest upierdliwy)
    $py = @'
import sys, re, io
path = sys.argv[1]
src = io.open(path, 'r', encoding='utf-8').read()
new_body = """    # === PATCH dla ROCm Windows: torchcodec/FFmpeg ABI nie zgadza sie z dostepnym BtbN buildem. ===
    # Zastepujemy AudioEncoder na soundfile (WAV/FLAC/OGG) lub subprocess ffmpeg.exe (MP3/AAC/OPUS/M4A).
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
# Znajdz body save_with_torchcodec i podmien (od `# Import torchcodec here` do konca funkcji).
pattern = re.compile(
    r'(?P<head>def save_with_torchcodec\([^)]*\)[^:]*:\s*\n(?:[ \t]+"""[\s\S]*?"""\s*\n)?)'
    r'(?:[ \t]+# Import torchcodec here[\s\S]*?)(?=\n(?:def |@|\Z))',
    re.MULTILINE
)
m = pattern.search(src)
if not m:
    print("MATCH_FAIL", file=sys.stderr)
    sys.exit(2)
new_src = src[:m.start()] + m.group('head') + new_body + src[m.end():]
io.open(path, 'w', encoding='utf-8', newline='').write(new_src)
print("OK")
'@
    $tmpPy = Join-Path $env:TEMP 'patch_torchaudio.py'
    Set-Content -LiteralPath $tmpPy -Value $py -Encoding UTF8
    $out = & $PyExe $tmpPy $f 2>&1
    Remove-Item $tmpPy -Force
    if ($LASTEXITCODE -ne 0) { Write-Warn2 "torchaudio patch nieudany: $out"; return }
    Write-Ok "torchaudio: save_with_torchcodec -> soundfile/subprocess ffmpeg.exe"
}

function Patch-Theme {
    # Customowy czarno-zoltawy modern theme (gr.themes.Base + yellow primary + dark zinc).
    # Marker w pliku: PORTABLE_THEME_MARKER. Mozna recznie zmienic kolory w pliku.
    $f = Join-Path $RepoDir 'acestep\ui\gradio\interfaces\__init__.py'
    if (-not (Test-Path $f)) { Write-Info "theme: plik nie istnieje (pomijam)"; return }
    $content = Get-Content -LiteralPath $f -Raw
    if ($content -match 'PORTABLE_THEME_MARKER') { Write-Ok "theme: juz portable (czarno-zoltawy)"; return }

    $themeBlock = @'
    # PORTABLE_THEME_MARKER (czarno-zoltawy modern, customowy theme oparty na gr.themes.Base)
    _portable_theme = gr.themes.Base(
        primary_hue=gr.themes.colors.yellow,
        secondary_hue=gr.themes.colors.amber,
        neutral_hue=gr.themes.colors.zinc,
        font=[gr.themes.GoogleFont("Inter"), "ui-sans-serif", "system-ui", "sans-serif"],
    ).set(
        body_background_fill="#0a0a0a",
        body_background_fill_dark="#0a0a0a",
        background_fill_primary="#111111",
        background_fill_primary_dark="#111111",
        background_fill_secondary="#181818",
        background_fill_secondary_dark="#181818",
        body_text_color="#f4f4f5",
        body_text_color_dark="#f4f4f5",
        body_text_color_subdued="#a1a1aa",
        body_text_color_subdued_dark="#a1a1aa",
        border_color_primary="#2a2a2a",
        border_color_primary_dark="#2a2a2a",
        block_background_fill="#141414",
        block_background_fill_dark="#141414",
        block_border_color="#2a2a2a",
        block_border_color_dark="#2a2a2a",
        block_title_text_color="#facc15",
        block_title_text_color_dark="#facc15",
        block_label_text_color="#fde047",
        block_label_text_color_dark="#fde047",
        input_background_fill="#1a1a1a",
        input_background_fill_dark="#1a1a1a",
        input_border_color="#3a3a3a",
        input_border_color_dark="#3a3a3a",
        input_border_color_focus="#facc15",
        input_border_color_focus_dark="#facc15",
        button_primary_background_fill="#facc15",
        button_primary_background_fill_dark="#facc15",
        button_primary_background_fill_hover="#fde047",
        button_primary_background_fill_hover_dark="#fde047",
        button_primary_text_color="#0a0a0a",
        button_primary_text_color_dark="#0a0a0a",
        button_secondary_background_fill="#27272a",
        button_secondary_background_fill_dark="#27272a",
        button_secondary_background_fill_hover="#3f3f46",
        button_secondary_background_fill_hover_dark="#3f3f46",
        button_secondary_text_color="#fafafa",
        button_secondary_text_color_dark="#fafafa",
        link_text_color="#facc15",
        link_text_color_dark="#facc15",
        link_text_color_hover="#fde047",
        link_text_color_hover_dark="#fde047",
        shadow_drop="0 1px 2px 0 rgb(0 0 0 / 0.6)",
        shadow_drop_lg="0 10px 15px -3px rgb(0 0 0 / 0.7)",
    )
    with gr.Blocks(
        title=t("app.title"),
        theme=_portable_theme,
'@

    # 3 mozliwe stany do podmienienia: Soft (upstream), Glass (poprzedni patch), dracula_revamped (jeszcze poprzedni)
    $patterns = @(
        @{ rx = '\s*with gr\.Blocks\(\s*\r?\n\s*title=t\("app\.title"\),\s*\r?\n\s*theme=gr\.themes\.Soft\(\),'; old = 'Soft' },
        @{ rx = '\s*with gr\.Blocks\(\s*\r?\n\s*title=t\("app\.title"\),\s*\r?\n\s*theme=gr\.themes\.Glass\(\),'; old = 'Glass' },
        @{ rx = '\s*with gr\.Blocks\(\s*\r?\n\s*title=t\("app\.title"\),\s*\r?\n\s*theme="freddyaboulton/dracula_revamped",'; old = 'Dracula' }
    )
    foreach ($p in $patterns) {
        if ($content -match $p.rx) {
            $newContent = $content -replace $p.rx, "`r`n$themeBlock"
            Set-Content -LiteralPath $f -Value $newContent -NoNewline
            Write-Ok "theme: $($p.old) -> portable (czarno-zoltawy)"
            return
        }
    }
    Write-Info "theme: niezmieniony (oryginal niestandardowy lub juz patched)"
}

function Patch-DarkSynthDefaults {
    # Dark-synthwave preset: guidance=9.0, heun, sde, shift=4.0, steps=60 (zamiast 7.0/euler/ode/3.0/32)
    $f1 = Join-Path $RepoDir 'acestep\ui\gradio\interfaces\generation_advanced_dit_controls.py'
    if (Test-Path $f1) {
        $c = Get-Content -LiteralPath $f1 -Raw
        if ($c -notmatch 'PORTABLE_DEFAULTS') {
            $c = $c -replace '(\s*)guidance_scale = gr\.Slider\(', '$1# PORTABLE_DEFAULTS: dark-synth presets (guidance 9.0, sde, heun)$1guidance_scale = gr.Slider('
            $c = $c -replace '(guidance_scale = gr\.Slider\([^)]*?value=)7\.0', '${1}9.0'
            $c = $c -replace '(infer_method = gr\.Dropdown\([^)]*?value=)"ode"', '$1"sde"'
            $c = $c -replace '(sampler_mode = gr\.Dropdown\([^)]*?value=)"euler"', '$1"heun"'
            Set-Content -LiteralPath $f1 -Value $c -NoNewline
            Write-Ok "defaults UI: guidance 9.0 / sde / heun"
        } else { Write-Ok "defaults UI: juz zapatchowane" }
    }
    $f2 = Join-Path $RepoDir 'acestep\ui\gradio\events\generation\model_config.py'
    if (Test-Path $f2) {
        $c = Get-Content -LiteralPath $f2 -Raw
        if ($c -notmatch 'PORTABLE_DEFAULTS') {
            $c = $c -replace 'steps = 50 if is_sft else 32', "# PORTABLE_DEFAULTS: 30 steps (FP32 na RDNA2 = ~5 min/utwor)`r`n        steps = 50 if is_sft else 30"
            # podmien tylko shift_value w bloku base (drugie wystapienie)
            $idx = 0
            $c = [regex]::Replace($c, '"shift_value": 3\.0', { param($m) $script:idx++; if ($script:idx -eq 2) { '"shift_value": 4.0' } else { $m.Value } })
            Set-Content -LiteralPath $f2 -Value $c -NoNewline
            Write-Ok "defaults model_config: steps 60 / shift 4.0 (base only)"
        } else { Write-Ok "defaults model_config: juz zapatchowane" }
    }
}

function Patch-DurationDefault {
    # Duration 240s na stale, auto OFF — user nie chce klikac duration_auto przy kazdej generacji
    $f = Join-Path $RepoDir 'acestep\ui\gradio\interfaces\generation_tab_optional_controls.py'
    if (-not (Test-Path $f)) { Write-Info "duration: plik nie istnieje"; return }
    $c = Get-Content -LiteralPath $f -Raw
    if ($c -match 'PORTABLE_DURATION_DEFAULT') { Write-Ok "duration: juz zapatchowane (240s)"; return }
    $c = $c -replace '(audio_duration = gr\.Number\([^)]*?value=)-1(,[\s\S]*?interactive=)False',
                     "# PORTABLE_DURATION_DEFAULT: 240 s (4 min), Auto OFF`r`n            `$1`240`$2True"
    $c = $c -replace '(duration_auto = gr\.Checkbox\([^)]*?value=)True',
                     '${1}False'
    Set-Content -LiteralPath $f -Value $c -NoNewline
    Write-Ok "duration: default 240s, auto OFF"
}

function Apply-CodePatches {
    Write-Step "Patche kodu (ROCm Windows + UI theme + defaults)"
    Patch-VectorQuantize
    Patch-TorchaudioSave
    Patch-Theme
    Patch-DarkSynthDefaults
    Patch-DurationDefault
}

# -----------------------------------------------------------------------------
# 6. Wrappery Start.bat / Stop.bat / Stop.ps1 + gpu_profile.env
# -----------------------------------------------------------------------------
function Write-Launchers($gpu) {
    Write-Step "Wrappery Start/Stop + profil GPU"

    # gpu_profile.env (czytany przez Start.bat — survives folder move)
    $profileText = @"
# Auto-wygenerowane przez Install.ps1 — nie edytuj recznie, uruchom skrypt ponownie.
GPU_VENDOR=$($gpu.Vendor)
GPU_NAME=$($gpu.Name)
GPU_GFX=$($gpu.Gfx)
HSA_OVERRIDE_GFX_VERSION=$($gpu.HsaOverride)
"@
    Set-Content -LiteralPath $Profile -Value $profileText -Encoding ASCII

    # Start.bat — czyta gpu_profile.env, ustawia HF_HOME na folder, uruchamia ACE-Step
    $startBat = Join-Path $Root 'Start.bat'
    $startContent = @'
@echo off
setlocal enabledelayedexpansion
title ACE-Step 1.5 (Portable)
cd /d "%~dp0"

REM === Wczytaj gpu_profile.env ===
if exist gpu_profile.env (
    for /f "usebackq tokens=1,* delims==" %%a in ("gpu_profile.env") do (
        set "_k=%%a"
        if not "!_k!"=="" if not "!_k:~0,1!"=="#" set "!_k!=%%b"
    )
) else (
    echo BRAK gpu_profile.env — uruchom najpierw Install.bat.
    pause & exit /b 1
)

REM === Cache HuggingFace w folderze ===
set HF_HOME=%~dp0models
set HUGGINGFACE_HUB_CACHE=%~dp0models\hub
set TRANSFORMERS_CACHE=%~dp0models\transformers
set MODELSCOPE_CACHE=%~dp0models\modelscope
if not exist "%HF_HOME%" mkdir "%HF_HOME%"

REM === Wspolne flagi runtime ===
set ACESTEP_LM_BACKEND=pt
REM Timeout generacji 30 min (FP32 + 30 steps na RX 6800 to ~5-8 min, daj zapas)
set ACESTEP_GENERATION_TIMEOUT=1800
set TORCH_COMPILE_BACKEND=eager
set MIOPEN_FIND_MODE=FAST
set TOKENIZERS_PARALLELISM=false
REM Mniej fragmentacji VRAM (klucz dla 16 GB RX 6800 z 1.7B LM + DiT + VAE)
set PYTORCH_HIP_ALLOC_CONF=expandable_segments:True
REM Turbo (8 steps) = mala akumulacja bledow numerycznych, bfloat16 dziala ok.
REM Dla base/sft (50+ steps) ustaw float32 zeby uniknac szumow.
set ACESTEP_ROCM_DTYPE=bfloat16

REM === Server === (7860 zajety przez Brain, uzywamy 7870)
if not defined PORT set PORT=7870
if not defined SERVER_NAME set SERVER_NAME=127.0.0.1

REM === Python portable ===
set PY=%~dp0python\python.exe
if not exist "%PY%" (
    echo BRAK python\python.exe — uruchom Install.bat.
    pause & exit /b 1
)

REM === Powiadomienie o GPU ===
echo ============================================
echo  ACE-Step 1.5 (portable)
echo  GPU:    %GPU_NAME% [%GPU_VENDOR% / %GPU_GFX%]
echo  HSA:    %HSA_OVERRIDE_GFX_VERSION%
echo  URL:    http://%SERVER_NAME%:%PORT%
echo  Pierwsze uruchomienie: pobieranie modeli (~5-10 GB).
echo ============================================

REM Otworz przegladarke po 40 s (gradio + pierwszy download)
start "" /b cmd /c "timeout /t 40 /nobreak >nul & start http://%SERVER_NAME%:%PORT%"

cd ACE-Step-1.5
"%PY%" -u acestep\acestep_v15_pipeline.py ^
    --port %PORT% --server-name %SERVER_NAME% --language en ^
    --config_path acestep-v15-turbo ^
    --lm_model_path acestep-5Hz-lm-1.7B ^
    --offload_to_cpu true ^
    --init_service true ^
    --backend pt

echo.
echo (Serwer zatrzymany.)
pause
endlocal
'@
    Set-Content -LiteralPath $startBat -Value $startContent -Encoding ASCII
    Write-Ok "Start.bat"

    # Stop.ps1 — kill po porcie + procesy z lokalnego python.exe
    $stopPs1 = Join-Path $Root 'Stop.ps1'
    $stopContent = @'
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
'@
    Set-Content -LiteralPath $stopPs1 -Value $stopContent -Encoding UTF8
    Write-Ok "Stop.ps1"

    # Stop.bat — wrapper
    $stopBat = Join-Path $Root 'Stop.bat'
    $stopBatContent = @'
@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop.ps1"
timeout /t 2 /nobreak >nul
'@
    Set-Content -LiteralPath $stopBat -Value $stopBatContent -Encoding ASCII
    Write-Ok "Stop.bat"
}

# -----------------------------------------------------------------------------
# 7. Optional: desktop shortcuts (wskazuja na obecna lokalizacje folderu)
# -----------------------------------------------------------------------------
function Write-DesktopShortcuts {
    Write-Step "Skroty na pulpicie"
    $desktop = [Environment]::GetFolderPath('Desktop')
    $sh = New-Object -ComObject WScript.Shell

    $startLnk = Join-Path $desktop 'Start ACE-Step.lnk'
    $s = $sh.CreateShortcut($startLnk)
    $s.TargetPath       = (Join-Path $Root 'Start.bat')
    $s.WorkingDirectory = $Root
    $s.IconLocation     = "$env:SystemRoot\System32\shell32.dll,137"
    $s.Description      = 'Uruchom ACE-Step (portable)'
    $s.WindowStyle      = 1
    $s.Save()
    Write-Ok $startLnk

    $stopLnk = Join-Path $desktop 'Stop ACE-Step.lnk'
    $s = $sh.CreateShortcut($stopLnk)
    $s.TargetPath       = (Join-Path $Root 'Stop.bat')
    $s.WorkingDirectory = $Root
    $s.IconLocation     = "$env:SystemRoot\System32\shell32.dll,131"
    $s.Description      = 'Zatrzymaj ACE-Step (portable)'
    $s.WindowStyle      = 1
    $s.Save()
    Write-Ok $stopLnk
}

# =============================================================================
# Glowny przebieg
# =============================================================================
Write-Host ''
Write-Host '============================================' -ForegroundColor Cyan
Write-Host ' ACE-Step 1.5 — Portable Installer' -ForegroundColor Cyan
Write-Host " Folder: $Root" -ForegroundColor Cyan
Write-Host '============================================' -ForegroundColor Cyan

# Sanity: Windows 11 nie jest WYMAGANE dla CUDA/CPU, ale ROCm 7.2 tak.
$build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
Write-Info "Windows build: $build"

# Force = wyczysc python/
if ($Force -and (Test-Path $PyDir)) {
    Write-Warn2 "-Force: usuwam $PyDir"
    Remove-Item -LiteralPath $PyDir -Recurse -Force
}

# Detekcja GPU
Write-Step "Detekcja GPU"
$gpu = if ($GpuVendor -eq 'auto') { Detect-Gpu } else {
    @{ Vendor=$GpuVendor; Name="(wymuszone: $GpuVendor)"; HsaOverride=''; Gfx='' }
}
Write-Info "GPU vendor:  $($gpu.Vendor)"
Write-Info "GPU name:    $($gpu.Name)"
if ($gpu.Vendor -eq 'amd') {
    if ($HsaOverride) { $gpu.HsaOverride = $HsaOverride }
    Write-Info "GFX:         $($gpu.Gfx)"
    Write-Info "HSA override:$($gpu.HsaOverride)"
    if ($build -lt 22000) {
        Write-Warn2 "ROCm 7.2 wymaga Windows 11 (build 22000+). Wykryto $build — instalacja moze nie zadzialac."
    }
    Write-Info "Pamietaj: sterownik AMD Adrenalin >= 26.1.1 dla ROCm 7.2."
} elseif ($gpu.Vendor -eq 'intel') {
    Write-Warn2 "Intel Arc nie ma jeszcze oficjalnej sciezki ACE-Step. Przelaczam na tryb CPU."
    $gpu = @{ Vendor='cpu'; Name=$gpu.Name + ' (fallback CPU)'; HsaOverride=''; Gfx='' }
}

Ensure-Python
Ensure-Git
Ensure-Repo
Install-Stack $gpu
Ensure-FFmpeg
Apply-CodePatches
SmokeTest $gpu
Write-Launchers $gpu

if ($DesktopShortcuts) { Write-DesktopShortcuts }

Write-Host ''
Write-Host '============================================' -ForegroundColor Green
Write-Host ' GOTOWE.' -ForegroundColor Green
Write-Host '============================================' -ForegroundColor Green
Write-Host " Backend:  $($gpu.Vendor)"
Write-Host " GPU:      $($gpu.Name)"
Write-Host ''
Write-Host " >> Start: dwuklik 'Start.bat' w tym folderze"
Write-Host " >> Stop:  dwuklik 'Stop.bat' w tym folderze"
Write-Host " >> UI:    http://127.0.0.1:7870 (otworzy sie sam po ~40 s)"
Write-Host ''
Write-Host " Pierwsze uruchomienie pobierze modele (~5-10 GB) do '$ModelsDir'."
Write-Host " Aby przeniesc na inny komputer:"
Write-Host "  - skopiuj caly folder (najlepiej z 'models/' zeby nie pobierac ponownie)"
Write-Host "  - na nowym PC odpal Install.bat (auto wykryje nowe GPU)"
Write-Host ''
