#Requires -Version 5.1
<#
.SYNOPSIS
    Runs the headless MUDRO test suite (physics, progression, content).
.DESCRIPTION
    Exit code 0 = every assertion passed, 1 = failures, 2 = environment problem.
.EXAMPLE
    .\tools\local_build\run_tests.ps1
#>
[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'common.ps1')

try {
    Initialize-GodotEnvironment
    $godot = Get-GodotPath
    Assert-GodotVersion -Godot $godot

    Write-Host "Running test suite..." -ForegroundColor Cyan
    $output = Invoke-Godot -Godot $godot -LogName 'tests.log' -Arguments @(
        '--headless', '--path', $ProjectRoot, 'res://tests/test_runner.tscn'
    )
    $lines = $output -split "`n"
    $lines | Where-Object { $_ -match '^(PASS|FAIL|TESTS:|---|RESULT)' } | ForEach-Object { Write-Host $_ }

    $failCount = ($lines | Where-Object { $_ -match '^FAIL' }).Count
    $summary = $lines | Where-Object { $_ -match '^TESTS:' } | Select-Object -Last 1
    if ($failCount -gt 0) {
        Write-Host "FAILED: $failCount assertion(s)." -ForegroundColor Red
        exit 1
    }
    if (-not $summary) {
        Write-Host "No test summary found - the suite did not run." -ForegroundColor Red
        exit 2
    }
    Write-Host "PASSED: $summary" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
