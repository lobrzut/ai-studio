#Requires -Version 5.1
# Tworzy Toolkit\AIStudio-Tray.ico (jednorazowo)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$Toolkit = $PSScriptRoot
$icoPath = Join-Path $Toolkit 'AIStudio-Tray.ico'
if (Test-Path -LiteralPath $icoPath) { exit 0 }

$size = 32
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.Clear([System.Drawing.Color]::FromArgb(255, 5, 5, 8))
$pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 250, 204, 21), 2)
$g.DrawEllipse($pen, 3, 3, 26, 26)
$brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 250, 204, 21))
$g.FillPolygon($brush, @(
    [System.Drawing.Point]::new(9, 20),
    [System.Drawing.Point]::new(9, 12),
    [System.Drawing.Point]::new(16, 15),
    [System.Drawing.Point]::new(23, 12),
    [System.Drawing.Point]::new(23, 20),
    [System.Drawing.Point]::new(16, 17)
))
$icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
$cloned = New-Object System.Drawing.Icon($icon, 32, 32)
$fs = [System.IO.File]::OpenWrite($icoPath)
$cloned.Save($fs)
$fs.Close()
$icon.Dispose()
$cloned.Dispose()
$g.Dispose()
$pen.Dispose()
$brush.Dispose()
$bmp.Dispose()
Write-Host "OK: $icoPath"
