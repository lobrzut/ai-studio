const API = '';
const HUB_API_VERSION = 8;
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

const MOTION_MS = 420;

function prefersReducedMotion() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches;
}

function withViewTransition(update) {
  if (prefersReducedMotion() || typeof document.startViewTransition !== 'function') {
    update();
    return;
  }
  document.startViewTransition(() => update());
}

function openOverlay(el, bodyClass, onOpen) {
  if (!el) return;
  el.removeAttribute('hidden');
  el.setAttribute('aria-hidden', 'false');
  el.classList.remove('is-closing');
  onOpen?.();
  requestAnimationFrame(() => {
    requestAnimationFrame(() => el.classList.add('is-open'));
  });
  if (bodyClass) document.body.classList.add(bodyClass);
}

function closeOverlay(el, bodyClass, onClosed) {
  if (!el || (!el.classList.contains('is-open') && el.hasAttribute('hidden'))) return;
  el.classList.remove('is-open');
  el.classList.add('is-closing');
  if (bodyClass) document.body.classList.remove(bodyClass);
  const finish = () => {
    el.classList.remove('is-closing');
    el.setAttribute('hidden', '');
    el.setAttribute('aria-hidden', 'true');
    onClosed?.();
  };
  if (prefersReducedMotion()) {
    finish();
    return;
  }
  let done = false;
  const end = () => {
    if (done) return;
    done = true;
    finish();
  };
  const animEl =
    el.querySelector('.gallery-modal-panel') || el.querySelector('.gallery-lb-figure') || el;
  animEl.addEventListener('transitionend', end, { once: true });
  setTimeout(end, 720);
}

const AUDIO_EXT = /\.(mp3|wav|flac|m4a|opus|ogg|aac|wma)$/i;

async function fetchStatus() {
  const r = await fetch(`${API}/api/status`);
  return r.json();
}

function formatGb(mb) {
  if (mb == null || Number.isNaN(mb)) return '--';
  return (mb / 1024).toFixed(1);
}

function formatMb(mb) {
  if (mb == null || Number.isNaN(mb)) return '--';
  return `${Math.round(mb)} MB`;
}

function setBar(barEl, pct, hotFrom = 85) {
  if (!barEl) return;
  const p = Math.max(0, Math.min(100, pct));
  barEl.style.width = `${p}%`;
  barEl.parentElement?.setAttribute('aria-valuenow', String(Math.round(p)));
  barEl.classList.toggle('hot', p >= hotFrom);
}

function updateGpuMeter(gpu, hub) {
  const root = $('#gpu-meter');
  if (!root) return;
  const nameEl = $('#gpu-meter-name');
  const utilTxt = $('#gpu-meter-util-txt');
  const vramText = $('#gpu-meter-vram');
  const barUtil = $('#gpu-bar-util');
  const barVram = $('#gpu-bar-vram');
  const stackLine = $('#gpu-meter-stack');
  const breakdown = $('#gpu-meter-breakdown');
  const hint = $('#gpu-meter-hint');

  if (!gpu || !gpu.available) {
    root.classList.add('unavailable');
    if (nameEl) nameEl.textContent = gpu?.name || 'GPU';
    if (utilTxt) utilTxt.textContent = 'n/d';
    if (vramText) vramText.textContent = '-- / -- GB';
    setBar(barUtil, 0);
    setBar(barVram, 0);
    if (stackLine) stackLine.textContent = 'RAM stack -- · CPU --';
    if (breakdown) breakdown.textContent = '';
    if (hint) hint.textContent = gpu?.error ? `Brak danych: ${gpu.error}` : 'Czekam na odczyt...';
    return;
  }

  root.classList.remove('unavailable');
  const utilAvailable = gpu.util_available !== false && gpu.util_pct != null;
  const util = utilAvailable ? Math.max(0, Math.min(100, Number(gpu.util_pct) || 0)) : 0;
  const usedMb = Number(gpu.vram_used_mb) || 0;
  const totalMb = Number(gpu.vram_total_mb) || 16384;
  const vramPct = totalMb > 0 ? (usedMb / totalMb) * 100 : 0;
  const st = gpu.stack || {};

  if (nameEl) nameEl.textContent = gpu.name || 'GPU';
  if (utilTxt) utilTxt.textContent = utilAvailable ? `${Math.round(util)}%` : 'n/d';
  if (vramText) vramText.textContent = `${formatGb(usedMb)} / ${formatGb(totalMb)} GB`;
  setBar(barUtil, utilAvailable ? util : 0, 85);
  setBar(barVram, vramPct, 90);

  const stackRam = Number(st.ram_mb) || 0;
  const stackCpu = st.cpu_pct != null ? Number(st.cpu_pct) : null;
  if (stackLine) {
    const cpu = stackCpu != null ? `${stackCpu.toFixed(1)}% CPU` : 'CPU --';
    stackLine.textContent = `RAM stack ${formatMb(stackRam)} · ${cpu}`;
  }

  if (breakdown) {
    const ace = st.ace || {};
    const comfy = st.comfy || {};
    const parts = [];
    if (ace.running) parts.push(`ACE ${formatMb(ace.ram_mb)}`);
    else parts.push('ACE off');
    if (comfy.running) parts.push(`Comfy ${formatMb(comfy.ram_mb)}`);
    else parts.push('Comfy off');
    if (!st.vram_available && (ace.running || comfy.running)) {
      parts.push('VRAM/proces n/d — patrz pasek VRAM');
    }
    breakdown.textContent = parts.join(' · ');
  }

  if (hint) {
    const idle = hub?.gpu_idle_auto
      ? `auto idle ${hub.gpu_idle_minutes || '?'} min`
      : 'soft free ~60 s po runie Comfy';
    hint.textContent = `${st.process_count || 0} proc. · ${idle} · co 5 s`;
  }
}

