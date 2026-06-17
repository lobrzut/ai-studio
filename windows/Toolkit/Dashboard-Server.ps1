#Requires -Version 5.1
# Lokalny hub dashboardu - port 7880. Uruchamiany z Start.ps1 lub Open-Dashboard.bat.
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Port     = 7880
$Toolkit  = $PSScriptRoot
$Root     = Split-Path $Toolkit -Parent
$RepoRoot = Split-Path $Root -Parent
$WebRoot  = Join-Path $RepoRoot 'shared\web'
$LogDir   = Join-Path $Root 'logs'
# Podnies przy zmianach API / UI — klient ostrzeze gdy hub jest stary
$HubApiVersion = 8

. (Join-Path $Toolkit 'Get-GpuStats.ps1')
. (Join-Path $Toolkit 'Service-Control.ps1')
. (Join-Path $Toolkit 'Locale.ps1')

$script:GpuIdleAuto = $false
$script:GpuIdleIntervalSec = 180
$script:GpuIdleLastSoftFree = [datetime]::MinValue
$script:ComfyPingFailCount = 0
$script:ComfyQueueWasBusy = $false
$script:ComfyQueueIdleSince = $null
$script:ComfyAfterRunSoftFreeSec = 60
$script:StatusCache = $null
$script:StatusCacheAt = [datetime]::MinValue
$script:ComfyOutputsCache = $null
$script:ComfyOutputsCacheAt = [datetime]::MinValue
$script:ComfyGalleryCache = $null
$script:ComfyGalleryCacheAt = [datetime]::MinValue
$script:LastHubMaintenanceAt = [datetime]::MinValue
$script:HubMaintenanceIntervalSec = 20
$idleEnv = Join-Path $Toolkit 'gpu-idle.env'
if (Test-Path -LiteralPath $idleEnv) {
    Get-Content -LiteralPath $idleEnv | ForEach-Object {
        if ($_ -match '^\s*#' -or $_ -notmatch '=') { return }
        $k, $v = $_ -split '=', 2
        switch ($k.Trim()) {
            'GPU_IDLE_SOFT_FREE' { if ($v.Trim() -eq '1') { $script:GpuIdleAuto = $true } }
            'GPU_IDLE_MINUTES'   { $m = [int]$v.Trim(); if ($m -gt 0) { $script:GpuIdleIntervalSec = $m * 60 } }
        }
    }
}

$script:GpuStatsCache = @{
    available     = $false
    name          = 'GPU'
    util_pct      = $null
    vram_used_mb  = $null
    vram_total_mb = 16384
}
$script:GpuStatsUpdatedAt = [datetime]::MinValue
$script:GpuPollJob = $null
$script:GpuPollIntervalSec = 5

function Set-GpuStatsCache($stats) {
    $script:GpuStatsCache = $stats
    $script:GpuStatsUpdatedAt = Get-Date
}

function Get-GpuStatsCache {
    try {
        Ensure-GpuStatsFresh -WaitForResult:$false
        $h = @{}
        $script:GpuStatsCache.GetEnumerator() | ForEach-Object { $h[$_.Key] = $_.Value }
        return $h
    } catch {
        return @{
            available = $false
            name      = 'GPU'
            error     = $_.Exception.Message
        }
    }
}

function Ensure-GpuStatsFresh([switch]$WaitForResult) {
    if ($script:GpuPollJob) {
        if ($script:GpuPollJob.State -eq 'Completed') {
            try {
                $stats = Receive-Job -Job $script:GpuPollJob -ErrorAction Stop
                if ($stats) { Set-GpuStatsCache $stats }
            } catch {
                $script:GpuStatsCache.error = $_.Exception.Message
            } finally {
                Remove-Job -Job $script:GpuPollJob -Force -ErrorAction SilentlyContinue
                $script:GpuPollJob = $null
            }
        } elseif ($script:GpuPollJob.State -in @('Failed', 'Stopped')) {
            Remove-Job -Job $script:GpuPollJob -Force -ErrorAction SilentlyContinue
            $script:GpuPollJob = $null
        } elseif ($WaitForResult -and $script:GpuPollJob.State -eq 'Running') {
            $null = Wait-Job -Job $script:GpuPollJob -Timeout 15
            Ensure-GpuStatsFresh -WaitForResult:$false
            return
        }
    }

    $age = ((Get-Date) - $script:GpuStatsUpdatedAt).TotalSeconds
    if ($script:GpuPollJob -or ($age -lt $script:GpuPollIntervalSec -and $script:GpuStatsUpdatedAt -ne [datetime]::MinValue)) {
        return
    }

    $gpuScript = Join-Path $Toolkit 'Get-GpuStats.ps1'
    $script:GpuPollJob = Start-Job -ArgumentList $Root, $gpuScript -ScriptBlock {
        param($rootPath, $gpuScriptPath)
        . $gpuScriptPath
        Measure-GpuStats $rootPath
    }
}

function Test-PortUp([int]$p) {
    return [bool](Get-NetTCPConnection -LocalPort $p -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1)
}

function Test-StackProcessStarting([string]$cmdPattern) {
    if (-not $cmdPattern) { return $false }
    $esc = [regex]::Escape($Root)
    Get-CimInstance Win32_Process -Filter "Name = 'python.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -and $_.CommandLine -match $esc -and $_.CommandLine -match $cmdPattern } |
        Select-Object -First 1 |
        ForEach-Object { return $true }
    return $false
}

