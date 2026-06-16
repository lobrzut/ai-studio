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
REM Embeddable Python NIE dodaje CWD do sys.path automatycznie ? wymuszamy
set PYTHONPATH=%~dp0ComfyUI
"%PY%" -u main.py --listen %SERVER_NAME% --port %PORT%

echo.
echo (Serwer zatrzymany.)
pause
endlocal
