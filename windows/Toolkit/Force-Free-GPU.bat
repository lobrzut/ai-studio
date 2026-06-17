@echo off
title AI Studio - zwolnij GPU (ComfyUI)
cd /d "%~dp0\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Force-Free-GPU.ps1"
exit /b %ERRORLEVEL%
