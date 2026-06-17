@echo off
REM Drag & drop pliku audio (mp3/wav/flac) na te ikone -> wyciaga 4 stemy WAV (drums/bass/vocals/other).
REM Demucs htdemucs (Meta) na GPU ROCm. Output do Studio\Outputs\stems\<nazwa>\
if "%~1"=="" (
    echo.
    echo Uzycie: Stems.bat sciezka\do\utworu.mp3
    echo Lub przeciagnij plik audio na te ikone.
    echo.
    echo Opcje (2-gi argument): --two-stems vocals  (tylko vocal + accompaniment, szybciej)
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stems.ps1" -InputFile "%~1" %2 %3 %4
echo.
pause