function updateSvcChipButtons(s) {
  const map = [
    { id: 'ace', svc: s.ace },
    { id: 'comfy', svc: s.comfy },
  ];
  map.forEach(({ id, svc }) => {
    const chip = $(`#chip-${id}`);
    if (!chip) return;
    const st = svc?.state || (svc?.online ? 'online' : 'offline');
    const on = st === 'online' || st === 'starting' || st === 'hung';
    const startBtn = chip.querySelector('.chip-btn-start');
    const stopBtn = chip.querySelector('.chip-btn-stop');
    const link = chip.querySelector('.chip-link');
    if (startBtn) startBtn.disabled = on;
    if (stopBtn) stopBtn.disabled = !on;
    if (link) link.style.pointerEvents = on ? '' : 'none';
    if (link) link.style.opacity = on ? '1' : '0.45';
  });
}

function setChip(id, state, url) {
  const el = $(`#chip-${id}`);
  if (!el) return;
  const st = state === true ? 'online' : state === false ? 'offline' : state || 'offline';
  const prev = el.classList.contains('online')
    ? 'online'
    : el.classList.contains('starting')
      ? 'starting'
      : el.classList.contains('hung')
        ? 'hung'
        : 'offline';
  el.classList.remove('online', 'offline', 'starting', 'hung');
  el.classList.add(st);
  if (prev !== st) {
    el.classList.remove('chip-pop');
    void el.offsetWidth;
    el.classList.add('chip-pop');
  }
  const label = el.querySelector('.chip-label');
  if (label) {
    label.textContent =
      st === 'online' ? 'online'
        : st === 'starting' ? 'laduje...'
        : st === 'hung' ? 'zawieszony'
        : 'offline';
  }
  const link = el.querySelector('a.chip-link');
  if (link && url) {
    link.href = url;
    link.style.display = st === 'online' || st === 'hung' ? '' : 'none';
  }
}

