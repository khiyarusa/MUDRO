#Requires -Version 5.1
<#
.SYNOPSIS
    Runs MUDRO on this machine (desktop window, mouse/keyboard controls).
.EXAMPLE
    .\tools\local_build\run_game.ps1
    .\tools\local_build\run_game.ps1 -Scene res://scenes/race/race.tscn -Autodrive
#>
[CmdletBinding()]
param(
    [string]$Scene = '',
    [switch]$Autodrive,
    [switch]$Headless
)

. (Join-Path $PSScriptRoot 'common.ps1')

try {
    Initialize-GodotEnvironment
    $godot = Get-GodotPath
    Assert-GodotVersion -Godot $godot

    $arguments = @('--path', $ProjectRoot)
    if ($Headless) { $arguments += '--headless' }
    if ($Scene) { $arguments += $Scene }
    if ($Autodrive) { $arguments += '--autodrive' }

    Write-Host "Launching MUDRO..." -ForegroundColor Cyan
    & $godot @arguments
    exit $LASTEXITCODE
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
