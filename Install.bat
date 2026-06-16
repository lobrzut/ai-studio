@echo off
title AI Studio Portable - Install
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1" %*
echo.
echo UWAGA: Install NIE uruchamia serwerow. Po instalacji: Start.bat
echo.
pause
