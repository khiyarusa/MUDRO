#Requires -Version 5.1
<#
.SYNOPSIS
    Shared helpers for the MUDRO local build scripts.
.DESCRIPTION
    Resolves the Godot 4.7.2 executable, prepares a sane environment (Godot needs
    APPDATA to find export templates and editor settings), and provides logging.
#>

$ErrorActionPreference = 'Stop'

$script:ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$script:LogDir = Join-Path $ProjectRoot 'local-builds\logs'
$script:RequiredVersion = '4.7.2'

function Get-GodotPath {
    $candidates = @()
    if ($env:GODOT_BIN) { $candidates += $env:GODOT_BIN }
    $candidates += @(
        'H:\Game\Engines\Godot\editor\Godot_v4.7.2-stable_win64_console.exe',
        'H:\Game\Engines\Godot\editor\Godot_v4.7.2-stable_win64.exe',
        'C:\Program Files\Godot\Godot_v4.7.2-stable_win64_console.exe',
        (Join-Path $env:USERPROFILE 'Godot\Godot_v4.7.2-stable_win64_console.exe'),
        (Join-Path $env:USERPROFILE 'Godot\Godot_v4.7.2-stable_win64.exe')
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path -LiteralPath $path)) { return (Resolve-Path -LiteralPath $path).Path }
    }
    throw "Godot 4.7.2 not found. Set GODOT_BIN to the executable path."
}

function Initialize-GodotEnvironment {
    # Godot derives user:// from APPDATA. Automation shells sometimes strip it, which
    # makes the engine fall back to a relative directory and lose export templates.
    if (-not $env:APPDATA -and $env:USERPROFILE) {
        $env:APPDATA = Join-Path $env:USERPROFILE 'AppData\Roaming'
    }
    if (-not $env:LOCALAPPDATA -and $env:USERPROFILE) {
        $env:LOCALAPPDATA = Join-Path $env:USERPROFILE 'AppData\Local'
    }
    New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null
}

function Assert-GodotVersion {
    param([Parameter(Mandatory = $true)][string]$Godot)
    $raw = & $Godot --headless --version 2>&1 | Out-String
    if ($raw -notmatch [regex]::Escape($script:RequiredVersion)) {
        throw "Expected Godot $script:RequiredVersion, got: $($raw.Trim())"
    }
    Write-Host "Godot $script:RequiredVersion verified." -ForegroundColor DarkGray
}

function Write-BuildLog {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string[]]$Lines
    )
    New-Item -ItemType Directory -Force -Path $script:LogDir | Out-Null
    $path = Join-Path $script:LogDir $Name
    $Lines | Set-Content -LiteralPath $path -Encoding UTF8
    Write-Host "Log: $path" -ForegroundColor DarkGray
}

function Invoke-Godot {
    param(
        [Parameter(Mandatory = $true)][string]$Godot,
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [Parameter(Mandatory = $true)][string]$LogName
    )
    # Godot writes warnings to stderr. With $ErrorActionPreference = 'Stop' PowerShell
    # 5.1 turns the first stderr line into a terminating NativeCommandError, which used
    # to abort the test run before the summary was printed. Capture, never throw.
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Godot @Arguments 2>&1 | Out-String
    }
    finally {
        $ErrorActionPreference = $previous
    }
    Write-BuildLog -Name $LogName -Lines @($output)
    return $output
}

# A cold checkout has no .godot class cache, so every class_name fails to resolve.
# Import first when the cache is missing or older than the newest script.
function Ensure-ProjectImported {
    param([Parameter(Mandatory = $true)][string]$Godot)
    $cache = Join-Path $ProjectRoot '.godot\global_script_class_cache.cfg'
    $needsImport = -not (Test-Path -LiteralPath $cache)
    if (-not $needsImport) {
        $cacheTime = (Get-Item -LiteralPath $cache).LastWriteTimeUtc
        $newest = Get-ChildItem -Path (Join-Path $ProjectRoot 'scripts') -Recurse -Filter *.gd -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
        if ($newest -and $newest.LastWriteTimeUtc -gt $cacheTime) { $needsImport = $true }
    }
    if (-not $needsImport) { return }
    Write-Host 'Importing project (class cache missing or stale)...' -ForegroundColor DarkGray
    Invoke-Godot -Godot $Godot -LogName 'import.log' -Arguments @('--headless', '--path', $ProjectRoot, '--import') | Out-Null
}
