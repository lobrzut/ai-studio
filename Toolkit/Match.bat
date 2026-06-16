@echo off
REM Match.bat target.wav reference.wav  -> output: target_matched.wav (EQ+kompresja+LUFS jak referencyjny)
REM Mozesz tez przeciagnac TYLKO target audio - skrypt wezmie najnowszy plik z Studio\References\ jako referencyjny.
if "%~1"=="" (
    echo.
    echo Uzycie: Match.bat target.wav [reference.wav]
    echo Lub przeciagnij plik audio na te ikone ^(uzyje najnowszego z References\^)
    echo.
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Match.ps1" -Target "%~1" -Reference "%~2"
echo.
pause
