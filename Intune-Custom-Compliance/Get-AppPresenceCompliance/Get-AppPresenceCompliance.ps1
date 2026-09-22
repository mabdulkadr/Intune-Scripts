<#
.TITLE
    Custom Compliance - Application Presence

.SYNOPSIS
    Reports install presence or version for configured applications as custom compliance JSON.

.DESCRIPTION
    Custom compliance discovery script for Microsoft Intune. Checks the uninstall
    registry views (HKLM machine-wide or HKCU per-user) plus known executable
    file markers, and emits one JSON property per configured application name:
    True/False when $IsAppInstallCheckOnly is set, otherwise the installed
    display/file version ('0.0.0.0' when absent).

    A registry match wins; when the registry has no entry (e.g. Chrome installed
    via Google Updater with no ARP entry), a present marker file counts as
    installed — in version mode the file product version is reported.

    Contract for Intune custom compliance (discovery):
    - Exit 0 always + single-line JSON to stdout. Intune evaluates the JSON value,
      not the exit code. Never exit non-zero and never write plain text to stdout
      (both surface as Error 65009 - Invalid json for the discovered setting).
    - On script error still emit valid JSON (absent/false) and exit 0 so the
      device reports non-compliant instead of discovery-error.

.TAGS
    Compliance,CustomCompliance,Inventory

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads uninstall registry keys and tests
    known executable paths only.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-09-22)
    - Add file-marker fallback: when the registry has no entry, a known
      executable path ($AppFileMarkers) counts as installed; version mode
      reports the file product version. Fixes Chrome reporting false/0.0.0.0
      while chrome.exe is present with no ARP entry.
    2.0.1 (2026-09-22)
    - Fix Error 65009: file-only logging (no Write-Host), single stdout JSON line,
      catch emits valid JSON + exit 0 instead of plain-text/exit 2.
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Errors now exit 2 so Intune never misreads a crash as a valid discovery result
    1.1 (2025)
    - Version-check mode returning installed version or 0.0.0.0
    1.0.0
    - Initial release

.LASTUPDATE
    2026-09-22

.EXAMPLE
    .\Get-AppPresenceCompliance.ps1
    Emits {"Google Chrome":true} when Chrome is present (install-check mode).

.EXAMPLE
    .\Get-AppPresenceCompliance.ps1
    Emits {"Google Chrome":"141.0.7390.66"} in version mode, or "0.0.0.0" when absent.

.NOTES
    - Runs in SYSTEM context via Intune custom compliance.
    - Enter application names EXACTLY as shown in Programs and Features.
    - Keep discovery light: one registry sweep + marker file checks, no service/process enumeration.
    - Per-user installs under another user's AppData are not visible to SYSTEM file
      checks — use $UserProfileApp = $true (HKCU registry) for those.
    - Logs: C:\ProgramData\Get-AppPresenceCompliance\Logs
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - applications to discover and discovery mode.
# ============================================================================

$SolutionName = 'Get-AppPresenceCompliance'

# Enter the exact display name as shown in Programs and Features.
[array]$ApplicationNames = @(
    "Google Chrome"
)

# Set to $true to check user-based installs in HKCU instead of system-wide installs in HKLM.
[bool]$UserProfileApp = $false

# Set to $true to return only True/False; $false returns the installed version instead.
[bool]$IsAppInstallCheckOnly = $true

# File-marker fallback per application display name. Used ONLY when the registry
# has no entry — covers installs that write no ARP entry (e.g. Chrome via
# Google Updater). %ProgramFiles% paths are visible to SYSTEM; per-user AppData
# paths resolve to the SYSTEM profile under Intune, so prefer $UserProfileApp
# (HKCU) for per-user installs.
[hashtable]$AppFileMarkers = @{
    "Google Chrome" = @(
        "%ProgramFiles%\Google\Chrome\Application\chrome.exe",
        "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe",
        "%LOCALAPPDATA%\Google\Chrome\Application\chrome.exe"
    )
}

# ============================================================================
# LOGGING BLOCK (embedded canonical scripts/Write-Log.ps1 - copy VERBATIM)
# Single source of truth: Initialize-Log / Write-Banner / Write-Log / Finish-Script.
# ============================================================================

# --- Logging (CLI Configuration) --------------------------------------------
$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else {
    [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\')
}
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

# Creates the log folder/file and reports readiness.
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
        # Custom Compliance: stdout must stay clean for JSON (Error 65009) — file log only.
        return $false
    }
}

# Writes the solution banner to log file ONLY (Custom Compliance: stdout = JSON only, Error 65009).
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1} | {2}' -f $SolutionName, $ScriptMode, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
    $bannerLine = '=' * 78
    $lines      = @('', $bannerLine, $title, $bannerLine)

    foreach ($line in $lines) {
        if ($script:LogReady -and $script:LogFile) {
            Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
        }
    }
}

