@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
  echo Uzycie: przeciagnij plik na Scan-Silence.bat
  echo    lub: Scan-Silence.bat "sciezka\do\utworu.mp3"
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Scan-Silence.ps1" -InputFile "%~1"
echo.
pause
