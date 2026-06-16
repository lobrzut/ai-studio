@echo off
REM Drag & drop audio -> Enhance (domyslnie tryb light).
REM 2. argument: light | medium | heavy
if "%~1"=="" (
    echo.
    echo Uzycie: Enhance.bat sciezka\utwor.mp3 [light^|medium^|heavy]
    echo Lub przeciagnij plik na ikone (light).
    echo.
    echo  medium = AI Resemble Enhance (z Install.bat)
    echo  heavy  = kopiuje do kolejki ComfyUI + otwiera :7871
    pause
    exit /b 1
)
set "MODE=light"
if not "%~2"=="" set "MODE=%~2"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Enhance.ps1" -InputFile "%~1" -Mode %MODE%
echo.
pause