async function refreshStatus() {
  try {
    const s = await fetchStatus();
    setChip('ace', s.ace.state || (s.ace.online ? 'online' : 'offline'), s.ace.url);
    setChip('comfy', s.comfy.state || (s.comfy.online ? 'online' : 'offline'), s.comfy.url);
    setChip('hub', s.hub.online ? 'online' : 'offline', s.hub.url);
    updateSvcChipButtons(s);
    updateGpuMeter(s.gpu, s.hub);
    renderComfyPreviews(s.comfy_outputs);
    const hubVer = s.hub?.api_version;
    const hubStale = hubVer == null || hubVer < HUB_API_VERSION;
    if (s.hub && !s.hub.upload) {
      toast('Stary dashboard hub — Restart stack (brak API upload)', true);
    } else if (hubStale) {
      toast(
        `Stary hub (API v${hubVer ?? '?'}). Uruchom Open-Dashboard.bat lub Restart stack — brak Zwolnij GPU / wykrywania zawieszenia.`,
        true
      );
    }
    const banner = $('#status-banner');
    if (banner) {
      const aceSt = s.ace.state || (s.ace.online ? 'online' : 'offline');
      const comfySt = s.comfy.state || (s.comfy.online ? 'online' : 'offline');
      const all = aceSt === 'online' && comfySt === 'online';
      const nextClass = 'status-banner ' + (all ? 'all-up' : comfySt === 'hung' ? 'warn' : 'partial');
      let nextText = 'Uruchom Start stack (Install.bat nie startuje serwerow).';
      if (comfySt === 'hung') {
        nextText =
          'ComfyUI nie odpowiada (moze byc zajety po runie) — poczekaj lub Zwolnij VRAM / Restart Comfy.';
      } else if (all) {
        nextText = 'Stack gotowy — ComfyUI i ACE-Step dzialaja.';
      } else if (aceSt === 'starting' || comfySt === 'starting') {
        nextText = 'Serwisy startuja (ACE pierwszy raz: 5-15 min). Status odswieza sie co 5 s.';
      } else if (!aceSt.includes('online') && !comfySt.includes('online') && s.hub?.online) {
        nextText = 'Install.bat tylko instaluje — kliknij Start stack (nie sam Open-Dashboard).';
      } else if (comfySt === 'online') {
        nextText = 'ComfyUI dziala. ACE-Step: uruchom Start stack lub czekaj na model.';
      } else if (aceSt === 'online') {
        nextText = 'ACE-Step dziala. Uruchom Start stack dla ComfyUI.';
      }
      withViewTransition(() => {
        banner.className = nextClass;
        banner.textContent = nextText;
      });
    }
  } catch (e) {
    console.warn(e);
    const banner = $('#status-banner');
    if (banner) {
      banner.className = 'status-banner warn';
      banner.textContent =
        'Brak polaczenia z hubem :7880. Uruchom Open-Dashboard.bat (nie plik HTML z dysku).';
    }
    setChip('hub', 'offline');
  }
}

async function runAction(name, btn) {
  if (btn) {
    btn.classList.add('busy');
    btn.disabled = true;
  }
  try {
    const r = await fetch(`${API}/api/action?name=${encodeURIComponent(name)}`);
    const j = await r.json();
    if (!j.ok) throw new Error(j.error || 'Blad');
    toast(j.message || 'OK');
    if (
      /^(start|stop)_(stack|ace|comfy)$/.test(name) ||
      name === 'restart_stack' ||
      name === 'force_free_gpu' ||
      name === 'restart_comfy' ||
      name === 'soft_free_vram'
    ) {
      setTimeout(refreshStatus, 2000);
      setTimeout(refreshStatus, 8000);
      setTimeout(refreshStatus, 20000);
      setTimeout(refreshStatus, 45000);
    }
  } catch (e) {
    toast(e.message, true);
  } finally {
    if (btn) {
      btn.classList.remove('busy');
      btn.disabled = false;
    }
  }
}

async function uploadFile(kind, file) {
  const url = `${API}/api/upload?kind=${encodeURIComponent(kind)}&name=${encodeURIComponent(file.name)}`;
  let r;
  try {
    r = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/octet-stream',
        'X-File-Name': encodeURIComponent(file.name),
      },
      body: file,
    });
  } catch (e) {
    throw new Error(
      `Brak polaczenia z hubem (${e.message}). Otworz http://127.0.0.1:7880/ — nie plik HTML z dysku.`
    );
  }
  const raw = await r.text();
  let j;
  try {
    j = JSON.parse(raw);
  } catch {
    throw new Error(`Upload HTTP ${r.status}: ${raw.slice(0, 120) || 'brak odpowiedzi'}`);
  }
  if (!j.ok) throw new Error(j.error || `Upload failed (HTTP ${r.status})`);
  return j.path;
}