# Writes one timestamped line to log file ONLY (Custom Compliance: no Write-Host, Error 65009).
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $fileLine  = "[$timestamp] [$Level] $Message"

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $fileLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
    }
}

# Logs the final message and terminates with the given exit code.
function Finish-Script {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [int]$ExitCode,
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO",
        [switch]$NoExit
    )

    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) {
        exit $ExitCode
    }
}

# ============================================================================
# DISCOVERY LOGIC
# Read-only registry sweep + file-marker fallback; output feeds Intune custom
# compliance evaluation.
# ============================================================================

# Returns DisplayName/DisplayVersion entries from the requested registry hive view.
function Get-AppRegistryEntries {
    [CmdletBinding()]
    param (
        [bool]$CheckUserProfile
    )

    $entries = @()

    if ($CheckUserProfile) {
        if (Test-Path -LiteralPath 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall') {
            $entries += Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
                Select-Object DisplayName, DisplayVersion
        }

        if (Test-Path -LiteralPath 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
            $entries += Get-ItemProperty 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
                Select-Object DisplayName, DisplayVersion
        }
    }
    else {
        $entries = Get-ItemProperty `
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' `
            -ErrorAction SilentlyContinue |
            Select-Object DisplayName, DisplayVersion
    }

    return $entries
}

# Returns the first existing marker file for the application, or $null.
function Get-AppMarkerFile {
    [CmdletBinding()]
    param (
        [string]$Application
    )
    if (-not $AppFileMarkers.ContainsKey($Application)) { return $null }
    foreach ($rawPath in $AppFileMarkers[$Application]) {
        $expanded = [System.Environment]::ExpandEnvironmentVariables($rawPath)
        if ([string]::IsNullOrWhiteSpace($expanded)) { continue }
        if (Test-Path -LiteralPath $expanded) { return $expanded }
    }
    return $null
}

# Returns the file product version for a marker exe, or $null.
function Get-MarkerFileVersion {
    [CmdletBinding()]
    param (
        [string]$FilePath
    )
    try {
        $info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
        if (-not [string]::IsNullOrWhiteSpace($info.ProductVersion)) { return $info.ProductVersion }
        if (-not [string]::IsNullOrWhiteSpace($info.FileVersion)) { return $info.FileVersion }
    }
    catch {
        Write-Log -Message "File version read failed for '$FilePath': $($_.Exception.Message)" -Level 'DEBUG'
    }
    return $null
}

# Builds the JSON property bag Intune evaluates against the compliance rules.
function Get-ComplianceJson {
    $regEntries   = Get-AppRegistryEntries -CheckUserProfile $UserProfileApp
    $customObject = @{}

    foreach ($application in $ApplicationNames) {
        $matchedApp = $regEntries |
            Where-Object { $_.DisplayName -eq $application } |
            Select-Object -First 1

        if ($IsAppInstallCheckOnly) {
            if ($null -ne $matchedApp) {
                $customObject[$application] = $true
            }
            else {
                $markerFile = Get-AppMarkerFile -Application $application
                $customObject[$application] = [bool]($null -ne $markerFile)
            }
        }
        elseif ($matchedApp) {
            $customObject[$application] = [string]$matchedApp.DisplayVersion
        }
        else {
            $markerFile = Get-AppMarkerFile -Application $application
            if ($null -ne $markerFile) {
                $fileVersion = Get-MarkerFileVersion -FilePath $markerFile
                if ([string]::IsNullOrWhiteSpace($fileVersion)) { $fileVersion = '1.0.0.0' }
                $customObject[$application] = [string]$fileVersion
            }
            else {
                $customObject[$application] = '0.0.0.0'
            }
        }

        Write-Log -Message "Discovered '$application' -> $($customObject[$application])" -Level 'DEBUG'
    }

    return ($customObject | ConvertTo-Json -Compress)
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> discovery sweep -> emit single JSON line -> exit 0.
# stdout carries ONLY the JSON (Error 65009); all diagnostics go to the log file.

try {
    $ScriptMode = 'run'
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    Write-Log -Message "Discovery started" -Level 'INFO'

    $json = Get-ComplianceJson

    # This Write-Output MUST be the only stdout in the script.
    Write-Output $json
    Write-Log -Message "Discovery completed successfully" -Level 'SUCCESS'
    exit 0
}
catch {
    $errorMsg = "Discovery script error: $($_.Exception.Message)"
    Write-Log -Message $errorMsg -Level 'ERROR'
    # ALWAYS emit valid JSON even on failure — plain text triggers Error 65009.
    # Best effort: one false/version-zero property per configured app so Intune
    # evaluates non-compliant instead of discovery-error.
    $fallback = @{}
    foreach ($application in $ApplicationNames) {
        if ($IsAppInstallCheckOnly) { $fallback[$application] = $false }
        else { $fallback[$application] = '0.0.0.0' }
    }
    if ($fallback.Count -eq 0) { $fallback['Compliant'] = $false }
    ($fallback | ConvertTo-Json -Compress) | Write-Output
    exit 0
}
