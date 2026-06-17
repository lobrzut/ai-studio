#Requires -Version 5.1
<#
.SYNOPSIS
  Instaluje zaleznosci AI dla Enhance (tryb medium) - resemble-enhance.
  Wywolywane z Install.bat; mozna tez osobno po aktualizacji.
  Na Windows pomija deepspeed (wymagany tylko do treningu).
#>
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Toolkit = $PSScriptRoot
$AceRoot = (Resolve-Path (Join-Path $Toolkit '..\ACE-Step')).Path
$PyExe   = Join-Path $AceRoot 'python\python.exe'

if (-not (Test-Path $PyExe)) {
    Write-Host ('ERROR: brak ' + $PyExe + ' - najpierw Install.bat (ACE-Step)') -ForegroundColor Red
    exit 1
}

Write-Host ''
Write-Host '=== Install Enhance AI (resemble-enhance) ===' -ForegroundColor Cyan
Write-Host 'Pierwsze uruchomienie Enhance medium pobierze modele (~GB).' -ForegroundColor Gray
Write-Host 'Windows: bez deepspeed (tylko inferencja).' -ForegroundColor Gray
Write-Host ''

$pipBase = @('-m', 'pip', 'install', '--upgrade')
if ($Force) { $pipBase += '--force-reinstall' }

# Pakiet PyPI wymaga deepspeed; na Windows build pada. Instalujemy wheel bez zaleznosci.
& $PyExe @($pipBase + @('resemble-enhance==0.0.1', '--no-deps'))
if ($LASTEXITCODE -ne 0) {
    Write-Host 'ERROR: pip install resemble-enhance nieudany.' -ForegroundColor Red
    exit $LASTEXITCODE
}

$runtimeDeps = @(
    'celluloid==0.2.0'
    'librosa==0.10.1'
    'omegaconf==2.3.0'
    'ptflops==0.7.1.2'
    'rich>=13.7.0'
    'resampy==0.4.2'
    'tabulate==0.8.10'
    'tqdm==4.66.1'
)
& $PyExe @($pipBase + $runtimeDeps)
if ($LASTEXITCODE -ne 0) {
    Write-Host 'ERROR: pip install zaleznosci runtime nieudany.' -ForegroundColor Red
    exit $LASTEXITCODE
}

function Apply-ResembleWindowsPatch {
    $site = & $PyExe -c 'import site; print(site.getsitepackages()[0])' 2>&1 | Select-Object -Last 1
    if (-not $site -or -not (Test-Path -LiteralPath $site)) { return }

    $patches = @{
        (Join-Path $site 'resemble_enhance\enhancer\inference.py') = @{
            Old = 'from .train import Enhancer, HParams'
            New = "from .enhancer import Enhancer`r`nfrom .hparams import HParams"
        }
        (Join-Path $site 'resemble_enhance\denoiser\inference.py') = @{
            Old = 'from .train import Denoiser, HParams'
            New = "from .denoiser import Denoiser`r`nfrom .hparams import HParams"
        }
    }
    foreach ($path in $patches.Keys) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        $text = [IO.File]::ReadAllText($path)
        if ($text -notmatch [regex]::Escape($patches[$path].Old)) { continue }
        $text = $text.Replace($patches[$path].Old, $patches[$path].New)
        [IO.File]::WriteAllText($path, $text)
    }
}

Apply-ResembleWindowsPatch

$stubDir = Join-Path $Toolkit 'deepspeed_stub'
$checkPy = @"
import sys
sys.path.insert(0, r'$stubDir')
from resemble_enhance.enhancer.inference import denoise, enhance
"@
$check = & $PyExe -c $checkPy 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host 'UWAGA: Pelna inferencja Resemble na tym torch/ROCm moze nie dzialac.' -ForegroundColor Yellow
    Write-Host 'Enhance medium i tak dziala przez ffmpeg (mocniejszy niz light).' -ForegroundColor Gray
    if ($check) { $check | Select-Object -First 4 | ForEach-Object { Write-Host ('  ' + $_) } }
} else {
    Write-Host 'OK: resemble-enhance (inferencja AI)' -ForegroundColor Green
}
Write-Host ''
Write-Host 'GOTOWE. Uzyj Enhance medium na dashboardzie lub:' -ForegroundColor Green
Write-Host '  Toolkit\Enhance.ps1 -InputFile utwor.mp3 -Mode medium' -ForegroundColor Gray
Write-Host ''
