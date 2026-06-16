@echo off
cd /d "%~dp0\.."
powershell -NoProfile -ExecutionPolicy Bypass -Sta -File "%~dp0Dashboard-Tray.ps1" %*
