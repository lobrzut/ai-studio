@echo off
title AI Studio Portable - Stop
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop.ps1"
timeout /t 2 /nobreak >nul
