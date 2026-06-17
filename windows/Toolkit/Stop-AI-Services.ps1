#Requires -Version 5.1
# Zatrzymuje tylko ACE (:7870) i ComfyUI (:7871). Dashboard :7880 zostaje.
. (Join-Path $PSScriptRoot 'Service-Control.ps1')
Stop-StudioServicesBoth | ForEach-Object { Write-Host $_ }
