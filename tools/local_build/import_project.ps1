#Requires -Version 5.1
<#
.SYNOPSIS
    Imports the MUDRO project (regenerates .godot cache, imports SVG/WAV/fonts).
.EXAMPLE
    .\tools\local_build\import_project.ps1
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'common.ps1')

try {
    Initialize-GodotEnvironment
    $godot = Get-GodotPath
    Assert-GodotVersion -Godot $godot
    Write-Host "Importing project..." -ForegroundColor Cyan
    $output = Invoke-Godot -Godot $godot -LogName 'import.log' -Arguments @(
        '--headless', '--path', $ProjectRoot, '--import'
    )
    $errors = ($output -split "`n") | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Failed to load' }
    if ($errors) {
        Write-Host "Import reported script errors:" -ForegroundColor Red
        $errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        exit 1
    }
    Write-Host "Import complete." -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
