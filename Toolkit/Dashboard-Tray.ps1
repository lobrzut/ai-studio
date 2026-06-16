#Requires -Version 5.1
# Tray = wlasciciel calego stacku. Bez ikony tray: brak huba, ACE, Comfy.
param(
    [switch]$OpenBrowser,
    [switch]$AutoStartAi
)

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$Toolkit = $PSScriptRoot
$Root    = Split-Path $Toolkit -Parent
$script:TrayLog = Join-Path $Root 'logs\tray.log'

function Write-TrayLog([string]$msg) {
    try {
        $dir = Split-Path $script:TrayLog -Parent
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Add-Content -LiteralPath $script:TrayLog -Encoding UTF8
    } catch { }
}

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $psExe = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (-not (Test-Path -LiteralPath $psExe)) { $psExe = 'powershell.exe' }
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Sta', '-File', $PSCommandPath)
    if ($OpenBrowser) { $argList += '-OpenBrowser' }
    if ($AutoStartAi) { $argList += '-AutoStartAi' }
    Write-TrayLog "Relaunch STA: $psExe"
    Start-Process -FilePath $psExe -ArgumentList $argList -WindowStyle Minimized | Out-Null
    exit 0
}

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-TrayLog "Tray start PID=$PID"
$HubUrl  = 'http://127.0.0.1:7880'
$HubApi  = "$HubUrl/api/status"
$HubAct  = "$HubUrl/api/action"

. (Join-Path $Toolkit 'Service-Control.ps1')

$script:AutoStartAiPending = [bool]$AutoStartAi
$script:OpenBrowserPending = [bool]$OpenBrowser

$mutex = New-Object Threading.Mutex($false, 'AIStudioPortable.DashboardTray')
if (-not $mutex.WaitOne(0, $false)) {
    if ($OpenBrowser -and (Test-StudioPort 7880)) { Start-Process $HubUrl }
    exit 0
}

Repair-OrphanStackBeforeTray | Out-Null
Write-TrayLock
Write-TrayLog 'Tray lock written'

function Get-TrayIconPath {
    $ico = Join-Path $Toolkit 'AIStudio-Tray.ico'
    if (-not (Test-Path -LiteralPath $ico)) {
        $gen = Join-Path $Toolkit 'Ensure-TrayIcon.ps1'
        if (Test-Path -LiteralPath $gen) {
            & powershell -NoProfile -ExecutionPolicy Bypass -File $gen | Out-Null
        }
    }
    return $ico
}

function New-TrayIcon {
    $icoPath = Get-TrayIconPath
    if (Test-Path -LiteralPath $icoPath) {
        return New-Object System.Drawing.Icon($icoPath)
    }
    Write-TrayLog 'WARN: brak AIStudio-Tray.ico — ikona systemowa'
    return [System.Drawing.SystemIcons]::Application
}

function Start-HubInBackground {
    $restart = Join-Path $Toolkit 'Restart-Dashboard.ps1'
    if (-not (Test-Path -LiteralPath $restart)) {
        throw "Brak $restart"
    }
    Start-Process -FilePath 'powershell.exe' -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $restart
    ) -WorkingDirectory $Toolkit -WindowStyle Hidden | Out-Null
}

function Get-HubStatus {
    try { return Invoke-RestMethod -Uri $HubApi -TimeoutSec 4 } catch { return $null }
}

function Invoke-HubAction([string]$name) {
    try {
        $r = Invoke-RestMethod -Uri "$HubAct`?name=$name" -TimeoutSec 120
        if ($r.ok) { return [string]$r.message }
        throw [string]$r.error
    } catch {
        return (Invoke-LocalAction $name)
    }
}

function Invoke-LocalAction([string]$name) {
    try {
        switch ($name) {
            'start_ace'   { return (Start-StudioService -Name Ace) }
            'stop_ace'    { return (Stop-StudioService -Name Ace) }
            'start_comfy' { return (Start-StudioService -Name Comfy) }
            'stop_comfy'  { return (Stop-StudioService -Name Comfy) }
            'start_stack' { return ((Ensure-DashboardHub) + ' ' + (Start-StudioServicesBoth)) }
            'stop_stack'  { return (Stop-StudioServicesBoth) }
            'soft_free_vram' {
                & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Toolkit 'Soft-Free-GPU.ps1') -Quiet
                return 'Soft free VRAM (Comfy)'
            }
            'force_free_gpu' {
                & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Toolkit 'Force-Free-GPU.ps1') -Quiet
                return 'Zwolniono GPU (hard)'
            }
            'restart_hub' { return (Start-StudioHub) }
            default { throw "Nieznana akcja: $name" }
        }
    } catch {
        return "Blad: $($_.Exception.Message)"
    }
}

function Test-SvcOn($state) {
    return $state -in @('online', 'starting', 'hung')
}

