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
    echo BRAK gpu_profile.env ? uruchom najpierw Install.bat.
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
    echo BRAK python\python.exe ? uruchom Install.bat.
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
