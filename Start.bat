@echo off

title AI Studio Portable - Dashboard

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start.ps1" %*

if errorlevel 1 (

    echo.

    echo Start nieudany — sprawdz logs\ lub Install.bat

    pause

    exit /b 1

)

echo.

echo Dashboard: http://127.0.0.1:7880/
echo Ikona tray: zolte A przy zegarze. Brak? Kliknij ^ przy zegarze -^> Ikony zasobnika -^> wlacz AI Studio.

timeout /t 3 /nobreak >nul