function Format-TrayTip($s) {
    if (-not $s) {
        return @(
            'AI Studio Portable'
            'Hub: offline'
            'Zamknij tray = caly stack OFF'
        ) -join "`n"
    }
    $gpu = $s.gpu
    $vram = if ($gpu.vram_used_mb) { "{0:N1}/{1:N1} GB VRAM" -f ($gpu.vram_used_mb/1024), ($gpu.vram_total_mb/1024) } else { 'VRAM: ?' }
    $util = if ($null -ne $gpu.util_pct) { "GPU {0}%" -f $gpu.util_pct } else { 'GPU ?' }
    $st = $gpu.stack
    $stackLine = if ($st) {
        $rv = if ($st.vram_mb -ne $null) { "{0:N1} GB" -f ($st.vram_mb/1024) } else { 'n/d' }
        "Stack RAM {0} MB | VRAM {1} | CPU {2}" -f $st.ram_mb, $rv, $(if($st.cpu_pct -ne $null){"$($st.cpu_pct)%"}else{'?'})
    } else { '' }
    $lines = @(
        'AI Studio Portable (tray ON)'
        "ACE: $($s.ace.state)  |  Comfy: $($s.comfy.state)"
        "$util  |  $vram"
        $stackLine
    ) | Where-Object { $_ }
    return ($lines -join "`n")
}

function Show-Balloon($ni, [string]$title, [string]$text, [int]$timeoutMs = 4000) {
    if ($text.Length -gt 240) { $text = $text.Substring(0, 237) + '...' }
    $ni.BalloonTipTitle = $title
    $ni.BalloonTipText = $text
    $ni.ShowBalloonTip($timeoutMs)
}

function Set-NotifyShortText($ni, [string]$full) {
    $short = ($full -replace "`r?`n", ' | ')
    if ($short.Length -gt 63) { $short = $short.Substring(0, 60) + '...' }
    $ni.Text = $short
}

function Exit-StudioTray {
    [Windows.Forms.Application]::Exit()
}

$script:LastStatus = $null
$script:HubUrl = $HubUrl
$script:HubReady = $false

$icon = New-TrayIcon
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = $icon
$notify.Text = 'AI Studio'
$notify.Visible = $true
$script:notify = $notify
Write-TrayLog 'NotifyIcon Visible=true'

if (Test-StudioPort 7880) {
    $script:HubReady = $true
    $hubMsg = 'Dashboard hub juz dziala (:7880).'
    Write-TrayLog $hubMsg
} else {
    $hubMsg = 'Uruchamiam dashboard hub...'
    Write-TrayLog $hubMsg
    try { Start-HubInBackground } catch {
        $hubMsg = "Hub start blad: $($_.Exception.Message)"
        Write-TrayLog $hubMsg
    }
}

$menu = New-Object System.Windows.Forms.ContextMenuStrip

$mOpen = $menu.Items.Add('Otworz dashboard')
$mOpen.Add_Click({ Start-Process $script:HubUrl })

$menu.Items.Add('-') | Out-Null

$mStartAce = $menu.Items.Add('Start ACE-Step')
$mStopAce = $menu.Items.Add('Stop ACE-Step')
$mStartComfy = $menu.Items.Add('Start ComfyUI')
$mStopComfy = $menu.Items.Add('Stop ComfyUI')
$mStartAce.Add_Click({ Show-Balloon $script:notify 'ACE' (Invoke-HubAction 'start_ace') })
$mStopAce.Add_Click({ Show-Balloon $script:notify 'ACE' (Invoke-HubAction 'stop_ace') })
$mStartComfy.Add_Click({ Show-Balloon $script:notify 'Comfy' (Invoke-HubAction 'start_comfy') })
$mStopComfy.Add_Click({ Show-Balloon $script:notify 'Comfy' (Invoke-HubAction 'stop_comfy') })

$menu.Items.Add('-') | Out-Null

$mStartAi = $menu.Items.Add('Start AI (oba)')
$mStopAi = $menu.Items.Add('Stop AI (oba)')
$mStartAi.Add_Click({ Show-Balloon $script:notify 'Stack' (Invoke-HubAction 'start_stack') })
$mStopAi.Add_Click({ Show-Balloon $script:notify 'Stack' (Invoke-HubAction 'stop_stack') })

$menu.Items.Add('-') | Out-Null

