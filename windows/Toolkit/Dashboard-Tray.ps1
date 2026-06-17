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
                return (L 'tray_soft_free')
            }
            'force_free_gpu' {
                & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $Toolkit 'Force-Free-GPU.ps1') -Quiet
                return (L 'tray_hard_free')
            }
            'restart_hub' { return (Start-StudioHub) }
            default { throw (L 'err_unknown_action' @($name)) }
        }
    } catch {
        return (L 'tray_err_action' @($_.Exception.Message))
    }
}

function Test-SvcOn($state) {
    return $state -in @('online', 'starting', 'hung')
}

function Format-TrayTip($s) {
    if (-not $s) {
        return (L 'tray_tip_offline')
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
        (L 'tray_tip_online')
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
    $hubMsg = (L 'tray_hub_running')
    Write-TrayLog $hubMsg
} else {
    $hubMsg = (L 'tray_starting_hub')
    Write-TrayLog $hubMsg
    try { Start-HubInBackground } catch {
        $hubMsg = (L 'tray_hub_start_err' @($_.Exception.Message))
        Write-TrayLog $hubMsg
    }
}

$menu = New-Object System.Windows.Forms.ContextMenuStrip

$mOpen = $menu.Items.Add((L 'tray_open_dashboard'))
$mOpen.Add_Click({ Start-Process $script:HubUrl })

$menu.Items.Add('-') | Out-Null

$mStartAce = $menu.Items.Add((L 'tray_start_ace'))
$mStopAce = $menu.Items.Add((L 'tray_stop_ace'))
$mStartComfy = $menu.Items.Add((L 'tray_start_comfy'))
$mStopComfy = $menu.Items.Add((L 'tray_stop_comfy'))
$mStartAce.Add_Click({ Show-Balloon $script:notify 'ACE' (Invoke-HubAction 'start_ace') })
$mStopAce.Add_Click({ Show-Balloon $script:notify 'ACE' (Invoke-HubAction 'stop_ace') })
$mStartComfy.Add_Click({ Show-Balloon $script:notify 'Comfy' (Invoke-HubAction 'start_comfy') })
$mStopComfy.Add_Click({ Show-Balloon $script:notify 'Comfy' (Invoke-HubAction 'stop_comfy') })

$menu.Items.Add('-') | Out-Null

$mStartAi = $menu.Items.Add((L 'tray_start_both'))
$mStopAi = $menu.Items.Add((L 'tray_stop_both'))
$mStartAi.Add_Click({ Show-Balloon $script:notify 'Stack' (Invoke-HubAction 'start_stack') })
$mStopAi.Add_Click({ Show-Balloon $script:notify 'Stack' (Invoke-HubAction 'stop_stack') })

$menu.Items.Add('-') | Out-Null

$mSoft = $menu.Items.Add((L 'tray_soft_vram'))
$mHard = $menu.Items.Add((L 'tray_hard_gpu'))
$mSoft.Add_Click({ Show-Balloon $script:notify 'VRAM' (Invoke-HubAction 'soft_free_vram') })
$mHard.Add_Click({
    $r = [Windows.Forms.MessageBox]::Show(
        (L 'tray_confirm_hard'),
        'AI Studio',
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Warning
    )
    if ($r -eq 'Yes') { Show-Balloon $script:notify 'GPU' (Invoke-HubAction 'force_free_gpu') }
})

$menu.Items.Add('-') | Out-Null

$mLangPl = $menu.Items.Add((L 'tray_lang_pl'))
$mLangEn = $menu.Items.Add((L 'tray_lang_en'))
$mLangPl.Add_Click({
    Set-StudioLocale 'pl'
    Update-TrayMenuTexts
    Show-Balloon $script:notify 'PL' (L 'tray_lang_pl')
})
$mLangEn.Add_Click({
    Set-StudioLocale 'en'
    Update-TrayMenuTexts
    Show-Balloon $script:notify 'EN' (L 'tray_lang_en')
})

$menu.Items.Add('-') | Out-Null

$mStatus = $menu.Items.Add((L 'tray_show_status'))
$mStatus.Add_Click({
    $s = if ($script:LastStatus) { $script:LastStatus } else { Get-HubStatus }
    [Windows.Forms.MessageBox]::Show(
        (Format-TrayTip $s),
        (L 'tray_status_title'),
        [Windows.Forms.MessageBoxButtons]::OK,
        [Windows.Forms.MessageBoxIcon]::Information
    ) | Out-Null
})

$mHub = $menu.Items.Add((L 'tray_restart_hub'))
$mHub.Add_Click({
    Stop-DashboardHub
    Start-Sleep -Seconds 2
    $msg = Start-StudioHub
    Show-Balloon $script:notify 'Hub' $msg
})

$menu.Items.Add('-') | Out-Null

$mExit = $menu.Items.Add((L 'tray_exit'))
$mExit.Add_Click({
    $r = [Windows.Forms.MessageBox]::Show(
        (L 'tray_confirm_exit'),
        'AI Studio',
        [Windows.Forms.MessageBoxButtons]::YesNo,
        [Windows.Forms.MessageBoxIcon]::Question
    )
    if ($r -eq 'Yes') { Exit-StudioTray }
})

function Update-TrayMenuTexts {
    $mOpen.Text = L 'tray_open_dashboard'
    $mStartAce.Text = L 'tray_start_ace'
    $mStopAce.Text = L 'tray_stop_ace'
    $mStartComfy.Text = L 'tray_start_comfy'
    $mStopComfy.Text = L 'tray_stop_comfy'
    $mStartAi.Text = L 'tray_start_both'
    $mStopAi.Text = L 'tray_stop_both'
    $mSoft.Text = L 'tray_soft_vram'
    $mHard.Text = L 'tray_hard_gpu'
    $mLangPl.Text = L 'tray_lang_pl'
    $mLangEn.Text = L 'tray_lang_en'
    $mStatus.Text = L 'tray_show_status'
    $mHub.Text = L 'tray_restart_hub'
    $mExit.Text = L 'tray_exit'
}

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
    Show-Balloon $script:notify 'AI Studio' (L 'tray_boot_ready') 3500
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
    (L 'tray_balloon_icon')
    (L 'tray_balloon_hidden')
    (L 'tray_tip_close')
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
        (L 'tray_err_start' @($_.Exception.Message)),
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
