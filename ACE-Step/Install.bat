@echo off
REM ACE-Step Portable Installer — double-click me.
REM Uruchamia Install.ps1 z bezpiecznym ExecutionPolicy bez modyfikowania ustawien systemu.
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
echo.
pause