$mSoft = $menu.Items.Add('Zwolnij VRAM (soft, Comfy)')
$mHard = $menu.Items.Add('Zwolnij GPU (hard)')
$mSoft.Add_Click({ Show-Balloon $script:notify 'VRAM' (Invoke-HubAction 'soft_free_vram') })
$mHard.Add_Click({
    $r = [Windows.Forms.MessageBox]::Show(
        'Zatrzymac ComfyUI i ACE-Step i zwolnic VRAM?',
        'AI Studio',
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($r -eq 'Yes') { Show-Balloon $script:notify 'GPU' (Invoke-HubAction 'force_free_gpu') }
})

$menu.Items.Add('-') | Out-Null

$mStatus = $menu.Items.Add('Pokaz status...')
$mStatus.Add_Click({
    $s = if ($script:LastStatus) { $script:LastStatus } else { Get-HubStatus }
    [Windows.Forms.MessageBox]::Show(
        (Format-TrayTip $s),
        'AI Studio - status',
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
})

$mHub = $menu.Items.Add('Restart dashboard hub')
$mHub.Add_Click({
    Stop-DashboardHub
    Start-Sleep -Seconds 2
    $msg = Start-StudioHub
    Show-Balloon $script:notify 'Hub' $msg
})

$menu.Items.Add('-') | Out-Null

$mExit = $menu.Items.Add('Zamknij AI Studio (wszystko)')
$mExit.Add_Click({
    $r = [Windows.Forms.MessageBox]::Show(
        'Zatrzymac hub, ACE, Comfy i zamknac ikone tray?',
        'AI Studio',
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Question
    )
    if ($r -eq 'Yes') { Exit-StudioTray }
})

$notify.ContextMenuStrip = $menu

$menu.Add_Opening({
    $s = Get-HubStatus
    $script:LastStatus = $s
    $aceOn = $s -and (Test-SvcOn $s.ace.state)
    $comfyOn = $s -and (Test-SvcOn $s.comfy.state)
    $mStartAce.Enabled = -not $aceOn
    $mStopAce.Enabled = $aceOn
    $mStartComfy.Enabled = -not $comfyOn
    $mStopComfy.Enabled = $comfyOn
    $mSoft.Enabled = $comfyOn
    Set-NotifyShortText $script:notify (Format-TrayTip $s)
})

$notify.Add_DoubleClick({ Start-Process $script:HubUrl })

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 5000
$timer.Add_Tick({
    $s = Get-HubStatus
    $script:LastStatus = $s
    Set-NotifyShortText $script:notify (Format-TrayTip $s)
})
$timer.Start()

$script:BootDone = $false
function Complete-TrayBoot {
    if ($script:BootDone) { return }
    $script:BootDone = $true
    $script:HubReady = $true
    Write-TrayLog 'Hub port 7880 OK'
    Show-Balloon $script:notify 'AI Studio' 'Dashboard gotowy: http://127.0.0.1:7880/' 3500
    if ($script:AutoStartAiPending) {
        $script:AutoStartAiPending = $false
        Show-Balloon $script:notify 'Start' (Invoke-HubAction 'start_stack') 3000
    }
    if ($script:OpenBrowserPending) {
        $script:OpenBrowserPending = $false
        Start-Process $script:HubUrl
    }
}

$bootTimer = New-Object System.Windows.Forms.Timer
$bootTimer.Interval = 1500
$bootTimer.Add_Tick({
    if (-not (Test-StudioPort 7880)) { return }
    $bootTimer.Stop()
    $bootTimer.Dispose()
    Complete-TrayBoot
})
$bootTimer.Start()
if (Test-StudioPort 7880) { Complete-TrayBoot }

Show-Balloon $notify 'AI Studio' @(
    $hubMsg
    'Ikona przy zegarze (zolte A).'
    'Jesli jej nie widzisz: strzalka ^ przy zegarze -> Ikony zasobnika.'
    'Zamknij tray = caly stack OFF.'
) -join "`n" 6000

$hiddenForm = New-Object System.Windows.Forms.Form
$hiddenForm.Name = 'AIStudioTrayHost'
$hiddenForm.Text = 'AI Studio'
$hiddenForm.ShowInTaskbar = $false
$hiddenForm.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedToolWindow
$hiddenForm.StartPosition = [System.Windows.Forms.FormStartPosition]::Manual
$hiddenForm.Location = New-Object System.Drawing.Point (-32000, -32000)
$hiddenForm.Size = New-Object System.Drawing.Size 1, 1
$hiddenForm.Add_Load({ $this.Hide() })

try {
    Write-TrayLog 'Message loop (hidden form)'
    [void]$hiddenForm.Show()
    [System.Windows.Forms.Application]::Run($hiddenForm)
} catch {
    Write-TrayLog "Run error: $($_.Exception.Message)"
    [Windows.Forms.MessageBox]::Show(
        "Tray nie moze wystartowac:`n$($_.Exception.Message)`n`nLog: logs\tray.log",
        'AI Studio',
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Error
    ) | Out-Null
} finally {
    Write-TrayLog 'Tray shutdown'
    $timer.Stop()
    $timer.Dispose()
    $notify.Visible = $false
    $notify.Dispose()
    $icon.Dispose()
    Stop-StudioAll
    Remove-TrayLock
    if ($hiddenForm) { $hiddenForm.Dispose() }
    $mutex.ReleaseMutex() | Out-Null
    $mutex.Dispose()
}
