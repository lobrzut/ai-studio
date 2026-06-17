@echo off
title ComfyUI - soft free VRAM
cd /d "%~dp0\.."
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Soft-Free-GPU.ps1"
exit /b %ERRORLEVEL%