function Get-ServiceState([int]$port, [string]$cmdPattern) {
    if (Test-PortUp $port) { return 'online' }
    if (Test-StackProcessStarting $cmdPattern) { return 'starting' }
    'offline'
}

function Test-ComfyApiPing([int]$TimeoutSec = 2) {
    try {
        $null = Invoke-WebRequest -Uri 'http://127.0.0.1:7871/queue' -UseBasicParsing -TimeoutSec $TimeoutSec
        return $true
    } catch {
        return $false
    }
}

function Get-ComfyQueueCounts($q) {
    if (-not $q) { return 0, 0 }
    $run = @($q.queue_running).Count
    $pend = @($q.queue_pending).Count
    return $run, $pend
}

function Invoke-ComfySoftFreeVram([int]$Port = 7871, [switch]$Force) {
    $base = "http://127.0.0.1:$Port"
    try {
        $q = Invoke-RestMethod -Uri "$base/queue" -TimeoutSec 3
        $run, $pend = Get-ComfyQueueCounts $q
        if (($run -gt 0 -or $pend -gt 0) -and -not $Force) {
            return @{ ok = $false; skipped = $true; reason = "queue busy run=$run pending=$pend" }
        }
        if ($Force -and ($run -gt 0 -or $pend -gt 0)) {
            Invoke-RestMethod -Method POST -Uri "$base/interrupt" -Body '{}' -ContentType 'application/json' -TimeoutSec 3 | Out-Null
            Invoke-RestMethod -Method POST -Uri "$base/queue" -Body '{"clear":true}' -ContentType 'application/json' -TimeoutSec 3 | Out-Null
        }
        Invoke-RestMethod -Method POST -Uri "$base/free" -Body '{"unload_models":true,"free_memory":true}' -ContentType 'application/json' -TimeoutSec 6 | Out-Null
        return @{ ok = $true }
    } catch {
        return @{ ok = $false; error = $_.Exception.Message }
    }
}

function Maybe-AutoSoftFreeVram {
    if (-not $script:GpuIdleAuto) { return }
    if (-not (Test-PortUp 7871)) { return }
    $age = ((Get-Date) - $script:GpuIdleLastSoftFree).TotalSeconds
    if ($age -lt $script:GpuIdleIntervalSec) { return }
    $r = Invoke-ComfySoftFreeVram
    if ($r.ok) {
        $script:GpuIdleLastSoftFree = Get-Date
        Write-Host "[gpu-idle] Comfy soft free VRAM (timer)" -ForegroundColor DarkGray
    }
}

function Maybe-SoftFreeAfterComfyRun {
    if (-not (Test-PortUp 7871)) {
        $script:ComfyQueueWasBusy = $false
        $script:ComfyQueueIdleSince = $null
        return
    }
    try {
        $q = Invoke-RestMethod -Uri 'http://127.0.0.1:7871/queue' -TimeoutSec 5
        $run, $pend = Get-ComfyQueueCounts $q
        $busy = ($run -gt 0 -or $pend -gt 0)
        if ($busy) {
            $script:ComfyQueueWasBusy = $true
            $script:ComfyQueueIdleSince = $null
            return
        }
        if (-not $script:ComfyQueueWasBusy) { return }
        if (-not $script:ComfyQueueIdleSince) {
            $script:ComfyQueueIdleSince = Get-Date
            return
        }
        $idleSec = ((Get-Date) - $script:ComfyQueueIdleSince).TotalSeconds
        if ($idleSec -lt $script:ComfyAfterRunSoftFreeSec) { return }
        $age = ((Get-Date) - $script:GpuIdleLastSoftFree).TotalSeconds
        if ($age -lt 30) { return }
        $r = Invoke-ComfySoftFreeVram
        if ($r.ok) {
            $script:ComfyQueueWasBusy = $false
            $script:ComfyQueueIdleSince = $null
            $script:GpuIdleLastSoftFree = Get-Date
            Write-Host "[comfy-idle] soft free VRAM po runie (${idleSec}s bez kolejki)" -ForegroundColor DarkGray
        }
    } catch { }
}

function Update-ComfyHealth {
    if (-not (Test-PortUp 7871)) {
        $script:ComfyPingFailCount = 0
        return
    }
    if (Test-ComfyApiPing -TimeoutSec 2) {
        $script:ComfyPingFailCount = 0
    } else {
        $script:ComfyPingFailCount++
    }
}

function Run-HubMaintenanceIfDue {
    $age = ((Get-Date) - $script:LastHubMaintenanceAt).TotalSeconds
    if ($age -lt $script:HubMaintenanceIntervalSec) { return }
    $script:LastHubMaintenanceAt = Get-Date
    Update-ComfyHealth
    Maybe-SoftFreeAfterComfyRun
    Maybe-AutoSoftFreeVram
    $script:StatusCache = $null
}

