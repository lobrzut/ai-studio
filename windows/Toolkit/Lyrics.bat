@echo off
REM Lyrics.bat audio.mp3 [model]
REM Domyslny model: medium (770 MB, dobry kompromis). Inne: tiny / base / small / medium / large-v3
REM Output: Studio\Outputs\lyrics\<nazwa>.{lrc,srt,vtt,txt,json}
if "%~1"=="" (
    echo.
    echo Uzycie: Lyrics.bat sciezka\do\utworu.mp3 [model]
    echo Lub przeciagnij plik audio na te ikone.
    echo.
    echo Modele Whisper:
    echo   tiny     ^( 39 MB^)  najszybszy, niska jakosc
    echo   base     ^( 74 MB^)  szybki
    echo   small    ^(244 MB^)  ok
    echo   medium   ^(770 MB^)  zalecane ^(default^)
    echo   large-v3 ^(1.5 GB^) najlepsza jakosc, ~3x wolniejszy
    pause
    exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Lyrics.ps1" -InputFile "%~1" -Model "%~2"
echo.
pause