function getEnhanceMode(card) {
  const el = card?.querySelector('input[name="enhance-mode"]:checked');
  return el?.value || 'light';
}

async function runDropApi(body) {
  const r = await fetch(`${API}/api/run`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
  const raw = await r.text();
  let j;
  try {
    j = JSON.parse(raw);
  } catch {
    throw new Error(`Run HTTP ${r.status}: ${raw.slice(0, 120)}`);
  }
  if (!j.ok) throw new Error(j.error || `Run failed (HTTP ${r.status})`);
  toast(j.message || 'Uruchomiono - sprawdz okno PowerShell');
}

async function runDrop(kind, file, refFile, opts = {}) {
  toast(`Wgrywam: ${file.name}...`);
  const uploadKind = kind === 'match' ? 'match_target' : kind;
  const targetPath = await uploadFile(uploadKind, file);
  let refPath = '';
  if (kind === 'match' && refFile) {
    refPath = await uploadFile('match_reference', refFile);
  }
  const body = { kind, path: targetPath };
  if (refPath) body.ref = refPath;
  if (kind === 'enhance' && opts.mode) body.mode = opts.mode;
  await runDropApi(body);
}

function filterAudio(files) {
  return [...files].filter((f) => AUDIO_EXT.test(f.name));
}

function setupDropZones() {
  $$('.drop-card').forEach((card) => {
    const kind = card.dataset.drop;
    const zones = $$('.drop-zone', card);

    const onFiles = async (files, slot) => {
      const audio = filterAudio(files);
      if (!audio.length) {
        toast('Dozwolone: mp3, wav, flac, m4a, opus...', true);
        return;
      }
      card.classList.add('busy');
      try {
        if (kind === 'match') {
          if (audio.length >= 2) {
            await runDrop('match', audio[0], audio[1]);
          } else if (slot === 'reference') {
            const targetPath = card.dataset.targetPath;
            if (!targetPath) {
              toast('Najpierw upusc utwor (lewa strefa)', true);
              return;
            }
            const refPath = await uploadFile('match_reference', audio[0]);
            await runDropApi({ kind: 'match', path: targetPath, ref: refPath });
          } else {
            card.dataset.targetPath = await uploadFile('match_target', audio[0]);
            toast(`Target OK: ${audio[0].name} - opcjonalnie upusc referencje`);
            await runDropApi({ kind: 'match', path: card.dataset.targetPath });
          }
        } else if (kind === 'enhance') {
          await runDrop(kind, audio[0], null, { mode: getEnhanceMode(card) });
        } else {
          await runDrop(kind, audio[0]);
        }
      } catch (e) {
        toast(e.message, true);
      } finally {
        card.classList.remove('busy');
      }
    };

    zones.forEach((zone) => {
      const slot = zone.dataset.matchSlot;
      ['dragenter', 'dragover'].forEach((ev) => {
        zone.addEventListener(ev, (e) => {
          e.preventDefault();
          e.stopPropagation();
          zone.classList.add('dragover');
        });
      });
      zone.addEventListener('dragleave', () => zone.classList.remove('dragover'));
      zone.addEventListener('drop', (e) => {
        e.preventDefault();
        e.stopPropagation();
        zone.classList.remove('dragover');
        onFiles(e.dataTransfer.files, slot);
      });
    });

    card.addEventListener('drop', (e) => {
      if (e.target.closest('.drop-zone')) return;
      e.preventDefault();
      onFiles(e.dataTransfer.files);
    });
  });
}

function toast(msg, isErr = false) {
  const t = $('#toast');
  if (!t) return;
  t.textContent = msg;
  t.className = 'toast show' + (isErr ? ' err' : '');
  clearTimeout(toast._tid);
  toast._tid = setTimeout(() => t.classList.remove('show'), 4200);
}

function escapeHtml(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/"/g, '&quot;');
}

let galleryItems = [];
let galleryIndex = 0;
let galleryFolder = '';

function comfyImgUrl(rel) {
  if (!rel) return '';
  return `/api/comfy-output?rel=${encodeURIComponent(rel)}`;
}

function galleryApiUrl(folder, force) {
  const params = new URLSearchParams({ limit: '48' });
  if (folder) params.set('folder', folder);
  if (force) params.set('refresh', '1');
  return `/api/comfy-gallery?${params}`;
}

function kickGalleryImages() {
  const grid = $('#gallery-grid');
  if (!grid) return;
  grid.querySelectorAll('img[data-rel]').forEach((img) => {
    const rel = img.dataset.rel;
    if (!rel) return;
    const url = comfyImgUrl(rel);
    if (img.getAttribute('src') !== url) img.src = url;
    else if (!img.complete || img.naturalWidth === 0) {
      img.removeAttribute('src');
      img.src = url;
    }
  });
}

function formatGalleryDate(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  return d.toLocaleString('pl-PL', {
    day: '2-digit',
    month: '2-digit',
    year: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  });
}

function renderGalleryBrowse(data) {
  const nav = $('#gallery-browse');
  const foldersEl = $('#gallery-folders');
  if (!nav) return;

  const crumbs = data?.breadcrumbs?.length ? data.breadcrumbs : [{ name: 'output', rel: '' }];
  nav.innerHTML = crumbs
    .map((c, i) => {
      const isLast = i === crumbs.length - 1;
      const rel = c.rel ?? '';
      const sep = i > 0 ? '<span class="gallery-crumb-sep" aria-hidden="true">/</span>' : '';
      const cls = isLast ? 'gallery-crumb is-current' : 'gallery-crumb';
      const label = escapeHtml(c.name || 'output');
      return `${sep}<button type="button" class="${cls}" data-gallery-folder="${escapeHtml(rel)}" ${isLast ? 'aria-current="page"' : ''}>${label}</button>`;
    })
    .join('');

  nav.querySelectorAll('[data-gallery-folder]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const rel = btn.dataset.galleryFolder || '';
      if (rel === galleryFolder) return;
      loadGallery(rel, true);
    });
  });

  const folders = data?.folders || [];
  if (!foldersEl) return;
  if (!folders.length) {
    foldersEl.hidden = true;
    foldersEl.innerHTML = '';
    return;
  }
  foldersEl.hidden = false;
  foldersEl.innerHTML = folders
    .map((f) => {
      const count = f.count ? `${f.count} plikow` : 'pusty';
      return `<button type="button" class="gallery-folder" data-gallery-folder="${escapeHtml(f.rel)}">
        <span class="gallery-folder-name">${escapeHtml(f.name)}</span>
        <span class="gallery-folder-meta">${escapeHtml(count)}</span>
      </button>`;
    })
    .join('');
  foldersEl.querySelectorAll('[data-gallery-folder]').forEach((btn) => {
    btn.addEventListener('click', () => loadGallery(btn.dataset.galleryFolder || '', true));
  });
}