function Get-ServiceStatus {
    try {
    $cachedAge = ((Get-Date) - $script:StatusCacheAt).TotalSeconds
    if ($script:StatusCache -and $cachedAge -lt 3) {
        return $script:StatusCache
    }

    $aceState = Get-ServiceState 7870 'acestep_v15_pipeline'
    $comfyState = Get-ServiceState 7871 'main\.py'
    if ($comfyState -eq 'online' -and $script:ComfyPingFailCount -ge 4) {
        $comfyState = 'hung'
    }
    $status = @{
        ace   = @{
            online = ($aceState -eq 'online')
            state  = $aceState
            port   = 7870
            url    = 'http://127.0.0.1:7870/'
        }
        comfy = @{
            online = ($comfyState -in 'online', 'hung')
            state  = $comfyState
            port   = 7871
            url    = 'http://127.0.0.1:7871/'
            hung   = ($comfyState -eq 'hung')
        }
        hub   = @{
            online      = $true
            port        = $Port
            url         = "http://127.0.0.1:$Port/"
            api_version = $HubApiVersion
            upload      = $true
            locale      = (Get-StudioLocale)
            edition     = 'windows'
            features    = @('force_free_gpu', 'soft_free_vram', 'comfy_hung', 'gpu_meter', 'gpu_idle_auto', 'service_toggle', 'comfy_outputs', 'i18n')
            gpu_idle_auto = $script:GpuIdleAuto
            gpu_idle_minutes = [math]::Round($script:GpuIdleIntervalSec / 60, 1)
        }
        gpu = Get-GpuStatsCache
        comfy_outputs = Get-ComfyOutputsCache
    }
    $script:StatusCache = $status
    $script:StatusCacheAt = Get-Date
    return $status
    } catch {
        Write-Host "[hub] status error: $($_.Exception.Message)" -ForegroundColor Yellow
        return @{
            ace   = @{ online = $false; state = 'offline'; port = 7870; url = 'http://127.0.0.1:7870/' }
            comfy = @{ online = $false; state = 'offline'; port = 7871; url = 'http://127.0.0.1:7871/'; hung = $false }
            hub   = @{
                online = $true; port = $Port; url = "http://127.0.0.1:$Port/"
                api_version = $HubApiVersion; upload = $true
                locale = (Get-StudioLocale)
                edition = 'windows'
                gpu_idle_auto = $script:GpuIdleAuto
                gpu_idle_minutes = [math]::Round($script:GpuIdleIntervalSec / 60, 1)
            }
            gpu = @{ available = $false; name = 'GPU'; error = $_.Exception.Message }
        }
    }
}

function Add-CorsHeaders($ctx) {
    $origin = $ctx.Request.Headers['Origin']
    if ($origin) {
        $ctx.Response.AddHeader('Access-Control-Allow-Origin', $origin)
    } else {
        $ctx.Response.AddHeader('Access-Control-Allow-Origin', '*')
    }
    $ctx.Response.AddHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
    $ctx.Response.AddHeader('Access-Control-Allow-Headers', 'Content-Type, X-File-Name')
    $ctx.Response.AddHeader('Access-Control-Max-Age', '86400')
}

function Send-Json($ctx, $obj, [int]$code = 200) {
    Add-CorsHeaders $ctx
    $json = $obj | ConvertTo-Json -Compress -Depth 6
    $buf  = [Text.Encoding]::UTF8.GetBytes($json)
    $ctx.Response.StatusCode = $code
    $ctx.Response.ContentType = 'application/json; charset=utf-8'
    $ctx.Response.ContentLength64 = $buf.Length
    $ctx.Response.OutputStream.Write($buf, 0, $buf.Length)
    $ctx.Response.Close()
}

function Send-Text($ctx, [string]$text, [string]$ctype = 'text/plain', [int]$code = 200) {
    $buf = [Text.Encoding]::UTF8.GetBytes($text)
    $ctx.Response.StatusCode = $code
    $ctx.Response.ContentType = "$ctype; charset=utf-8"
    $ctx.Response.ContentLength64 = $buf.Length
    $ctx.Response.OutputStream.Write($buf, 0, $buf.Length)
    $ctx.Response.Close()
}

function Send-File($ctx, [string]$path, [string]$ctype) {
    if (-not (Test-Path -LiteralPath $path)) {
        Send-Text $ctx 'Not found' 'text/plain' 404
        return
    }
    $bytes = [IO.File]::ReadAllBytes($path)
    $ctx.Response.StatusCode = 200
    $ctx.Response.ContentType = "$ctype; charset=utf-8"
    $ctx.Response.AddHeader('Cache-Control', 'no-cache, no-store, must-revalidate')
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.Close()
}

function Send-BinaryFile($ctx, [string]$path, [string]$ctype, [string]$cache = 'public, max-age=120') {
    Add-CorsHeaders $ctx
    if (-not (Test-Path -LiteralPath $path)) {
        Send-Text $ctx 'Not found' 'text/plain' 404
        return
    }
    $bytes = [IO.File]::ReadAllBytes($path)
    $ctx.Response.StatusCode = 200
    $ctx.Response.ContentType = $ctype
    if ($cache) { $ctx.Response.AddHeader('Cache-Control', $cache) }
    $ctx.Response.ContentLength64 = $bytes.Length
    $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
    $ctx.Response.Close()
}

function Launch-Bat([string]$relFromRoot) {
    $full = Join-Path $Root $relFromRoot
    if (-not (Test-Path -LiteralPath $full)) { throw "Brak: $full" }
    Start-Process -FilePath 'cmd.exe' -ArgumentList @('/c', 'start', '""', '/D', (Split-Path $full -Parent), $full) -WorkingDirectory $Root
}

