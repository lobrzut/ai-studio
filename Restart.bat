@echo off
title AI Studio Portable - Restart
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Restart.ps1" %*
if errorlevel 2 (
    echo.
    echo Restart niekompletny - sprawdz logs\
    pause
    exit /b 2
)
echo.
echo Restart zakonczony. Odswiez dashboard: http://127.0.0.1:7880/
timeout /t 8 /nobreak >nul
