#Requires -Version 5.1
# Shared PL/EN strings for dashboard hub, tray, and stack scripts.
if (Get-Command Get-StudioLocale -ErrorAction SilentlyContinue) { return }

function Get-LocaleEnvPath {
    $toolkit = if ($PSScriptRoot -match 'Toolkit$') { $PSScriptRoot } else { Join-Path $PSScriptRoot 'Toolkit' }
    return Join-Path $toolkit 'locale.env'
}

function Get-StudioLocale {
    $path = Get-LocaleEnvPath
    if (Test-Path -LiteralPath $path) {
        $line = (Get-Content -LiteralPath $path -TotalCount 1 -ErrorAction SilentlyContinue)
        if ($line -match '^\s*LANG\s*=\s*(pl|en)\s*$') { return $Matches[1] }
    }
    try {
        $ui = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName
        if ($ui -eq 'en') { return 'en' }
    } catch { }
    return 'pl'
}

function Set-StudioLocale([ValidateSet('pl', 'en')][string]$Lang) {
    $path = Get-LocaleEnvPath
    $dir = Split-Path $path -Parent
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    "LANG=$Lang" | Set-Content -LiteralPath $path -Encoding UTF8 -NoNewline
}

$script:StudioLocaleStrings = @{
    pl = @{
        svc_not_installed       = '{0} nie zainstalowany. Uruchom Install.bat.'
        svc_already_running     = '{0} juz dziala (:{1}).'
        svc_starting            = '{0} startuje (launcher PID {1}). Port :{2} za 30-90 s. Log: logs\{3}.stderr.log'
        svc_stopped             = '{0} zatrzymany (:{1} wolny).'
        svc_port_busy           = '{0}: port :{1} nadal zajety. Sprobuj Zwolnij GPU (hard) lub restart PC.'
        svc_comfy_running       = 'ComfyUI juz dziala.'
        svc_ace_running         = 'ACE-Step juz dziala.'
        hub_already_running     = 'Dashboard hub juz dziala (:7880).'
        hub_started             = 'Dashboard hub uruchomiony (:7880).'
        hub_failed              = 'Dashboard hub nie wstal. Sprawdz logs\dashboard.stderr.log'
        hub_no_tray             = 'Brak ikony tray. Uruchom Open-Dashboard.bat lub Start.bat (stack zyje tylko z tray).'
        action_restart_stack    = 'Restart: Stop + Start (~30-90 s). Odswiez strone za chwile.'
        action_install          = 'Uruchomiono Install.bat'
        action_force_gpu        = 'GPU: stop Comfy + ACE (bez restartu). Okno PS + log logs\force-gpu.last.log'
        action_restart_comfy    = 'Restart ComfyUI po zwolnieniu GPU (ACE wylaczony).'
        action_soft_vram_ok     = 'ComfyUI: modele zrzucane z VRAM (serwis zostaje online).'
        action_gpu_idle_on      = 'Auto idle ON: Comfy soft free co {0} min (gdy kolejka pusta).'
        action_gpu_idle_off     = 'Auto idle wylaczone.'
        action_ace_outputs      = 'ACE utwory: {0}'
        action_comfy_outputs    = 'Comfy output: {0}'
        drop_master             = 'Master: {0}'
        drop_stems              = 'Stems (Demucs): {0}'
        drop_lyrics             = 'Lyrics (Whisper): {0}'
        drop_match              = 'Match: {0}'
        drop_match_ref          = 'Match: {0} vs {1}'
        drop_match_refs_folder  = 'Match: {0} (referencja z References\)'
        drop_enhance            = 'Enhance ({0}): {1}'
        drop_silence            = 'Napraw cisze: {0}'
        err_unknown_action      = 'Nieznana akcja: {0}'
        err_unknown_drop        = 'Nieznany drop: {0}'
        err_missing_name        = 'Brak parametru name'
        err_missing_kind        = 'Brak parametru kind'
        err_missing_filename    = 'Brak nazwy pliku (name lub naglowek X-File-Name)'
        err_comfy_busy          = 'ComfyUI zajety: {0}'
        tray_open_dashboard     = 'Otworz dashboard'
        tray_start_ace          = 'Start ACE-Step'
        tray_stop_ace           = 'Stop ACE-Step'
        tray_start_comfy        = 'Start ComfyUI'
        tray_stop_comfy         = 'Stop ComfyUI'
        tray_start_both         = 'Start AI (oba)'
        tray_stop_both          = 'Stop AI (oba)'
        tray_soft_vram          = 'Zwolnij VRAM (soft, Comfy)'
        tray_hard_gpu           = 'Zwolnij GPU (hard)'
        tray_show_status        = 'Pokaz status...'
        tray_restart_hub        = 'Restart dashboard hub'
        tray_exit               = 'Zamknij AI Studio (wszystko)'
        tray_lang_pl            = 'Jezyk: Polski'
        tray_lang_en            = 'Language: English'
        tray_confirm_hard       = 'Zatrzymac ComfyUI i ACE-Step i zwolnic VRAM?'
        tray_confirm_exit       = 'Zatrzymac hub, ACE, Comfy i zamknac ikone tray?'
        tray_status_title       = 'AI Studio - status'
        tray_boot_ready         = 'Dashboard gotowy: http://127.0.0.1:7880/'
        tray_starting_hub       = 'Uruchamiam dashboard hub...'
        tray_hub_running        = 'Dashboard hub juz dziala (:7880).'
        tray_hub_start_err      = 'Hub start blad: {0}'
        tray_tip_offline        = "AI Studio Portable`nHub: offline`nZamknij tray = caly stack OFF"
        tray_tip_online         = 'AI Studio Portable (tray ON)'
        tray_tip_close          = 'Zamknij tray = caly stack OFF'
        tray_balloon_icon       = 'Ikona przy zegarze (zolte A).'
        tray_balloon_hidden     = 'Jesli jej nie widzisz: strzalka ^ przy zegarze -> Ikony zasobnika.'
        tray_err_start          = "Tray nie moze wystartowac:`n{0}`n`nLog: logs\tray.log"
        tray_soft_free          = 'Soft free VRAM (Comfy)'
        tray_hard_free          = 'Zwolniono GPU (hard)'
        tray_err_action         = 'Blad: {0}'
        install_title           = 'AI Studio Portable — instalacja'
        install_done            = 'INSTALACJA ZAKONCZONA'
        install_no_servers      = 'Install.bat NIE uruchamia ACE-Step ani ComfyUI.'
        install_use_start       = 'Serwery startuje dopiero:  Start.bat'
        install_first_start     = 'Pierwszy Start moze trwac 5-15 min (ladowanie modeli na GPU).'
        install_run_start       = 'Uruchomic Start.bat teraz? (T = tak / N = pozniej)'
        install_addresses       = 'Adresy po Start.bat:'
        install_enhance_warn    = 'UWAGA: Enhance AI nie zainstalowany — sredni tryb Enhance niedostepny do czasu naprawy pip.'
        install_gpu_sync        = 'Profil GPU zsynchronizowany do ComfyUI'
        install_ace_fail        = 'ACE-Step Install.ps1 nieudany.'
        install_comfy_fail      = 'ComfyUI Install.ps1 nieudany.'
        install_start_incomplete = 'Start niekompletny — sprawdz logs\ (modele moga jeszcze ladowac).'
        start_title             = 'AI Studio Portable - Dashboard'
        start_first_run         = 'Pierwsze uruchomienie — Install.ps1 (moze potrwac)...'
        start_install_fail      = 'Install.ps1 nieudany.'
        start_ace_not_ready     = 'ACE-Step nie gotowy. Uruchom Install.bat.'
        start_comfy_not_ready   = 'ComfyUI nie gotowy. Uruchom Install.bat.'
        start_already_running   = 'Dashboard juz dziala (ikona tray przy zegarze).'
        start_tray_broken       = 'Tray uszkodzony (stary lock) — restart...'
        start_tray_timeout      = 'WARN: Tray nie potwierdzil startu w 20 s — sprawdz logs\tray.log'
        start_tray_hint         = '      Sprobuj: Stop.bat, potem Start.bat. Ikona moze byc w ukrytych przy zegarze.'
        start_ok                = 'OK: Dashboard uruchomiony (tray + http://127.0.0.1:7880/)'
        start_ai_hint           = '     ACE/Comfy: Start z dashboardu lub menu tray.'
        start_with_ai           = '     AI: auto-start wlaczony (-WithAi).'
        start_close_hint        = '     Zamkniecie: tray -> Zamknij AI Studio, lub Stop.bat'
        stop_title              = '==> Stop AI Studio (stack + tray)'
        stop_warn_ports         = 'WARN: nadal cos slucha na 7870/7871/7880 — sprobuj ponownie lub reboot.'
        stop_ok                 = 'OK: stack wylaczony. Bez ikony tray nic nie dziala.'
    }
    en = @{
        svc_not_installed       = '{0} is not installed. Run Install.bat.'
        svc_already_running     = '{0} is already running (:{1}).'
        svc_starting            = '{0} starting (launcher PID {1}). Port :{2} in 30-90 s. Log: logs\{3}.stderr.log'
        svc_stopped             = '{0} stopped (:{1} free).'
        svc_port_busy           = '{0}: port :{1} still in use. Try Release GPU (hard) or reboot.'
        svc_comfy_running       = 'ComfyUI is already running.'
        svc_ace_running         = 'ACE-Step is already running.'
        hub_already_running     = 'Dashboard hub is already running (:7880).'
        hub_started             = 'Dashboard hub started (:7880).'
        hub_failed              = 'Dashboard hub failed to start. Check logs\dashboard.stderr.log'
        hub_no_tray             = 'Tray icon missing. Run Open-Dashboard.bat or Start.bat (stack only runs with tray).'
        action_restart_stack    = 'Restart: Stop + Start (~30-90 s). Refresh the page shortly.'
        action_install          = 'Install.bat launched'
        action_force_gpu        = 'GPU: stop Comfy + ACE (no auto-restart). PS window + log logs\force-gpu.last.log'
        action_restart_comfy    = 'Restart ComfyUI after GPU release (ACE disabled).'
        action_soft_vram_ok     = 'ComfyUI: models unloaded from VRAM (service stays online).'
        action_gpu_idle_on      = 'Auto idle ON: Comfy soft free every {0} min (when queue empty).'
        action_gpu_idle_off     = 'Auto idle disabled.'
        action_ace_outputs      = 'ACE tracks: {0}'
        action_comfy_outputs    = 'Comfy output: {0}'
        drop_master             = 'Master: {0}'
        drop_stems              = 'Stems (Demucs): {0}'
        drop_lyrics             = 'Lyrics (Whisper): {0}'
        drop_match              = 'Match: {0}'
        drop_match_ref          = 'Match: {0} vs {1}'
        drop_match_refs_folder  = 'Match: {0} (reference from References\)'
        drop_enhance            = 'Enhance ({0}): {1}'
        drop_silence            = 'Fix silence: {0}'
        err_unknown_action      = 'Unknown action: {0}'
        err_unknown_drop        = 'Unknown drop: {0}'
        err_missing_name        = 'Missing name parameter'
        err_missing_kind        = 'Missing kind parameter'
        err_missing_filename    = 'Missing file name (name or X-File-Name header)'
        err_comfy_busy          = 'ComfyUI busy: {0}'
        tray_open_dashboard     = 'Open dashboard'
        tray_start_ace          = 'Start ACE-Step'
        tray_stop_ace           = 'Stop ACE-Step'
        tray_start_comfy        = 'Start ComfyUI'
        tray_stop_comfy         = 'Stop ComfyUI'
        tray_start_both         = 'Start AI (both)'
        tray_stop_both          = 'Stop AI (both)'
        tray_soft_vram          = 'Release VRAM (soft, Comfy)'
        tray_hard_gpu           = 'Release GPU (hard)'
        tray_show_status        = 'Show status...'
        tray_restart_hub        = 'Restart dashboard hub'
        tray_exit               = 'Quit AI Studio (everything)'
        tray_lang_pl            = 'Jezyk: Polski'
        tray_lang_en            = 'Language: English'
        tray_confirm_hard       = 'Stop ComfyUI and ACE-Step and release VRAM?'
        tray_confirm_exit       = 'Stop hub, ACE, Comfy and close tray icon?'
        tray_status_title       = 'AI Studio - status'
        tray_boot_ready         = 'Dashboard ready: http://127.0.0.1:7880/'
        tray_starting_hub       = 'Starting dashboard hub...'
        tray_hub_running        = 'Dashboard hub already running (:7880).'
        tray_hub_start_err      = 'Hub start error: {0}'
        tray_tip_offline        = "AI Studio Portable`nHub: offline`nQuit tray = entire stack OFF"
        tray_tip_online         = 'AI Studio Portable (tray ON)'
        tray_tip_close          = 'Quit tray = entire stack OFF'
        tray_balloon_icon       = 'Icon in the system tray (yellow A).'
        tray_balloon_hidden     = 'If hidden: click ^ near the clock -> Notification area icons.'
        tray_err_start          = "Tray cannot start:`n{0}`n`nLog: logs\tray.log"
        tray_soft_free          = 'Soft free VRAM (Comfy)'
        tray_hard_free          = 'GPU released (hard)'
        tray_err_action         = 'Error: {0}'
        install_title           = 'AI Studio Portable — installation'
        install_done            = 'INSTALLATION COMPLETE'
        install_no_servers      = 'Install.bat does NOT start ACE-Step or ComfyUI.'
        install_use_start       = 'Servers start with:  Start.bat'
        install_first_start     = 'First Start may take 5-15 min (loading models on GPU).'
        install_run_start       = 'Run Start.bat now? (Y = yes / N = later)'
        install_addresses       = 'URLs after Start.bat:'
        install_enhance_warn    = 'WARNING: Enhance AI not installed — medium Enhance mode unavailable until pip is fixed.'
        install_gpu_sync        = 'GPU profile synced to ComfyUI'
        install_ace_fail        = 'ACE-Step Install.ps1 failed.'
        install_comfy_fail      = 'ComfyUI Install.ps1 failed.'
        install_start_incomplete = 'Start incomplete — check logs\ (models may still be loading).'
        start_title             = 'AI Studio Portable - Dashboard'
        start_first_run         = 'First run — Install.ps1 (may take a while)...'
        start_install_fail      = 'Install.ps1 failed.'
        start_ace_not_ready     = 'ACE-Step not ready. Run Install.bat.'
        start_comfy_not_ready   = 'ComfyUI not ready. Run Install.bat.'
        start_already_running   = 'Dashboard already running (tray icon near clock).'
        start_tray_broken       = 'Tray broken (stale lock) — restarting...'
        start_tray_timeout      = 'WARN: Tray did not confirm start within 20 s — check logs\tray.log'
        start_tray_hint         = '      Try: Stop.bat, then Start.bat. Icon may be in hidden tray icons.'
        start_ok                = 'OK: Dashboard started (tray + http://127.0.0.1:7880/)'
        start_ai_hint           = '     ACE/Comfy: Start from dashboard or tray menu.'
        start_with_ai           = '     AI: auto-start enabled (-WithAi).'
        start_close_hint        = '     To quit: tray -> Quit AI Studio, or Stop.bat'
        stop_title              = '==> Stop AI Studio (stack + tray)'
        stop_warn_ports         = 'WARN: something still listens on 7870/7871/7880 — retry or reboot.'
        stop_ok                 = 'OK: stack stopped. Without tray icon nothing runs.'
    }
}

function L([Parameter(Mandatory)][string]$Key, [object[]]$Args = @()) {
    $loc = Get-StudioLocale
    $table = $script:StudioLocaleStrings[$loc]
    if (-not $table) { $table = $script:StudioLocaleStrings['pl'] }
    $fmt = $table[$Key]
    if (-not $fmt) {
        $fmt = $script:StudioLocaleStrings['pl'][$Key]
        if (-not $fmt) { return $Key }
    }
    if ($Args -and $Args.Count -gt 0) { return [string]::Format($fmt, $Args) }
    return $fmt
}