function Launch-Explorer([string]$relFromRoot) {
    $full = Join-Path $Root $relFromRoot
    if (-not (Test-Path -LiteralPath $full)) { New-Item -ItemType Directory -Force -Path $full | Out-Null }
    Start-Process -FilePath 'explorer.exe' -ArgumentList $full
}

function Get-AceOutputsDir {
    $dir = Join-Path $Root 'ACE-Step\ACE-Step-1.5\gradio_outputs'
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }
    return (Resolve-Path -LiteralPath $dir).Path
}

function Open-AceOutputs {
    $dir = Get-AceOutputsDir
    Start-Process -FilePath 'explorer.exe' -ArgumentList $dir
    return $dir
}

$script:ComfyImageExt = @('.png', '.jpg', '.jpeg', '.webp', '.gif', '.bmp')

function Get-ComfyOutputsDir {
    foreach ($rel in @('ComfyUI\ComfyUI\output', 'ComfyUI\output')) {
        $dir = Join-Path $Root $rel
        if (Test-Path -LiteralPath $dir) {
            return @{
                path = (Resolve-Path -LiteralPath $dir).Path
                rel  = $rel
            }
        }
    }
    $rel = 'ComfyUI\ComfyUI\output'
    $dir = Join-Path $Root $rel
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    return @{
        path = (Resolve-Path -LiteralPath $dir).Path
        rel  = $rel
    }
}

