@echo off
REM ComfyUI Portable Installer (z natywnym ACE-Step 1.5) - dwuklik
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
echo.
pause
