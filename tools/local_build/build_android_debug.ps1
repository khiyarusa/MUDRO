#Requires -Version 5.1
<#
.SYNOPSIS
    Builds the MUDRO Android debug APK locally and verifies the result.
.DESCRIPTION
    Uses the locally installed Godot 4.7.2 export templates and the Android
    build-tools to produce local-builds/android/MUDRO-debug.apk, then checks the
    package id, architectures and signature with aapt2/apksigner.
.EXAMPLE
    .\tools\local_build\build_android_debug.ps1
    .\tools\local_build\build_android_debug.ps1 -Install
#>
[CmdletBinding()]
param(
    [switch]$Install,
    [string]$BuildTools = ''
)

. (Join-Path $PSScriptRoot 'common.ps1')

try {
    Initialize-GodotEnvironment
    $godot = Get-GodotPath
    Assert-GodotVersion -Godot $godot

    $outDir = Join-Path $ProjectRoot 'local-builds\android'
    $reportDir = Join-Path $ProjectRoot 'local-builds\reports'
    New-Item -ItemType Directory -Force -Path $outDir, $reportDir | Out-Null
    $apk = Join-Path $outDir 'MUDRO-debug.apk'
    if (Test-Path -LiteralPath $apk) { Remove-Item -LiteralPath $apk -Force }

    Write-Host "Exporting Android debug APK..." -ForegroundColor Cyan
    $output = Invoke-Godot -Godot $godot -LogName 'android_export.log' -Arguments @(
        '--headless', '--path', $ProjectRoot, '--export-debug', 'Android', $apk
    )

    if (-not (Test-Path -LiteralPath $apk)) {
        Write-Host "Export failed. Last lines:" -ForegroundColor Red
        ($output -split "`n") | Select-Object -Last 25 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
        exit 1
    }

    $file = Get-Item -LiteralPath $apk
    $hash = (Get-FileHash -LiteralPath $apk -Algorithm SHA256).Hash
    Write-Host ("APK: {0} ({1:N1} MB)" -f $file.FullName, ($file.Length / 1MB)) -ForegroundColor Green
    Write-Host "SHA256: $hash" -ForegroundColor DarkGray

    # Locate build-tools for verification.
    if (-not $BuildTools) {
        $sdkCandidates = @(
            'F:\Unity\Editors\6000.3.11f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\build-tools',
            'H:\Game\Engines\Android-SDK\toolchain\sdk\build-tools'
        )
        foreach ($root in $sdkCandidates) {
            if (Test-Path -LiteralPath $root) {
                $latest = Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name -Descending | Select-Object -First 1
                if ($latest) { $BuildTools = $latest.FullName; break }
            }
        }
    }

    $badging = ''
    $previousEap = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    if ($BuildTools -and (Test-Path -LiteralPath (Join-Path $BuildTools 'aapt2.exe'))) {
        $aapt = Join-Path $BuildTools 'aapt2.exe'
        $badging = & $aapt dump badging $apk 2>&1 | Out-String
        ($badging -split "`n") | Where-Object { $_ -match 'package:|sdkVersion|native-code|application-label:' } |
            Select-Object -First 5 | ForEach-Object { Write-Host $_.Trim() }
        $apksigner = Join-Path $BuildTools 'apksigner.bat'
        if (Test-Path -LiteralPath $apksigner) {
            $verify = & $apksigner verify --print-certs $apk 2>&1 | Out-String
            if ($verify -match 'Signer #1') { Write-Host "Signature: verified" -ForegroundColor Green }
            else { Write-Host "Signature: NOT verified" -ForegroundColor Red }
        }
    }
    $ErrorActionPreference = $previousEap

    $verifyLines = @()
    foreach ($line in ($badging -split "`n")) {
        if ($line -match 'package:|sdkVersion|native-code|application-label:') {
            $verifyLines += $line.Trim()
        }
    }
    $reportLines = @(
        '# MUDRO - Android build report',
        '',
        ('Built: ' + (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')),
        ('APK: ' + $apk),
        ('Size: {0:N0} bytes ({1:N1} MB)' -f $file.Length, ($file.Length / 1MB)),
        ('SHA256: ' + $hash),
        '',
        '## Manifest verification (aapt2 dump badging)',
        '```'
    )
    $reportLines += $verifyLines
    $reportLines += @(
        '```',
        '',
        '## Export command',
        '```',
        ('godot --headless --path . --export-debug Android ' + $apk),
        '```'
    )
    Set-Content -LiteralPath (Join-Path $reportDir 'ANDROID_BUILD_REPORT.md') -Value $reportLines -Encoding UTF8
    Write-Host "Report: $reportDir\ANDROID_BUILD_REPORT.md" -ForegroundColor DarkGray

    if ($Install) {
        $adb = ''
        $adbCandidates = @(
            'F:\Unity\Editors\6000.3.11f1\Editor\Data\PlaybackEngines\AndroidPlayer\SDK\platform-tools\adb.exe',
            'H:\Game\Engines\Android-SDK\toolchain\sdk\platform-tools\adb.exe'
        )
        foreach ($candidate in $adbCandidates) { if (Test-Path -LiteralPath $candidate) { $adb = $candidate; break } }
        if (-not $adb) { Write-Host "adb not found - skipping install." -ForegroundColor Yellow }
        else {
            Write-Host "Installing on device..." -ForegroundColor Cyan
            & $adb install -r $apk
            if ($LASTEXITCODE -ne 0) { Write-Host "adb install failed." -ForegroundColor Red; exit 1 }
            Write-Host "Installed. Launch it from the device launcher." -ForegroundColor Green
        }
    }

    exit 0
}
catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
