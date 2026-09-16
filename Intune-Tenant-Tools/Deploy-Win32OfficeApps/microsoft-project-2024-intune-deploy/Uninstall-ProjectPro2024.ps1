<#
.TITLE
    Uninstall-ProjectPro2024

.SYNOPSIS
    Silent uninstaller for Microsoft Project Professional 2024 (volume) via the Office Deployment Tool.

.DESCRIPTION
    PowerShell wrapper for `setup.exe /configure Uninstall-ProjectPro2024.xml` designed to run under
    an Intune Win32 app assignment (SYSTEM context) or an elevated prompt.
    - Anchors every path to the script folder (dot-source safe, $PSScriptRoot fallback).
    - Refuses to run without elevation and fails fast when bundle files are missing.
    - Invokes ODT synchronously and forwards its real exit code to Intune (0 = success).
    - Writes a dedicated transcript to <SystemDrive>\IntuneLogs\ProjectPro2024\.

.TAGS
    Intune,Win32App,Office,Project,Deployment,Uninstall

.PLATFORM
    Windows 10, Windows 11

.PERMISSIONS
    None (local SYSTEM context) - removes a Click-to-Run product locally; no Graph calls.

.AUTHOR
    Mohammad Abdelkader Omar | GitHub @mabdulkadr | momar.tech

.VERSION
    1.2.0

.CHANGELOG
    1.2.0 (2026-09-16) - Migrated from ProjectPro2019Volume to ProjectPro2024Volume
                         (PerpetualVL2024 channel); XML renamed to Uninstall-ProjectPro2024.xml;
                         logs to <SystemDrive>\IntuneLogs\ProjectPro2024\.
    1.1.0 (2026-09-16) - Canonical rewrite: uninstall now removes ProjectPro2019Volume (the product
                         this package installs) instead of ProjectProRetail, adds canonical logging
                         to <SystemDrive>\IntuneLogs\ProjectPro2024\, and forwards the real setup.exe
                         exit code to Intune.
    1.0.0 (2023)        - Original packaging.

.LASTUPDATE
    2026-09-16

.PARAMETER ConfigurationPath
    Path to Uninstall-ProjectPro2024.xml. Defaults to the file beside this script.

.PARAMETER SetupPath
    Path to setup.exe (Office Deployment Tool). Defaults to the file beside this script.

.EXAMPLE
    powershell.exe -ExecutionPolicy Bypass -NoProfile -File .\Uninstall-ProjectPro2024.ps1
    Removes the volume-licensed Project Professional 2024 product silently.

.NOTES
    - Intune Win32 app uninstall command; runs as System.
    - Returns the Office Deployment Tool exit code (0 = success).
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$ConfigurationPath = '',
    [string]$SetupPath = ''
)

$ErrorActionPreference = 'Stop'
$SolutionName = 'ProjectPro2024'
$ScriptMode   = 'uninstall'

# --- Script-location anchoring (Law 12) --------------------------------------
# Resolves the script folder even when dot-sourced (leaving $PSScriptRoot empty).
$scriptBase = if ($PSScriptRoot) { $PSScriptRoot }
elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath }
elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path }
else { (Get-Location).Path }

if (-not $ConfigurationPath) { $ConfigurationPath = Join-Path $scriptBase 'Uninstall-ProjectPro2024.xml' }
if (-not $SetupPath) { $SetupPath = Join-Path $scriptBase 'setup.exe' }

# --- Logging (CLI Configuration) ---------------------------------------------
# Canonical CLI logging helpers, copied verbatim (self-contained: no dot-sourcing).
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')]
        [string]$Type = 'General'
    )

    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }

        if (-not (Test-Path -LiteralPath $script:LogRoot)) {
            $null = [System.IO.Directory]::CreateDirectory($script:LogRoot)
        }
        if (-not (Test-Path -LiteralPath $script:LogFile)) {
            $null = [System.IO.File]::Create($script:LogFile).Dispose()
        }

        $script:LogReady = $true
        return $true
    }
    catch {
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

function Write-Banner {
    [CmdletBinding()]
    param()

    $title      = '{0} | {1} | {2}' -f $SolutionName, $ScriptMode, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($line -eq $title) {
            Write-Host $line -ForegroundColor White
        } else {
            Write-Host $line -ForegroundColor DarkGray
        }

        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers commonly use `Write-Log -Message ""` to break
    # sections vertically. Mandatory binding treats an empty string as a missing
    # value, so the canonical helper MUST early-return on empty (Pitfall 30).
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileLine  = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $Message -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $fileLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# --- Elevation probe ---------------------------------------------------------
# Detects the current process token; Intune SYSTEM context always passes.
function Test-IsElevated {
    $identity   = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal  = New-Object System.Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# --- Main --------------------------------------------------------------------
$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'Intune'
Write-Banner

if (-not (Test-IsElevated)) {
    Write-Log -Message 'Elevation required - run as Administrator or via Intune (SYSTEM).' -Level 'ERROR'
    exit 1
}
if (-not (Test-Path -LiteralPath $SetupPath)) {
    Write-Log -Message "Office Deployment Tool not found: $SetupPath" -Level 'ERROR'
    exit 1
}
if (-not (Test-Path -LiteralPath $ConfigurationPath)) {
    Write-Log -Message "Configuration file not found: $ConfigurationPath" -Level 'ERROR'
    exit 1
}

Write-Log -Message "Removing Project Professional 2024 with: $ConfigurationPath" -Level 'INFO'

$exitCode = 1
try {
    & $SetupPath /configure $ConfigurationPath
    $exitCode = $LASTEXITCODE
    if ($exitCode -eq 0) {
        Write-Log -Message 'Project Professional 2024 removed successfully.' -Level 'SUCCESS'
    } else {
        Write-Log -Message "setup.exe exited with code $exitCode - see %temp% for ODT logs." -Level 'ERROR'
    }
}
catch {
    Write-Log -Message "Uninstall failed: $($_.Exception.Message)" -Level 'ERROR'
    $exitCode = 2
}

exit $exitCode