function renderGallery(data) {
  const grid = $('#gallery-grid');
  const meta = $('#gallery-meta');
  if (!grid) return;

  galleryFolder = data?.folder ?? '';
  galleryItems = data?.items || [];
  renderGalleryBrowse(data);

  const root = data?.rel_root ? data.rel_root : 'ComfyUI/output';
  const folderLabel = galleryFolder ? ` · ${galleryFolder}` : '';
  const folderCount = (data?.folders || []).length;
  if (meta) {
    if (galleryItems.length) {
      meta.textContent = `${galleryItems.length} obrazow${folderLabel} · ${root}`;
    } else if (folderCount) {
      meta.textContent = `${folderCount} podfolderow${folderLabel} · ${root}`;
    } else {
      meta.textContent = `Brak obrazow${folderLabel} — wygeneruj cos w ComfyUI lub wybierz folder`;
    }
  }

  if (!galleryItems.length) {
    const hint = folderCount
      ? 'Wybierz folder powyzej lub przejdz glebiej.'
      : 'Brak obrazow PNG/JPG w tym folderze.';
    grid.innerHTML = `<p class="gallery-empty">${hint}</p>`;
    return;
  }

  grid.innerHTML = galleryItems
    .map((it, i) => {
      const title = escapeHtml(`${it.name} · ${formatGalleryDate(it.mtime)}`);
      const delay = Math.min(i * 0.04, 0.48);
      const rel = escapeHtml(it.rel);
      const src = comfyImgUrl(it.rel);
      return `<button type="button" class="gallery-item is-entering" data-gallery-index="${i}" title="${title}" style="animation-delay:${delay}s">
        <img data-rel="${rel}" src="${src}" alt="" loading="eager" decoding="async" />
        <span class="gallery-item-cap">${escapeHtml(it.name)}</span>
      </button>`;
    })
    .join('');

  grid.querySelectorAll('.gallery-item').forEach((btn) => {
    btn.addEventListener('click', () => openGalleryLightbox(Number(btn.dataset.galleryIndex)));
  });
  requestAnimationFrame(() => kickGalleryImages());
}

