<#
.TITLE
    Custom Compliance - Application Presence

.SYNOPSIS
    Reports install presence or version for configured applications as custom compliance JSON.

.DESCRIPTION
    Custom compliance discovery script for Microsoft Intune. Reads the uninstall
    registry views (HKLM machine-wide or HKCU per-user) and emits one JSON property
    per configured application name: True/False when $IsAppInstallCheckOnly is set,
    otherwise the installed display version ('0.0.0.0' when absent).

    Contract for Intune custom compliance:
    - Exit 0 = discovery succeeded (JSON output is evaluated against the policy rules)
    - Exit 2 = script error (no JSON evaluation occurs)

.TAGS
    Compliance,CustomCompliance,Inventory

.PLATFORM
    Windows

.MINROLE
    Intune Service Administrator

.PERMISSIONS
    None (local SYSTEM context) - reads uninstall registry keys only.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, exit contract)
    - Errors now exit 2 so Intune never misreads a crash as a valid discovery result
    1.1 (2025)
    - Version-check mode returning installed version or 0.0.0.0
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Get-AppPresenceCompliance.ps1
    Emits {"Google Chrome":true} when Chrome is present (install-check mode).

.EXAMPLE
    .\Get-AppPresenceCompliance.ps1
    Emits {"Google Chrome":"141.0.7390.66"} in version mode, or "0.0.0.0" when absent.

.NOTES
    - Runs in SYSTEM context via Intune custom compliance.
    - Enter application names EXACTLY as shown in Programs and Features.
    - Keep discovery light: one registry sweep, no service/process enumeration.
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
        Write-Host "Log initialization failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

# Writes the solution banner to console and log file.
function Write-Banner {
    [CmdletBinding()]
    [Alias('Show-Banner')]
    param()

    $title      = '{0} | {1}' -f $SolutionName, $ScriptMode
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

# Writes one timestamped, level-colored line to console and log file.
function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")]
        [string]$Level = "INFO"
    )

    # Visual spacer support: callers use Write-Log -Message "" to break sections; early-return on empty.
    if ([string]::IsNullOrEmpty($Message)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"

    $color = switch ($Level) {
        "DEBUG"   { "DarkGray" }
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARNING" { "Yellow" }
        "ERROR"   { "Red" }
    }
    Write-Host $logLine -ForegroundColor $color

    if ($script:LogReady -and $script:LogFile) {
        Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false
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
# Read-only registry sweep; output feeds Intune custom compliance evaluation.
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

# Builds the JSON property bag Intune evaluates against the compliance rules.
function Get-ComplianceJson {
    $regEntries   = Get-AppRegistryEntries -CheckUserProfile $UserProfileApp
    $customObject = @{}

    foreach ($application in $ApplicationNames) {
        $matchedApp = $regEntries |
            Where-Object { $_.DisplayName -eq $application } |
            Select-Object -First 1

        if ($IsAppInstallCheckOnly) {
            $customObject[$application] = [bool]($null -ne $matchedApp)
        }
        elseif ($matchedApp) {
            $customObject[$application] = [string]$matchedApp.DisplayVersion
        }
        else {
            $customObject[$application] = '0.0.0.0'
        }

        Write-Log -Message "Discovered '$application' -> $($customObject[$application])" -Level 'DEBUG'
    }

    return ($customObject | ConvertTo-Json -Compress)
}

# ============================================================================
# MAIN
# ============================================================================
# Flow: init -> banner -> discovery sweep -> emit JSON -> exit 0 / 2 on error.

try {
    $ScriptMode = 'run'
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    Write-Log -Message "Discovery started" -Level 'INFO'

    $json = Get-ComplianceJson

    Write-Output $json
    Finish-Script -ExitCode 0 -Message "Discovery completed successfully" -Level 'SUCCESS' -NoExit:$false
}
catch {
    Finish-Script -ExitCode 2 -Message "Discovery script error: $($_.Exception.Message)" -Level 'ERROR'
}
