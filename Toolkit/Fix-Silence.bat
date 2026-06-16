@echo off
setlocal
cd /d "%~dp0"
if "%~1"=="" (
  echo Uzycie: przeciagnij plik na Fix-Silence.bat
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Fix-Silence.ps1" -InputFile "%~1"
pause
