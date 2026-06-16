#Requires -Version 5.1
<#
.SYNOPSIS
  Skan ciszy + raport TXT + otwarcie ACE-Step (Repaint).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputFile,
    [switch]$NoOpenAce
)

$script = Join-Path $PSScriptRoot 'Scan-Silence.ps1'
& $script -InputFile $InputFile -SaveReport -OpenAce:(-not $NoOpenAce)
exit $LASTEXITCODE