async function loadGallery(folder = galleryFolder, force = false) {
  const grid = $('#gallery-grid');
  if (!grid) return;
  if (typeof folder === 'boolean') {
    force = folder;
    folder = galleryFolder;
  }
  galleryFolder = folder || '';
  if (force) grid.classList.add('gallery-loading');
  try {
    const r = await fetch(galleryApiUrl(galleryFolder, force));
    if (!r.ok) throw new Error('gallery');
    const data = await r.json();
    if (data?.ok === false) throw new Error(data.error || 'gallery');
    renderGallery(data);
    if (force) toast('Galeria odswiezona');
  } catch {
    const meta = $('#gallery-meta');
    if (meta) meta.textContent = 'Galeria niedostepna — zrestartuj dashboard (Restart-Dashboard.bat)';
    grid.innerHTML = '<p class="gallery-empty">Nie udalo sie wczytac galerii.</p>';
    $('#gallery-folders')?.setAttribute('hidden', '');
  } finally {
    grid.classList.remove('gallery-loading');
  }
}

function applyLightboxImage(it) {
  const img = $('#gallery-lb-img');
  const cap = $('#gallery-lb-cap');
  const link = $('#gallery-lb-open');
  const loading = $('#gallery-lb-loading');
  const url = comfyImgUrl(it.rel);
  if (cap) cap.textContent = `${it.name || ''} · ${it.rel || ''} · ${formatGalleryDate(it.mtime)}`;
  if (link) link.href = url;
  if (!img) return;

  const done = (ok = true) => {
    img.classList.remove('is-loading');
    if (loading) loading.hidden = true;
    if (!ok) toast('Nie udalo sie zaladowac pelnego obrazu', true);
  };

  img.alt = it.name || '';
  img.classList.add('is-loading');
  if (loading) loading.hidden = false;

  img.onload = () => done(true);
  img.onerror = () => done(false);

  const absolute = new URL(url, window.location.origin).href;
  if (img.src !== absolute) img.src = url;

  if (img.complete) {
    if (img.naturalWidth > 0) done(true);
    else done(false);
  }
}

function openGalleryLightbox(index) {
  const box = $('#gallery-lightbox');
  if (!box || !galleryItems.length) return;
  galleryIndex = ((index % galleryItems.length) + galleryItems.length) % galleryItems.length;
  const it = galleryItems[galleryIndex];
  const show = () => applyLightboxImage(it);
  if (box.classList.contains('is-open')) {
    show();
    return;
  }
  openOverlay(box, 'gallery-lightbox-active', () => {
    requestAnimationFrame(() => requestAnimationFrame(show));
  });
}

function closeGalleryLightbox() {
  const box = $('#gallery-lightbox');
  if (!box) return;
  closeOverlay(box, 'gallery-lightbox-active', () => {
    const img = $('#gallery-lb-img');
    const loading = $('#gallery-lb-loading');
    if (img) {
      img.removeAttribute('src');
      img.classList.remove('is-loading');
      img.onload = null;
      img.onerror = null;
    }
    if (loading) loading.hidden = true;
  });
}

function stepGalleryLightbox(delta) {
  if (!galleryItems.length) return;
  openGalleryLightbox(galleryIndex + delta);
}

function openGalleryModal() {
  const modal = $('#gallery-modal');
  if (!modal) return;
  openOverlay(modal, 'gallery-modal-open', () => {
    loadGallery(galleryFolder, false).then(() => {
      requestAnimationFrame(() => {
        requestAnimationFrame(() => kickGalleryImages());
      });
    });
  });
}

