#Requires -Version 5.1
<#
.SYNOPSIS
    Loads every scene headless and reports any script, resource or runtime error.
.DESCRIPTION
    `--check-only --script` cannot see autoloads, so it reports false errors for
    every `Content` / `GameSession` / `Loc` reference. This runs each real scene
    with the full project booted, which is the only honest compile check.
    Exit code 0 = every scene loaded cleanly.
#>
[CmdletBinding()]
param(
    [int]$Frames = 40
)

. (Join-Path $PSScriptRoot 'local_build\common.ps1')

try {
    Initialize-GodotEnvironment
    $godot = Get-GodotPath
    Assert-GodotVersion -Godot $godot
    Ensure-ProjectImported -Godot $godot

    $scenes = Get-ChildItem -Path (Join-Path $ProjectRoot 'scenes') -Recurse -Filter *.tscn |
        Sort-Object FullName
    $failed = @()
    foreach ($scene in $scenes) {
        $rel = $scene.FullName.Substring($ProjectRoot.Length).TrimStart('\').Replace('\', '/')
        $args = @('--headless', '--path', $ProjectRoot, "res://$rel", '--quit-after', "$Frames")
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            $out = & $godot @args 2>&1 | Out-String
        }
        finally {
            $ErrorActionPreference = $previous
        }
        $bad = @($out -split "`n" | Where-Object { $_ -match 'SCRIPT ERROR|Parse Error|Failed to load|Invalid |Cannot |ERROR:' } |
            Where-Object { $_ -notmatch 'resources still in use at exit' })
        $leak = @($out -split "`n" | Where-Object { $_ -match 'resources still in use at exit' })
        if ($leak.Count -gt 0) {
            Write-Host "WARN $rel (resource leak at exit)" -ForegroundColor Yellow
        }
        if ($bad.Count -gt 0) {
            $failed += $rel
            Write-Host "FAIL $rel" -ForegroundColor Red
            $bad | Select-Object -First 6 | ForEach-Object { Write-Host "     $($_.Trim())" -ForegroundColor DarkRed }
        }
        else {
            Write-Host "PASS $rel" -ForegroundColor Green
        }
    }

    Write-Host ''
    if ($failed.Count -gt 0) {
        Write-Host "SCENES FAILED: $($failed.Count)/$($scenes.Count)" -ForegroundColor Red
        exit 1
    }
    Write-Host "ALL SCENES OK: $($scenes.Count)" -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 2
}
