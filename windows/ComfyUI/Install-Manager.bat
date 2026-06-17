@echo off
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "& { $py = Join-Path (Get-Location) 'python\python.exe'; $req = Join-Path (Get-Location) 'ComfyUI\manager_requirements.txt'; & $py -m pip install -r $req; if ($LASTEXITCODE -eq 0) { Write-Host 'OK: comfyui_manager zainstalowany. Zrestartuj ComfyUI (Stop.bat + Start.bat).' -ForegroundColor Green } else { Write-Host 'BLAD pip' -ForegroundColor Red } }"
pause