function closeGalleryModal() {
  const modal = $('#gallery-modal');
  if (!modal) return;
  closeGalleryLightbox();
  closeOverlay(modal, 'gallery-modal-open');
}

function initGallery() {
  document.querySelectorAll('[data-open-gallery]').forEach((btn) => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      e.stopPropagation();
      openGalleryModal();
    });
  });
  document.querySelectorAll('[data-close-gallery]').forEach((el) => {
    el.addEventListener('click', closeGalleryModal);
  });
  $('#gallery-modal-close')?.addEventListener('click', closeGalleryModal);
  $('#gallery-refresh')?.addEventListener('click', () => loadGallery(galleryFolder, true));
  $('#gallery-lb-close')?.addEventListener('click', closeGalleryLightbox);
  $('#gallery-lb-prev')?.addEventListener('click', () => stepGalleryLightbox(-1));
  $('#gallery-lb-next')?.addEventListener('click', () => stepGalleryLightbox(1));
  $('#gallery-lightbox')?.addEventListener('click', (e) => {
    if (e.target.id === 'gallery-lightbox') closeGalleryLightbox();
  });
  document.addEventListener('keydown', (e) => {
    const lb = $('#gallery-lightbox');
    if (lb?.classList.contains('is-open')) {
      if (e.key === 'Escape') closeGalleryLightbox();
      if (e.key === 'ArrowLeft') stepGalleryLightbox(-1);
      if (e.key === 'ArrowRight') stepGalleryLightbox(1);
      return;
    }
    const modal = $('#gallery-modal');
    if (modal?.classList.contains('is-open') && e.key === 'Escape') closeGalleryModal();
  });
}

function initMotion() {
  requestAnimationFrame(() => {
    document.body.classList.add('is-loaded');
  });
}

function renderComfyPreviews(data) {
  const visual = $('#comfy-out-visual');
  const bg = $('#comfy-out-bg');
  const thumbs = $('#comfy-out-thumbs');
  if (!visual || !bg) return;

  const items = data?.items || [];
  if (!items.length) {
    visual.classList.add('comfy-out-visual--empty');
    bg.style.backgroundImage = '';
    if (thumbs) thumbs.innerHTML = '';
    return;
  }

  visual.classList.remove('comfy-out-visual--empty');
  const latest = items[0];
  const bgUrl = comfyImgUrl(latest.rel);
  const probe = new Image();
  probe.onload = () => {
    bg.style.backgroundImage = `url(${bgUrl})`;
  };
  probe.onerror = () => {
    visual.classList.add('comfy-out-visual--empty');
    bg.style.backgroundImage = '';
  };
  probe.src = bgUrl;

  if (thumbs) {
    thumbs.innerHTML = items
      .slice(0, 4)
      .map((it) => {
        const rel = encodeURIComponent(it.rel);
        const title = escapeHtml(`${it.name} · ${it.rel}`);
        return `<a class="comfy-out-thumb" href="${comfyImgUrl(it.rel)}" target="_blank" rel="noopener" title="${title}" onclick="event.stopPropagation()"><img src="${comfyImgUrl(it.rel)}" alt="" loading="lazy" decoding="async" /></a>`;
      })
      .join('');
  }
}

document.addEventListener('click', (e) => {
  const btn = e.target.closest('[data-action]');
  if (!btn || btn.classList.contains('disabled')) return;
  e.preventDefault();
  const act = btn.dataset.action;
  const confirmMsg = btn.dataset.confirm;
  if (confirmMsg && !window.confirm(confirmMsg)) return;
  if (act === 'open_ace' || act === 'open_comfy') {
    window.open(act === 'open_ace' ? 'http://127.0.0.1:7870/' : 'http://127.0.0.1:7871/', '_blank');
    return;
  }
  runAction(act, btn);
});

if (location.protocol === 'file:') {
  toast('Otworz dashboard przez http://127.0.0.1:7880/ (upload nie dziala z pliku HTML)', true);
}

initMotion();
setupDropZones();
initGallery();
refreshStatus();
setInterval(refreshStatus, 5000);