function Test-ComfyOutputRelSafe([string]$rel) {
    if ([string]::IsNullOrWhiteSpace($rel)) { return $false }
    $norm = $rel.Replace('\', '/').TrimStart('/')
    if ($norm -match '(^|/)\.\.(/|$)') { return $false }
    if ($norm -match '[:*?"<>|]') { return $false }
    return $true
}

function Resolve-ComfyOutputFile([string]$rel) {
    if (-not (Test-ComfyOutputRelSafe $rel)) { return $null }
    $info = Get-ComfyOutputsDir
    $root = $info.path
    $full = [IO.Path]::GetFullPath((Join-Path $root ($rel.Replace('/', [IO.Path]::DirectorySeparatorChar))))
    $rootFull = [IO.Path]::GetFullPath($root)
    if (-not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return $null }
    $ext = [IO.Path]::GetExtension($full).ToLower()
    if ($script:ComfyImageExt -notcontains $ext) { return $null }
    return $full
}

function Get-ComfyOutputsCache([int]$limit = 6) {
    $age = ((Get-Date) - $script:ComfyOutputsCacheAt).TotalSeconds
    if (-not $script:ComfyOutputsCache -or $age -gt 15) {
        $script:ComfyOutputsCache = Get-ComfyOutputRecent -limit $limit
        $script:ComfyOutputsCacheAt = Get-Date
    }
    return $script:ComfyOutputsCache
}

function Normalize-ComfyFolder([string]$folder) {
    if ([string]::IsNullOrWhiteSpace($folder)) { return '' }
    $norm = $folder.Replace('\', '/').Trim().TrimStart('/').TrimEnd('/')
    if (-not (Test-ComfyOutputRelSafe $norm)) { return $null }
    return $norm
}

function Resolve-ComfyFolderPath([string]$folder) {
    $norm = Normalize-ComfyFolder $folder
    if ($null -eq $norm) { return $null }
    $info = Get-ComfyOutputsDir
    $root = $info.path
    if (-not $norm) {
        return @{ root = $root; path = $root; rel = ''; info = $info }
    }
    $full = [IO.Path]::GetFullPath((Join-Path $root ($norm.Replace('/', [IO.Path]::DirectorySeparatorChar))))
    $rootFull = [IO.Path]::GetFullPath($root)
    if (-not $full.StartsWith($rootFull, [StringComparison]::OrdinalIgnoreCase)) { return $null }
    if (-not (Test-Path -LiteralPath $full -PathType Container)) { return $null }
    return @{ root = $root; path = $full; rel = $norm; info = $info }
}

function Get-ComfyBreadcrumbs([string]$folder) {
    $crumbs = @(@{ name = 'output'; rel = '' })
    if ([string]::IsNullOrWhiteSpace($folder)) { return $crumbs }
    $acc = ''
    foreach ($p in $folder.Split('/')) {
        if ([string]::IsNullOrWhiteSpace($p)) { continue }
        $acc = if ($acc) { "$acc/$p" } else { $p }
        $crumbs += @{ name = $p; rel = $acc }
    }
    return $crumbs
}

function Get-ComfyGalleryData([string]$folder = '', [int]$limit = 48) {
    $resolved = Resolve-ComfyFolderPath $folder
    if (-not $resolved) {
        return @{
            ok          = $false
            error       = 'Nieprawidlowy folder'
            folder      = $folder
            folders     = @()
            items       = @()
            breadcrumbs = @(@{ name = 'output'; rel = '' })
        }
    }
    $base = $resolved.path
    $root = $resolved.root
    $norm = $resolved.rel
    $info = $resolved.info

    $folders = @(
        Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object {
                $relDir = if ($norm) { "$norm/$($_.Name)" } else { $_.Name }
                $relDir = $relDir.Replace('\', '/')
                $imgCount = @(
                    Get-ChildItem -LiteralPath $_.FullName -Recurse -File -ErrorAction SilentlyContinue |
                        Where-Object { $script:ComfyImageExt -contains $_.Extension.ToLower() }
                ).Count
                @{
                    rel   = $relDir
                    name  = $_.Name
                    count = [int]$imgCount
                }
            }
    )

    $files = @(
        Get-ChildItem -LiteralPath $base -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $script:ComfyImageExt -contains $_.Extension.ToLower() } |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First $limit
    )
    $items = foreach ($f in $files) {
        @{
            rel   = $f.FullName.Substring($root.Length).TrimStart('\', '/').Replace('\', '/')
            name  = $f.Name
            mtime = $f.LastWriteTime.ToString('o')
            size  = [int64]$f.Length
        }
    }
    return @{
        ok          = $true
        root        = $root
        rel_root    = $info.rel
        folder      = $norm
        breadcrumbs = @(Get-ComfyBreadcrumbs $norm)
        folders     = @($folders)
        items       = @($items)
        limit       = $limit
    }
}

function Get-ComfyGalleryCache([string]$folder = '', [int]$limit = 48, [switch]$Refresh) {
    $folderNorm = Normalize-ComfyFolder $folder
    if ($null -eq $folderNorm) { $folderNorm = '' }
    if ($Refresh) {
        $script:ComfyGalleryCache = $null
        $script:ComfyGalleryCacheAt = [datetime]::MinValue
    }
    $age = ((Get-Date) - $script:ComfyGalleryCacheAt).TotalSeconds
    $stale = (-not $script:ComfyGalleryCache) -or ($age -gt 20) -or $Refresh `
        -or ($script:ComfyGalleryCacheFolder -ne $folderNorm) -or ($script:ComfyGalleryCacheLimit -ne $limit)
    if ($stale) {
        $script:ComfyGalleryCache = Get-ComfyGalleryData $folderNorm $limit
        $script:ComfyGalleryCacheAt = Get-Date
        $script:ComfyGalleryCacheFolder = $folderNorm
        $script:ComfyGalleryCacheLimit = $limit
    }
    return $script:ComfyGalleryCache
}

function Get-ComfyOutputRecent([int]$limit = 6) {
    $data = Get-ComfyGalleryData '' $limit
    return @{
        root     = $data.root
        rel_root = $data.rel_root
        items    = $data.items
        limit    = $limit
        folder   = ''
    }
}

function Open-ComfyOutputs {
    $info = Get-ComfyOutputsDir
    Start-Process -FilePath 'explorer.exe' -ArgumentList $info.path
    return $info.path
}

$script:AllowedAudio = @('.mp3','.wav','.flac','.m4a','.opus','.ogg','.aac','.wma')

function Ensure-SubDir([string]$parent, [string]$name) {
    $path = Join-Path $parent $name
    if (Test-Path -LiteralPath $path) {
        $item = Get-Item -LiteralPath $path
        if (-not $item.PSIsContainer) {
            $bak = "$path.file.bak"
            if (Test-Path -LiteralPath $bak) { Remove-Item -LiteralPath $bak -Force }
            Rename-Item -LiteralPath $path -NewName (Split-Path -Leaf $bak) -Force
        }
    }
    [void][System.IO.Directory]::CreateDirectory($path)
    return $path
}

function Get-InboxDir {
    $d = Join-Path $Toolkit 'inbox'
    [void][System.IO.Directory]::CreateDirectory($d)
    Ensure-SubDir $d 'jobs' | Out-Null
    return $d
}

function Get-JobsDir {
    Ensure-SubDir (Get-InboxDir) 'jobs'
}

function Test-AudioExtension([string]$name) {
    $ext = [IO.Path]::GetExtension($name).ToLower()
    return $script:AllowedAudio -contains $ext
}

function Get-UploadFileName($req) {
    $name = $req.QueryString['name']
    if ($name) {
        try { $name = [Uri]::UnescapeDataString($name) } catch { }
    }
    if (-not $name) {
        $hdr = $req.Headers['X-File-Name']
        if ($hdr) {
            try { $name = [Uri]::UnescapeDataString($hdr) } catch { $name = $hdr }
        }
    }
    return [IO.Path]::GetFileName($name)
}

function Save-UploadStream($req, [string]$fileName) {
    $safe = Get-UploadFileName $req
    if (-not $safe) { $safe = [IO.Path]::GetFileName($fileName) }
    if (-not $safe -or -not (Test-AudioExtension $safe)) {
        throw "Nieobslugiwany format ($safe). Dozwolone: $($script:AllowedAudio -join ', ')"
    }
    $inbox = Get-InboxDir
    $dest = Join-Path $inbox (([Guid]::NewGuid().ToString('N')) + '_' + $safe)
    $in = $req.InputStream
    if (-not $in) { throw 'Brak strumienia POST (InputStream)' }
    $out = [IO.File]::Create($dest)
    try {
        $in.CopyTo($out)
        $out.Flush()
    } finally {
        $out.Close()
        $in.Close()
    }
    if (-not (Test-Path -LiteralPath $dest)) { throw "Nie zapisano pliku: $dest" }
    if ((Get-Item -LiteralPath $dest).Length -eq 0) { throw 'Plik pusty (0 bajtow) - sprobuj ponownie' }
    return [IO.Path]::GetFullPath($dest)
}

function Get-RunRequestPayload($req) {
    $kind     = $req.QueryString['kind']
    $filePath = $req.QueryString['path']
    $refPath  = $req.QueryString['ref']
    $mode     = $req.QueryString['mode']
    $ctype    = if ($req.ContentType) { $req.ContentType.Split(';')[0].Trim().ToLower() } else { '' }
    if ($ctype -eq 'application/json') {
        $reader = New-Object System.IO.StreamReader($req.InputStream, [Text.Encoding]::UTF8)
        try {
            $raw = $reader.ReadToEnd()
            if ($raw) {
                $o = $raw | ConvertFrom-Json
                if ($o.kind)  { $kind     = [string]$o.kind }
                if ($o.path)  { $filePath = [string]$o.path }
                if ($o.ref)   { $refPath  = [string]$o.ref }
                if ($o.mode)  { $mode     = [string]$o.mode }
            }
        } finally { $reader.Close() }
    }
    if ($filePath) {
        try { $filePath = [Uri]::UnescapeDataString($filePath) } catch { }
    }
    if ($refPath) {
        try { $refPath = [Uri]::UnescapeDataString($refPath) } catch { }
    }
    return @{ kind = $kind; path = $filePath; ref = $refPath; mode = $mode }
}

function Launch-DropJob([string]$kind, [string]$filePath, [string]$refPath, [string]$mode) {
    $launcher = Join-Path $Toolkit 'Invoke-Drop.ps1'
    if (-not (Test-Path -LiteralPath $launcher)) { throw "Brak $launcher" }
    $jobsDir = Get-JobsDir
    $jobFile = Join-Path $jobsDir (([Guid]::NewGuid().ToString('N')) + '.json')
    $job = @{
        kind = $kind
        path = $filePath
        root = $Root
    }
    if ($refPath) { $job.ref = $refPath }
    if ($mode)   { $job.mode = $mode }
    $job | ConvertTo-Json -Compress | Set-Content -LiteralPath $jobFile -Encoding UTF8
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit',
        '-File', $launcher,
        '-JobFile', $jobFile
    ) -WorkingDirectory $Root | Out-Null
}

function Invoke-DropProcess([string]$kind, [string]$filePath, [string]$refPath) {
    $mode = $script:EnhanceMode
    if ($kind -eq 'enhance') {
        if (-not $mode) { $mode = 'light' }
        if ($mode -notin 'light', 'medium', 'heavy') { $mode = 'light' }
    } else {
        $mode = ''
    }
    Launch-DropJob $kind $filePath $refPath $mode
    switch ($kind) {
        'master' { return (L 'drop_master' @((Split-Path $filePath -Leaf))) }
        'stems'  { return (L 'drop_stems' @((Split-Path $filePath -Leaf))) }
        'lyrics' { return (L 'drop_lyrics' @((Split-Path $filePath -Leaf))) }
        'match' {
            if ($refPath) { return (L 'drop_match_ref' @((Split-Path $filePath -Leaf), (Split-Path $refPath -Leaf))) }
            return (L 'drop_match_refs_folder' @((Split-Path $filePath -Leaf)))
        }
        'enhance' { return (L 'drop_enhance' @($mode, (Split-Path $filePath -Leaf))) }
        'silence' { return (L 'drop_silence' @((Split-Path $filePath -Leaf))) }
        default { throw (L 'err_unknown_drop' @($kind)) }
    }
}

function Invoke-Action([string]$name) {
    switch ($name) {
        'start_stack' {
            $parts = @(Ensure-DashboardHub)
            $parts += (Start-StudioServicesBoth)
            return ($parts -join ' ')
        }
        'stop_stack' {
            return (Stop-StudioServicesBoth)
        }
        'start_ace'   { return (Start-StudioService -Name Ace) }
        'stop_ace'    { return (Stop-StudioService -Name Ace) }
        'start_comfy' { return (Start-StudioService -Name Comfy) }
        'stop_comfy'  { return (Stop-StudioService -Name Comfy) }
        'start_hub'   { return (Ensure-DashboardHub) }
        'restart_stack' {
            $restart = Join-Path $Root 'Restart.ps1'
            if (-not (Test-Path -LiteralPath $restart)) { throw "Brak $restart" }
            Start-Process -FilePath 'powershell.exe' -ArgumentList @(
                '-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Minimized','-File',$restart
            ) -WorkingDirectory $Root
            return (L 'action_restart_stack')
        }
        'install'      { Launch-Bat 'Install.bat'; return (L 'action_install') }
        'open_ace'     { Start-Process 'http://127.0.0.1:7870/'; return 'ACE-Step' }
        'open_comfy'   { Start-Process 'http://127.0.0.1:7871/'; return 'ComfyUI' }
        'force_free_gpu' {
            $script = Join-Path $Toolkit 'Force-Free-GPU.ps1'
            $log    = Join-Path $LogDir 'force-gpu.last.log'
            if (-not (Test-Path -LiteralPath $script)) { throw "Brak $script" }
            New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
            $null = Start-Process -FilePath 'powershell.exe' -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command',
                "& { & '$script' -Quiet *>&1 | Tee-Object -FilePath '$log' }"
            ) -WorkingDirectory $Root -WindowStyle Normal -PassThru
            return (L 'action_force_gpu')
        }
        'restart_comfy' {
            $script = Join-Path $Toolkit 'Force-Free-GPU.ps1'
            Start-Process -FilePath 'powershell.exe' -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $script, '-RestartComfy', '-Quiet'
            ) -WorkingDirectory $Root -WindowStyle Normal
            return (L 'action_restart_comfy')
        }
        'soft_free_vram' {
            $r = Invoke-ComfySoftFreeVram
            if ($r.ok) { return (L 'action_soft_vram_ok') }
            if ($r.skipped) { throw (L 'err_comfy_busy' @($r.reason)) }
            throw $r.error
        }
        'gpu_idle_on' {
            $script:GpuIdleAuto = $true
            $path = Join-Path $Toolkit 'gpu-idle.env'
            @(
                'GPU_IDLE_SOFT_FREE=1'
                "GPU_IDLE_MINUTES=$([math]::Max(1, [int]($script:GpuIdleIntervalSec / 60)))"
            ) | Set-Content -LiteralPath $path -Encoding UTF8
            return (L 'action_gpu_idle_on' @([math]::Round($script:GpuIdleIntervalSec/60,1)))
        }
        'gpu_idle_off' {
            $script:GpuIdleAuto = $false
            $path = Join-Path $Toolkit 'gpu-idle.env'
            if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
            return (L 'action_gpu_idle_off')
        }
        'master'       { Launch-Bat 'ACE-Step\Master.bat'; return 'Master.bat' }
        'stems'        { Launch-Bat 'Toolkit\Stems.bat'; return 'Stems.bat' }
        'match'        { Launch-Bat 'Toolkit\Match.bat'; return 'Match.bat' }
        'lyrics'       { Launch-Bat 'Toolkit\Lyrics.bat'; return 'Lyrics.bat' }
        'enhance'      { Launch-Bat 'Toolkit\Enhance.bat'; return 'Enhance.bat (light)' }
        'outputs'      { Launch-Explorer 'Toolkit\Outputs'; return 'Outputs' }
        'references'   { Launch-Explorer 'Toolkit\References'; return 'References' }
        'ace_outputs'  { return (L 'action_ace_outputs' @((Open-AceOutputs))) }
        'comfy_outputs' { return (L 'action_comfy_outputs' @((Open-ComfyOutputs))) }
        'raw_outputs'  { return (L 'action_ace_outputs' @((Open-AceOutputs))) }
        'readme'       {
            $p = Join-Path $Root 'README.md'
            if (Test-Path -LiteralPath $p) { Start-Process -FilePath $p }
            return 'README.md'
        }
        default        { throw (L 'err_unknown_action' @($name)) }
    }
}

$mime = @{
    '.html' = 'text/html'
    '.css'  = 'text/css'
    '.js'   = 'application/javascript'
    '.svg'  = 'image/svg+xml'
    '.ico'  = 'image/x-icon'
}

$null = Get-InboxDir
Write-Host "Upload inbox: $(Get-InboxDir)" -ForegroundColor Gray
Write-Host 'GPU meter: Windows Performance Counters (co 5 s, przy /api/status)' -ForegroundColor Gray
Ensure-GpuStatsFresh

$listener = New-Object System.Net.HttpListener
foreach ($prefix in @(
    "http://127.0.0.1:${Port}/",
    "http://localhost:${Port}/"
)) {
    try {
        $listener.Prefixes.Add($prefix)
        Write-Host "Listen: $prefix" -ForegroundColor Gray
    } catch {
        Write-Host "WARN: prefix $prefix - $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
if ($listener.Prefixes.Count -eq 0) {
    $listener.Prefixes.Add("http://127.0.0.1:${Port}/")
}
$listener.Start()
Write-Host "Dashboard hub: http://127.0.0.1:$Port/  (Ctrl+C = stop)"

try {
    while ($listener.IsListening) {
        Run-HubMaintenanceIfDue
        $ctx = $listener.GetContext()
        $req = $ctx.Request
        $path = $req.Url.LocalPath.TrimEnd('/')
        if (-not $path) { $path = '/' }

        try {
            if ($req.HttpMethod -eq 'OPTIONS') {
                Add-CorsHeaders $ctx
                $ctx.Response.StatusCode = 204
                $ctx.Response.Close()
                continue
            }

            if ($path -eq '/favicon.ico') {
                Add-CorsHeaders $ctx
                $ctx.Response.StatusCode = 302
                $ctx.Response.RedirectLocation = '/favicon.svg'
                $ctx.Response.Close()
                continue
            }

            if ($path -eq '/api/locale') {
                if ($req.HttpMethod -eq 'POST') {
                    $lang = $req.QueryString['lang']
                    if ($lang -in 'pl', 'en') {
                        Set-StudioLocale $lang
                        Send-Json $ctx @{ ok = $true; locale = $lang }
                    } else {
                        Send-Json $ctx @{ ok = $false; error = 'lang must be pl or en' } 400
                    }
                    continue
                }
                Send-Json $ctx @{ ok = $true; locale = (Get-StudioLocale) }
                continue
            }

            if ($path -eq '/api/status') {
                Send-Json $ctx (Get-ServiceStatus)
                continue
            }

            if ($path -eq '/api/gpu') {
                Ensure-GpuStatsFresh -WaitForResult
                Send-Json $ctx (Get-GpuStatsCache)
                continue
            }

            if ($path -eq '/api/comfy-outputs') {
                Send-Json $ctx (Get-ComfyOutputsCache -limit 6)
                continue
            }

            if ($path -eq '/api/comfy-gallery') {
                $lim = 48
                try {
                    $q = $req.QueryString['limit']
                    if ($q) { $lim = [int]$q }
                } catch { }
                if ($lim -lt 1) { $lim = 48 }
                if ($lim -gt 80) { $lim = 80 }
                $refresh = ($req.QueryString['refresh'] -eq '1')
                $folder = $req.QueryString['folder']
                if ($folder) {
                    try { $folder = [Uri]::UnescapeDataString($folder) } catch { }
                }
                Send-Json $ctx (Get-ComfyGalleryCache -folder $folder -limit $lim -Refresh:$refresh)
                continue
            }

            if ($path -eq '/api/comfy-output') {
                $rel = $req.QueryString['rel']
                if ($rel) {
                    try { $rel = [Uri]::UnescapeDataString($rel) } catch { }
                }
                $file = Resolve-ComfyOutputFile $rel
                if (-not $file) {
                    Send-Text $ctx 'Not found' 'text/plain' 404
                    continue
                }
                $ctype = switch ([IO.Path]::GetExtension($file).ToLower()) {
                    '.png'  { 'image/png' }
                    '.jpg'  { 'image/jpeg' }
                    '.jpeg' { 'image/jpeg' }
                    '.webp' { 'image/webp' }
                    '.gif'  { 'image/gif' }
                    '.bmp'  { 'image/bmp' }
                    default { 'application/octet-stream' }
                }
                Send-BinaryFile $ctx $file $ctype
                continue
            }

            if ($path -eq '/api/action') {
                $action = $req.QueryString['name']
                if (-not $action) {
                    Send-Json $ctx @{ ok = $false; error = (L 'err_missing_name') } 400
                    continue
                }
                try {
                    $msg = Invoke-Action $action
                    Send-Json $ctx @{ ok = $true; message = $msg; action = $action }
                } catch {
                    Send-Json $ctx @{ ok = $false; error = $_.Exception.Message } 500
                }
                continue
            }

            if ($path -eq '/api/upload') {
                if ($req.HttpMethod -ne 'POST') {
                    Send-Json $ctx @{ ok = $false; error = 'POST required' } 405
                    continue
                }
                $kind = $req.QueryString['kind']
                $name = Get-UploadFileName $req
                if (-not $kind) {
                    Send-Json $ctx @{ ok = $false; error = (L 'err_missing_kind') } 400
                    continue
                }
                if (-not $name) {
                    Send-Json $ctx @{ ok = $false; error = (L 'err_missing_filename') } 400
                    continue
                }
                try {
                    $saved = Save-UploadStream $req $name
                    Send-Json $ctx @{ ok = $true; kind = $kind; path = $saved; file = (Split-Path $saved -Leaf) }
                } catch {
                    Send-Json $ctx @{ ok = $false; error = $_.Exception.Message } 500
                }
                continue
            }

            if ($path -eq '/api/run') {
                if ($req.HttpMethod -ne 'POST') {
                    Send-Json $ctx @{ ok = $false; error = 'POST required' } 405
                    continue
                }
                $payload = Get-RunRequestPayload $req
                $kind     = $payload.kind
                $filePath = $payload.path
                $refPath  = $payload.ref
                $script:EnhanceMode = $payload.mode
                if (-not $kind -or -not $filePath) {
                    Send-Json $ctx @{ ok = $false; error = 'Brak kind lub path' } 400
                    continue
                }
                if (-not (Test-Path -LiteralPath $filePath)) {
                    Send-Json $ctx @{ ok = $false; error = "Plik nie istnieje: $filePath" } 404
                    continue
                }
                if ((Get-Item -LiteralPath $filePath).Length -lt 1024) {
                    Send-Json $ctx @{ ok = $false; error = 'Plik za krotki (upload nieudany?)' } 400
                    continue
                }
                try {
                    $msg = Invoke-DropProcess $kind $filePath $refPath
                    Send-Json $ctx @{ ok = $true; message = $msg; kind = $kind }
                } catch {
                    Send-Json $ctx @{ ok = $false; error = $_.Exception.Message } 500
                }
                continue
            }

            $rel = switch ($path) {
                '/' { 'index.html' }
                '/style.css' { 'style.css' }
                '/motion.css' { 'motion.css' }
                '/app.js' { 'app.js' }
                '/i18n.js' { 'i18n.js' }
                '/favicon.svg' { 'favicon.svg' }
                default { $null }
            }

            if ($rel) {
                $ext = [IO.Path]::GetExtension($rel)
                Send-File $ctx (Join-Path $WebRoot $rel) $mime[$ext]
                continue
            }

            Send-Text $ctx '404' 'text/plain' 404
        } catch {
            try { Send-Text $ctx $_.Exception.Message 'text/plain' 500 } catch {}
        }
    }
} finally {
    $listener.Stop()
    $listener.Close()
}
