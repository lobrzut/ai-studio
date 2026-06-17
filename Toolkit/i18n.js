/* AI Studio Portable — PL/EN i18n */
(function (global) {
  const STR = {
    pl: {
      tagline: 'ComfyUI · grafika & workflow · ACE-Step · muzyka · Toolkit',
      'edition.local': 'Wersja lokalna · Windows · 127.0.0.1',
      'btn.start_ai': 'Start AI',
      'btn.start_ai_title': 'Uruchamia ACE + Comfy (dashboard zostaje)',
      'btn.restart': 'Restart',
      'btn.restart_title': 'Stop + Start (ACE, ComfyUI, dashboard)',
      'btn.stop_ai': 'Stop AI',
      'btn.stop_ai_title': 'Zatrzymuje ACE + Comfy. Dashboard zostaje.',
      'status.checking': 'Sprawdzam serwisy...',
      'chip.open': 'Otworz',
      'chip.start': 'Start',
      'chip.stop': 'Stop',
      'chip.online': 'online',
      'chip.offline': 'offline',
      'chip.starting': 'laduje...',
      'chip.hung': 'zawieszony',
      'gpu.resources': 'Zasoby',
      'gpu.aria': 'Zasoby GPU i stacku',
      'gpu.vram': 'VRAM',
      'gpu.label': 'GPU',
      'gpu.stack_ram': 'RAM stack -- | CPU --',
      'gpu.hint': 'co 5 s | po runie Comfy soft free ~60 s',
      'gpu.no_data': 'Czekam na odczyt...',
      'gpu.no_data_err': 'Brak danych: {0}',
      'gpu.nd': 'n/d',
      'gpu.ace_off': 'ACE off',
      'gpu.comfy_off': 'Comfy off',
      'gpu.vram_nd': 'VRAM/proces n/d — patrz pasek VRAM',
      'gpu.idle_auto': 'auto idle {0} min',
      'gpu.idle_soft': 'soft free ~60 s po runie Comfy',
      'gpu.proc_hint': '{0} proc. · {1} · co 5 s',
      'section.launch': 'Wejscie do uslug',
      'section.stack': 'Stack',
      'section.postprod': 'Post-prod — przeciagnij plik audio',
      'section.folders': 'Foldery',
      'section.soon': 'Wkrotce',
      'launch.comfy_desc': 'Grafika, wideo, Manager, workflow',
      'launch.open_ui': 'Otworz UI',
      'launch.soft_vram': 'Zwolnij VRAM (soft)',
      'launch.soft_vram_desc': 'Comfy zostaje online — zrzuca modele z VRAM gdy kolejka pusta',
      'launch.soft_cta': 'Comfy soft',
      'launch.hard_gpu': 'Zwolnij GPU (hard)',
      'launch.hard_gpu_desc': 'Zabija Comfy + ACE. Gdy soft nie wystarcza lub zombie ROCm.',
      'launch.hard_cta': 'Stop AI GPU',
      'launch.idle_title': 'Co 3 min gdy Comfy bez kolejki — soft free VRAM',
      'launch.idle_name': 'Auto idle VRAM',
      'launch.idle_desc': 'Wlacz: Comfy sam zrzuca modele po bezczynnosci (3 min)',
      'launch.restart_comfy': 'Restart Comfy',
      'launch.restart_comfy_desc': 'Po zwolnieniu GPU — tylko ComfyUI :7871',
      'launch.restart_cta': 'Comfy od nowa',
      'launch.ace_desc': 'Generacja muzyki, turbo, Gradio',
      'launch.ace_tracks': 'ACE — utwory',
      'launch.ace_tracks_title': 'Folder z wygenerowanymi utworami (gradio_outputs)',
      'launch.ace_tracks_desc': 'Wszystkie wygenerowane MP3/WAV | gradio_outputs | podfoldery batch_*',
      'launch.open_folder': 'Otworz folder',
      'launch.comfy_out_title': 'ComfyUI output — ostatnie rendery',
      'launch.comfy_out_badge': 'ComfyUI output',
      'launch.latest_renders': 'Ostatnie rendery',
      'launch.latest_desc': 'PNG/JPG z ComfyUI/output — tlo = najnowszy plik',
      'launch.gallery': 'Galeria',
      'card.start_ai_desc': 'Wlacza ACE + Comfy (osobne Start/Stop na chipach)',
      'card.stop_ai_desc': 'Wylacza ACE + Comfy. Dashboard :7880 zostaje',
      'card.restart_desc': 'Stop, potem Start — ACE + Comfy + dashboard',
      'card.free_gpu': 'Zwolnij GPU',
      'card.free_gpu_desc': 'Stop Comfy + ACE (VRAM). Potem Start stack.',
      'card.install_desc': 'Po przeniesieniu folderu na nowy PC',
      'postprod.hint': 'mp3 | wav | flac | m4a | opus — po upuszczeniu otworzy sie okno PowerShell z postepm (jak drag na .bat). Strona musi byc http://127.0.0.1:7880/ (nie plik z dysku).',
      'legend.summary': 'Ktory kafelek wybrac? — podpowiedzi',
      'drop.master_tag': 'Glosnosc / eksport',
      'drop.master_hint': 'Upusc utwor tutaj',
      'drop.master_blurb': '2-pass loudnorm | domyslnie -12 LUFS | plik _mastered obok zrodla',
      'drop.stems_tag': 'Rozdzielenie sciezek',
      'drop.stems_blurb': 'Demucs -> 4x WAV (wokal, bas, drums, reszta) -> Outputs/stems/',
      'drop.match_tag': 'Brzmienie jak referencja',
      'drop.match_target': 'Match — twoj utwor',
      'drop.match_target_hint': 'Mix do dopasowania',
      'drop.match_ref': 'Referencja',
      'drop.match_ref_hint': 'Opcja | lub z References/',
      'drop.match_blurb': 'Matchering: EQ + kompresja + LUFS jak wzorzec | 2 pliki naraz = target + ref',
      'drop.lyrics_tag': 'Tekst / napisy',
      'drop.lyrics_blurb': 'Whisper -> LRC, SRT, VTT w Outputs/lyrics/',
      'drop.silence_tag': 'Dziury po ACE',
      'drop.silence_name': 'Napraw cisze',
      'drop.silence_hint': 'Skan + raport Repaint',
      'drop.silence_blurb': 'Wykrywa cisze | raport TXT | otwiera ACE :7870 | Repaint wg sekund',
      'drop.enhance_tag': 'Poprawa jakosci / enhance',
      'drop.enhance_aria': 'Tryb Enhance',
      'drop.enhance_light': 'Lekki',
      'drop.enhance_medium': 'Sredni',
      'drop.enhance_heavy': 'Ciezki',
      'drop.enhance_hint': 'Wybierz tryb | upusc utwor',
      'drop.enhance_blurb': 'light -> Outputs/enhance/light/ | medium -> AI WAV | heavy -> kolejka + ComfyUI',
      'drop.btn.comfy': 'Comfy — output',
      'drop.btn.ace': 'ACE — utwory',
      'folder.comfy_desc': 'ComfyUI/output | obrazy z workflow',
      'folder.ace_desc': 'gradio_outputs | generacje z :7870',
      'footer.hw': 'RX 6800 | ROCm | portable',
      'gallery.title': 'Galeria ComfyUI',
      'gallery.loading': 'Laduje...',
      'gallery.folder_output': 'Folder output',
      'gallery.refresh': 'Odswiez',
      'gallery.browse_aria': 'Foldery output',
      'gallery.close': 'Zamknij galerie',
      'gallery.lb_close': 'Zamknij',
      'gallery.lb_prev': 'Poprzedni',
      'gallery.lb_next': 'Nastepny',
      'gallery.lb_loading': 'Laduje podglad…',
      'gallery.lb_open': 'Otworz plik',
      'lang.pl': 'PL',
      'lang.en': 'EN',
      'lang.switch': 'Jezyk',
      'confirm.force_gpu': 'Zatrzymac ComfyUI i ACE-Step? VRAM zostanie zwolnione. Nic nie wstanie automatycznie — potem Start stack.',
      'confirm.restart_comfy': 'Zatrzymac stack AI i uruchomic od nowa tylko ComfyUI? (ACE zostanie wylaczony)',
      'confirm.force_gpu_card': 'Zatrzymac ComfyUI i ACE-Step? VRAM zwolnione — bez auto-restartu.',
      'toast.old_hub_upload': 'Stary dashboard hub — Restart stack (brak API upload)',
      'toast.old_hub_api': 'Stary hub (API v{0}). Uruchom Open-Dashboard.bat lub Restart stack — brak Zwolnij GPU / wykrywania zawieszenia.',
      'toast.no_hub': 'Brak polaczenia z hubem :7880. Uruchom Open-Dashboard.bat (nie plik HTML z dysku).',
      'toast.file_protocol': 'Otworz dashboard przez http://127.0.0.1:7880/ (upload nie dziala z pliku HTML)',
      'toast.audio_only': 'Dozwolone: mp3, wav, flac, m4a, opus...',
      'toast.match_first': 'Najpierw upusc utwor (lewa strefa)',
      'toast.match_target_ok': 'Target OK: {0} — opcjonalnie upusc referencje',
      'toast.uploading': 'Wgrywam: {0}...',
      'toast.upload_conn': 'Brak polaczenia z hubem ({0}). Otworz http://127.0.0.1:7880/ — nie plik HTML z dysku.',
      'toast.run_ok': 'Uruchomiono — sprawdz okno PowerShell',
      'toast.gallery_refreshed': 'Galeria odswiezona',
      'toast.gallery_unavailable': 'Galeria niedostepna — zrestartuj dashboard (Restart-Dashboard.bat)',
      'toast.gallery_load_fail': 'Nie udalo sie wczytac galerii.',
      'toast.lb_fail': 'Nie udalo sie zaladowac pelnego obrazu',
      'toast.err': 'Blad',
      'banner.start_stack': 'Uruchom Start stack (Install.bat nie startuje serwerow).',
      'banner.comfy_hung': 'ComfyUI nie odpowiada (moze byc zajety po runie) — poczekaj lub Zwolnij VRAM / Restart Comfy.',
      'banner.all_up': 'Stack gotowy — ComfyUI i ACE-Step dzialaja.',
      'banner.starting': 'Serwisy startuja (ACE pierwszy raz: 5-15 min). Status odswieza sie co 5 s.',
      'banner.install_only': 'Install.bat tylko instaluje — kliknij Start stack (nie sam Open-Dashboard).',
      'banner.comfy_only': 'ComfyUI dziala. ACE-Step: uruchom Start stack lub czekaj na model.',
      'banner.ace_only': 'ACE-Step dziala. Uruchom Start stack dla ComfyUI.',
      'gallery.files': '{0} plikow',
      'gallery.empty_folder': 'pusty',
      'gallery.meta_images': '{0} obrazow{1} · {2}',
      'gallery.meta_subfolders': '{0} podfolderow{1} · {2}',
      'gallery.meta_none': 'Brak obrazow{0} — wygeneruj cos w ComfyUI lub wybierz folder',
      'gallery.empty_pick': 'Wybierz folder powyzej lub przejdz glebiej.',
      'gallery.empty_noimg': 'Brak obrazow PNG/JPG w tym folderze.',
    },
    en: {
      tagline: 'ComfyUI · graphics & workflow · ACE-Step · music · Toolkit',
      'edition.local': 'Local edition · Windows · 127.0.0.1',
      'btn.start_ai': 'Start AI',
      'btn.start_ai_title': 'Starts ACE + Comfy (dashboard stays up)',
      'btn.restart': 'Restart',
      'btn.restart_title': 'Stop + Start (ACE, ComfyUI, dashboard)',
      'btn.stop_ai': 'Stop AI',
      'btn.stop_ai_title': 'Stops ACE + Comfy. Dashboard stays up.',
      'status.checking': 'Checking services...',
      'chip.open': 'Open',
      'chip.start': 'Start',
      'chip.stop': 'Stop',
      'chip.online': 'online',
      'chip.offline': 'offline',
      'chip.starting': 'loading...',
      'chip.hung': 'hung',
      'gpu.resources': 'Resources',
      'gpu.aria': 'GPU and stack resources',
      'gpu.vram': 'VRAM',
      'gpu.label': 'GPU',
      'gpu.stack_ram': 'Stack RAM -- | CPU --',
      'gpu.hint': 'every 5 s | after Comfy run soft free ~60 s',
      'gpu.no_data': 'Waiting for reading...',
      'gpu.no_data_err': 'No data: {0}',
      'gpu.nd': 'n/a',
      'gpu.ace_off': 'ACE off',
      'gpu.comfy_off': 'Comfy off',
      'gpu.vram_nd': 'VRAM/process n/a — see VRAM bar',
      'gpu.idle_auto': 'auto idle {0} min',
      'gpu.idle_soft': 'soft free ~60 s after Comfy run',
      'gpu.proc_hint': '{0} proc. · {1} · every 5 s',
      'section.launch': 'Service shortcuts',
      'section.stack': 'Stack',
      'section.postprod': 'Post-prod — drag an audio file',
      'section.folders': 'Folders',
      'section.soon': 'Coming soon',
      'launch.comfy_desc': 'Images, video, Manager, workflows',
      'launch.open_ui': 'Open UI',
      'launch.soft_vram': 'Release VRAM (soft)',
      'launch.soft_vram_desc': 'Comfy stays online — unloads models from VRAM when queue is empty',
      'launch.soft_cta': 'Comfy soft',
      'launch.hard_gpu': 'Release GPU (hard)',
      'launch.hard_gpu_desc': 'Kills Comfy + ACE. When soft is not enough or zombie ROCm.',
      'launch.hard_cta': 'Stop AI GPU',
      'launch.idle_title': 'Every 3 min when Comfy queue empty — soft free VRAM',
      'launch.idle_name': 'Auto idle VRAM',
      'launch.idle_desc': 'Enable: Comfy unloads models after idle (3 min)',
      'launch.restart_comfy': 'Restart Comfy',
      'launch.restart_comfy_desc': 'After GPU release — ComfyUI only :7871',
      'launch.restart_cta': 'Restart Comfy',
      'launch.ace_desc': 'Music generation, turbo, Gradio',
      'launch.ace_tracks': 'ACE — tracks',
      'launch.ace_tracks_title': 'Folder with generated tracks (gradio_outputs)',
      'launch.ace_tracks_desc': 'All generated MP3/WAV | gradio_outputs | batch_* subfolders',
      'launch.open_folder': 'Open folder',
      'launch.comfy_out_title': 'ComfyUI output — latest renders',
      'launch.comfy_out_badge': 'ComfyUI output',
      'launch.latest_renders': 'Latest renders',
      'launch.latest_desc': 'PNG/JPG from ComfyUI/output — background = newest file',
      'launch.gallery': 'Gallery',
      'card.start_ai_desc': 'Starts ACE + Comfy (per-service Start/Stop on chips)',
      'card.stop_ai_desc': 'Stops ACE + Comfy. Dashboard :7880 stays up',
      'card.restart_desc': 'Stop, then Start — ACE + Comfy + dashboard',
      'card.free_gpu': 'Release GPU',
      'card.free_gpu_desc': 'Stop Comfy + ACE (VRAM). Then Start stack.',
      'card.install_desc': 'After moving the folder to a new PC',
      'postprod.hint': 'mp3 | wav | flac | m4a | opus — dropping opens a PowerShell window with progress (like drag on .bat). Page must be http://127.0.0.1:7880/ (not a file:// URL).',
      'legend.summary': 'Which tile to pick? — guide',
      'drop.master_tag': 'Loudness / export',
      'drop.master_hint': 'Drop track here',
      'drop.master_blurb': '2-pass loudnorm | default -12 LUFS | _mastered file next to source',
      'drop.stems_tag': 'Stem separation',
      'drop.stems_blurb': 'Demucs -> 4x WAV (vocals, bass, drums, rest) -> Outputs/stems/',
      'drop.match_tag': 'Sound like reference',
      'drop.match_target': 'Match — your track',
      'drop.match_target_hint': 'Mix to match',
      'drop.match_ref': 'Reference',
      'drop.match_ref_hint': 'Optional | or from References/',
      'drop.match_blurb': 'Matchering: EQ + compression + LUFS like reference | 2 files at once = target + ref',
      'drop.lyrics_tag': 'Lyrics / subtitles',
      'drop.lyrics_blurb': 'Whisper -> LRC, SRT, VTT in Outputs/lyrics/',
      'drop.silence_tag': 'ACE gaps',
      'drop.silence_name': 'Fix silence',
      'drop.silence_hint': 'Scan + Repaint report',
      'drop.silence_blurb': 'Detects silence | TXT report | opens ACE :7870 | Repaint by seconds',
      'drop.enhance_tag': 'Quality / enhance',
      'drop.enhance_aria': 'Enhance mode',
      'drop.enhance_light': 'Light',
      'drop.enhance_medium': 'Medium',
      'drop.enhance_heavy': 'Heavy',
      'drop.enhance_hint': 'Pick mode | drop track',
      'drop.enhance_blurb': 'light -> Outputs/enhance/light/ | medium -> AI WAV | heavy -> queue + ComfyUI',
      'drop.btn.comfy': 'Comfy — output',
      'drop.btn.ace': 'ACE — tracks',
      'folder.comfy_desc': 'ComfyUI/output | images from workflows',
      'folder.ace_desc': 'gradio_outputs | generations from :7870',
      'footer.hw': 'RX 6800 | ROCm | portable',
      'gallery.title': 'ComfyUI Gallery',
      'gallery.loading': 'Loading...',
      'gallery.folder_output': 'Output folder',
      'gallery.refresh': 'Refresh',
      'gallery.browse_aria': 'Output folders',
      'gallery.close': 'Close gallery',
      'gallery.lb_close': 'Close',
      'gallery.lb_prev': 'Previous',
      'gallery.lb_next': 'Next',
      'gallery.lb_loading': 'Loading preview…',
      'gallery.lb_open': 'Open file',
      'lang.pl': 'PL',
      'lang.en': 'EN',
      'lang.switch': 'Language',
      'confirm.force_gpu': 'Stop ComfyUI and ACE-Step? VRAM will be released. Nothing auto-starts — then Start stack.',
      'confirm.restart_comfy': 'Stop AI stack and restart ComfyUI only? (ACE will be disabled)',
      'confirm.force_gpu_card': 'Stop ComfyUI and ACE-Step? VRAM released — no auto-restart.',
      'toast.old_hub_upload': 'Old dashboard hub — Restart stack (no upload API)',
      'toast.old_hub_api': 'Old hub (API v{0}). Run Open-Dashboard.bat or Restart stack — no Release GPU / hang detection.',
      'toast.no_hub': 'Cannot reach hub :7880. Run Open-Dashboard.bat (not an HTML file from disk).',
      'toast.file_protocol': 'Open dashboard at http://127.0.0.1:7880/ (upload does not work from file://)',
      'toast.audio_only': 'Allowed: mp3, wav, flac, m4a, opus...',
      'toast.match_first': 'Drop your track first (left zone)',
      'toast.match_target_ok': 'Target OK: {0} — optionally drop reference',
      'toast.uploading': 'Uploading: {0}...',
      'toast.upload_conn': 'Cannot reach hub ({0}). Open http://127.0.0.1:7880/ — not an HTML file from disk.',
      'toast.run_ok': 'Started — check the PowerShell window',
      'toast.gallery_refreshed': 'Gallery refreshed',
      'toast.gallery_unavailable': 'Gallery unavailable — restart dashboard (Restart-Dashboard.bat)',
      'toast.gallery_load_fail': 'Failed to load gallery.',
      'toast.lb_fail': 'Failed to load full image',
      'toast.err': 'Error',
      'banner.start_stack': 'Run Start stack (Install.bat does not start servers).',
      'banner.comfy_hung': 'ComfyUI not responding (may be busy after a run) — wait or Release VRAM / Restart Comfy.',
      'banner.all_up': 'Stack ready — ComfyUI and ACE-Step are running.',
      'banner.starting': 'Services starting (ACE first run: 5-15 min). Status refreshes every 5 s.',
      'banner.install_only': 'Install.bat only installs — click Start stack (not just Open-Dashboard).',
      'banner.comfy_only': 'ComfyUI running. ACE-Step: run Start stack or wait for model.',
      'banner.ace_only': 'ACE-Step running. Run Start stack for ComfyUI.',
      'gallery.files': '{0} files',
      'gallery.empty_folder': 'empty',
      'gallery.meta_images': '{0} images{1} · {2}',
      'gallery.meta_subfolders': '{0} subfolders{1} · {2}',
      'gallery.meta_none': 'No images{0} — generate in ComfyUI or pick a folder',
      'gallery.empty_pick': 'Pick a folder above or go deeper.',
      'gallery.empty_noimg': 'No PNG/JPG images in this folder.',
    },
  };

  const LEGEND = {
    pl: {
      master: `<h3><span class="legend-icon ico ico-diamond" aria-hidden="true"></span> Master</h3>
        <p><strong>Co robi:</strong> Ustawia docelowa glosnosc (ffmpeg loudnorm, 2 przebiegi).</p>
        <p><strong>Kiedy:</strong> Mix juz brzmi OK, chcesz glosny, spojny eksport (-12 LUFS).</p>
        <p class="legend-no"><strong>Nie robi:</strong> Nie naprawia slabej jakosci MP3 ani nie "AI-enhance".</p>
        <p class="legend-out">Wynik: <code>nazwa_mastered.ext</code> obok oryginalu</p>`,
      stems: `<h3><span class="legend-icon ico ico-comfy" aria-hidden="true"></span> Stems</h3>
        <p><strong>Co robi:</strong> Rozdziela utwor na 4 sciezki (Demucs: wokal, bas, perkusja, inne).</p>
        <p><strong>Kiedy:</strong> Remiks, karaoke, edycja pojedynczych warstw.</p>
        <p class="legend-out">Wynik: <code>Toolkit/Outputs/stems/</code></p>`,
      match: `<h3><span class="legend-icon ico ico-match" aria-hidden="true"></span> Match</h3>
        <p><strong>Co robi:</strong> Auto-mastering — dopasowuje EQ, kompresje i glosnosc twojego mixu do <em>referencji</em> (np. ulubiony utwor).</p>
        <p><strong>Kiedy:</strong> Twoj mix brzmi "cienko" / inaczej niz wzorzec — najblizej "ulepsz brzmienie" w tym stacku.</p>
        <p><strong>Jak:</strong> Lewa strefa = twoj utwor; prawa = referencja (opcja). Bez referencji — bierze najnowszy plik z <code>References/</code>. Mozesz upuscic 2 pliki naraz na caly kafelek.</p>
        <p class="legend-out">Wynik: <code>Toolkit/Outputs/mastered/</code></p>`,
      lyrics: `<h3><span class="legend-icon ico ico-lyrics" aria-hidden="true"></span> Lyrics</h3>
        <p><strong>Co robi:</strong> Rozpoznaje tekst (Whisper) i zapisuje napisy zsynchronizowane w czasie.</p>
        <p><strong>Kiedy:</strong> LRC do odtwarzacza, SRT/VTT do wideo, karaoke.</p>
        <p class="legend-out">Wynik: <code>Toolkit/Outputs/lyrics/</code> (.lrc, .srt, .vtt)</p>`,
      silence: `<h3><span class="legend-icon ico ico-silence" aria-hidden="true"></span> Napraw cisze</h3>
        <p><strong>Co robi:</strong> Skanuje utwor i wypisuje <em>sekundy ciszy</em> (dziury po ACE), zapisuje raport TXT.</p>
        <p><strong>Kiedy:</strong> Wygenerowany kawalek ma puste fragmenty — tam mialo byc audio, a jest cisza.</p>
        <p><strong>Dalej:</strong> ACE-Step tryb <strong>Repaint</strong> z sekundami z raportu (otwiera :7870).</p>
        <p class="legend-out">Wynik: <code>Toolkit/Outputs/silence/*_repaint_*.txt</code></p>`,
      enhance: `<h3><span class="legend-icon ico ico-enhance" aria-hidden="true"></span> Enhance</h3>
        <p><strong>Lekki:</strong> ffmpeg — odszumienie, EQ, kompresja (szybko, bez instalacji AI).</p>
        <p><strong>Sredni:</strong> Resemble Enhance — AI denoise + poprawa (mowa/wokal najlepiej; instaluje <code>Install.bat</code>).</p>
        <p><strong>Ciezki:</strong> kopiuje plik do kolejki ComfyUI + otwiera :7871 (workflow audio w Managerze).</p>
        <p class="legend-out">Wynik: <code>Outputs/enhance/light|medium|comfy_queue/</code></p>`,
    },
    en: {
      master: `<h3><span class="legend-icon ico ico-diamond" aria-hidden="true"></span> Master</h3>
        <p><strong>What it does:</strong> Sets target loudness (ffmpeg loudnorm, 2 passes).</p>
        <p><strong>When:</strong> Mix already sounds OK, you want a loud, consistent export (-12 LUFS).</p>
        <p class="legend-no"><strong>Does not:</strong> Fix poor MP3 quality or "AI-enhance".</p>
        <p class="legend-out">Output: <code>name_mastered.ext</code> next to original</p>`,
      stems: `<h3><span class="legend-icon ico ico-comfy" aria-hidden="true"></span> Stems</h3>
        <p><strong>What it does:</strong> Splits track into 4 stems (Demucs: vocals, bass, drums, other).</p>
        <p><strong>When:</strong> Remix, karaoke, editing individual layers.</p>
        <p class="legend-out">Output: <code>Toolkit/Outputs/stems/</code></p>`,
      match: `<h3><span class="legend-icon ico ico-match" aria-hidden="true"></span> Match</h3>
        <p><strong>What it does:</strong> Auto-mastering — matches EQ, compression and loudness of your mix to a <em>reference</em> track.</p>
        <p><strong>When:</strong> Your mix sounds thin / different from reference — closest to "improve sound" in this stack.</p>
        <p><strong>How:</strong> Left zone = your track; right = reference (optional). Without reference — uses newest file from <code>References/</code>. Drop 2 files on the whole tile at once.</p>
        <p class="legend-out">Output: <code>Toolkit/Outputs/mastered/</code></p>`,
      lyrics: `<h3><span class="legend-icon ico ico-lyrics" aria-hidden="true"></span> Lyrics</h3>
        <p><strong>What it does:</strong> Transcribes lyrics (Whisper) and writes time-synced subtitles.</p>
        <p><strong>When:</strong> LRC for players, SRT/VTT for video, karaoke.</p>
        <p class="legend-out">Output: <code>Toolkit/Outputs/lyrics/</code> (.lrc, .srt, .vtt)</p>`,
      silence: `<h3><span class="legend-icon ico ico-silence" aria-hidden="true"></span> Fix silence</h3>
        <p><strong>What it does:</strong> Scans track and lists <em>silence seconds</em> (ACE gaps), saves TXT report.</p>
        <p><strong>When:</strong> Generated song has empty sections — audio should be there but is silent.</p>
        <p><strong>Next:</strong> ACE-Step <strong>Repaint</strong> mode with seconds from report (opens :7870).</p>
        <p class="legend-out">Output: <code>Toolkit/Outputs/silence/*_repaint_*.txt</code></p>`,
      enhance: `<h3><span class="legend-icon ico ico-enhance" aria-hidden="true"></span> Enhance</h3>
        <p><strong>Light:</strong> ffmpeg — denoise, EQ, compression (fast, no AI install).</p>
        <p><strong>Medium:</strong> Resemble Enhance — AI denoise + improve (speech/vocals best; install via <code>Install.bat</code>).</p>
        <p><strong>Heavy:</strong> copies file to ComfyUI queue + opens :7871 (audio workflow in Manager).</p>
        <p class="legend-out">Output: <code>Outputs/enhance/light|medium|comfy_queue/</code></p>`,
    },
  };

  let locale = 'pl';
  let onChange = null;

  function fmt(str, ...args) {
    return String(str).replace(/\{(\d+)\}/g, (_, i) => (args[Number(i)] != null ? args[Number(i)] : ''));
  }

  function t(key, ...args) {
    const table = STR[locale] || STR.pl;
    const s = table[key] ?? STR.pl[key] ?? key;
    return args.length ? fmt(s, ...args) : s;
  }

  function dateLocale() {
    return locale === 'en' ? 'en-GB' : 'pl-PL';
  }

  function applyLegend() {
    const table = LEGEND[locale] || LEGEND.pl;
    document.querySelectorAll('[data-legend]').forEach((el) => {
      const k = el.dataset.legend;
      if (table[k]) el.innerHTML = table[k];
    });
  }

  function apply(root = document) {
    root.querySelectorAll('[data-i18n]').forEach((el) => {
      const key = el.dataset.i18n;
      if (key) el.textContent = t(key);
    });
    root.querySelectorAll('[data-i18n-title]').forEach((el) => {
      el.title = t(el.dataset.i18nTitle);
    });
    root.querySelectorAll('[data-i18n-aria]').forEach((el) => {
      el.setAttribute('aria-label', t(el.dataset.i18nAria));
    });
    root.querySelectorAll('[data-i18n-placeholder]').forEach((el) => {
      el.placeholder = t(el.dataset.i18nPlaceholder);
    });
    applyLegend();
    document.documentElement.lang = locale;
    document.querySelectorAll('[data-lang-btn]').forEach((btn) => {
      btn.classList.toggle('is-active', btn.dataset.langBtn === locale);
      btn.setAttribute('aria-pressed', btn.dataset.langBtn === locale ? 'true' : 'false');
    });
    if (typeof onChange === 'function') onChange(locale);
  }

  async function fetchLocale() {
    let fromApi = false;
    try {
      const r = await fetch('/api/locale');
      if (r.ok) {
        const j = await r.json();
        if (j.locale === 'en' || j.locale === 'pl') {
          locale = j.locale;
          fromApi = true;
        }
      }
    } catch { /* hub offline */ }
    if (!fromApi) {
      try {
        const stored = localStorage.getItem('ai-studio-locale');
        if (stored === 'en' || stored === 'pl') locale = stored;
      } catch { /* private mode */ }
    }
  }

  async function setLocale(next, persist = true) {
    if (next !== 'pl' && next !== 'en') return;
    locale = next;
    try { localStorage.setItem('ai-studio-locale', locale); } catch { /* */ }
    apply();
    if (persist) {
      try {
        await fetch(`/api/locale?lang=${encodeURIComponent(locale)}`, { method: 'POST' });
      } catch { /* offline */ }
    }
  }

  function confirmKey(el) {
    const k = el?.dataset?.i18nConfirm;
    return k ? t(k) : el?.dataset?.confirm || '';
  }

  async function init(opts = {}) {
    onChange = opts.onChange || null;
    await fetchLocale();
    apply();
    document.querySelectorAll('[data-lang-btn]').forEach((btn) => {
      btn.addEventListener('click', () => setLocale(btn.dataset.langBtn));
    });
  }

  global.I18n = { t, apply, init, setLocale, getLocale: () => locale, dateLocale, confirmKey, fmt };
})(window);
