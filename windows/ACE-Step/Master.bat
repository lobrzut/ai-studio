@echo off
REM Drag & drop pliku audio na te ikone -> wymaster pod -12 LUFS (lub argument 2).
REM Uzycie: Master.bat utwor.mp3 [-target_lufs] [-target_peak]
REM Domyslnie: -12 LUFS / -1 dBFS peak / 4 LRA (klubowe synthwave)
if "%~1"=="" (
    echo.
    echo Uzycie: Master.bat sciezka\do\utworu.mp3
    echo Lub przeciagnij plik audio na te ikone.
    echo.
    echo Opcjonalne 2-gi argument: target LUFS np. -10 dla glosniej, -14 dla Spotify standard
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Master.ps1" -InputFile "%~1"
echo.
pause
