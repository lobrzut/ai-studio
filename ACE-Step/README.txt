ACE-Step 1.5 — Portable
=======================

Co to jest:
  Samodzielny folder, ktory mozesz skopiowac na dowolny komputer z Windows 10/11.
  Brak instalacji w systemie. Wszystko (Python, Git, modele, venv) siedzi tutaj.

Pierwsze uruchomienie:
  1. Dwuklik 'Install.bat'  → wykryje GPU i pobierze wlasciwy stos (5-10 min + ~5-10 GB).
  2. Dwuklik 'Start.bat'    → uruchomi serwer i otworzy przegladarke na 127.0.0.1:7860.
                               PIERWSZE uruchomienie pobiera modele (~5-10 GB) do models/.
  3. Dwuklik 'Stop.bat'     → zatrzyma serwer.

Przeniesienie na inny komputer:
  1. Skopiuj caly folder (z 'models/' zeby nie pobierac modeli ponownie, ale BEZ
     'python/' jesli inne GPU — wymusza wtedy swiezy install pod docelowa karte).
  2. Na nowym PC: dwuklik 'Install.bat'. Skrypt sprawdzi GPU i:
       - jesli ten sam backend (np. AMD->AMD) i 'python/' istnieje → tylko zwery-
         fikuje, nic nie pobiera,
       - jesli inny backend (AMD->NVIDIA) → przebuduje site-packages,
       - jesli brak 'python/' → pobierze wszystko od zera.

Wymagania per backend:
  AMD ROCm 7.2:  Windows 11, sterownik AMD Adrenalin >= 26.1.1, RX 6000+/7000+/9000+
                 (RX 6800 = gfx1030 → HSA_OVERRIDE_GFX_VERSION=10.3.0, auto).
  NVIDIA CUDA:   sterownik z CUDA 12.4 lub nowszy, RTX 20xx+, ~6 GB VRAM minimum.
  CPU:           dziala wszedzie, ale BARDZO wolno (~20-40 min na utwor).

Parametry Install.ps1 (gdyby cos):
  -Force                  → wyczysc python/ i postaw od zera
  -GpuVendor amd|nvidia|cpu  → wymus backend (gdy detekcja klamie)
  -HsaOverride 10.3.0     → wymus HSA dla AMD
  -DesktopShortcuts       → dodatkowo polozy ikony na pulpicie

Layout po instalacji:
  python/             embeddable Python 3.12 + pakiety
  PortableGit/        MinGit do clone/pull
  ACE-Step-1.5/       repo (auto-update przy kazdym Install)
  models/             modele HF (HF_HOME wskazany tutaj)
  gpu_profile.env     wynik detekcji GPU
  Install.bat/.ps1    instalator
  Start.bat           uruchamia serwer
  Stop.bat/.ps1       zatrzymuje serwer
