<#
.TITLE
    Reinstall Company Portal via Winget

.SYNOPSIS
    Repairs the Microsoft Company Portal installation by uninstalling and reinstalling it with winget.

.DESCRIPTION
    Ensures the Microsoft Company Portal is correctly installed: it verifies administrative privileges,
    resolves the winget executable from the WindowsApps App Installer package, checks whether Company
    Portal is currently installed, uninstalls it when present, and installs it fresh from the Microsoft
    Store source.

    This is a purely local tool - it never calls Microsoft Graph. It modifies the system by design:
    it removes and reinstalls the Company Portal package.

.TAGS
    Windows,Winget,CompanyPortal,Repair,PackageManagement

.PLATFORM
    Windows

.MINROLE
    None (standalone tool)

.PERMISSIONS
    None (local SYSTEM context) - winget package uninstall/install of the Company Portal; requires an elevated (Administrator) console.

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.0.0

.CHANGELOG
    2.0.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, typed catches)
    - Failure paths now exit 1 instead of the legacy bare Exit (exit code hygiene)
    - Console output now mirrored to C:\ProgramData\Repair-CompanyPortal\Logs\
    1.0.0 (2025-01-09)
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Repair-CompanyPortal.ps1
    From an elevated console: uninstalls Company Portal when present, then reinstalls it via winget.

.EXAMPLE
    .\Repair-CompanyPortal.ps1
    Use after a corrupted Company Portal install blocks Intune enrollment or app protection checks.

.NOTES
    - Requires the App Installer (winget) package; the Microsoft Store page opens automatically when it is missing.
    - Installs from the msstore source ("Company Portal"), accepting package and source agreements.
    - Exit 0 = reinstall flow completed; exit 1 = missing elevation, missing winget, or a failed step.
    - Logs: C:\ProgramData\Repair-CompanyPortal\Logs\
#>

#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity and package targets.
# ============================================================================

$SolutionName = 'Repair-CompanyPortal'
$ScriptMode   = 'Repair'

$CompanyName      = "Company Portal"
$StoreProductId   = "9NBLGGH4NNS1"
$WingetSearchRoot = "C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe"

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

# Creates the Intune log folder/file and reports readiness.
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
# PREREQUISITE CHECKS
# Confirms elevation and locates the winget executable.
# ============================================================================

# Verifies the session runs elevated and stops the script when it does not.
function Test-AdminPrivilege {
    if (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-Log -Message "This script must be run as an Administrator." -Level 'ERROR'
        Finish-Script -ExitCode 1 -Message "Elevation required" -Level 'ERROR'
    }
}

# Resolves the winget executable path and opens the Store when App Installer is absent.
function Resolve-WingetPath {
    Write-Log -Message "Resolving winget executable path..." -Level 'INFO'
    $ResolveWingetPath = Resolve-Path $WingetSearchRoot -ErrorAction SilentlyContinue
    if ($ResolveWingetPath) {
        $WingetPath = $ResolveWingetPath[-1].Path
        return "$WingetPath\winget.exe"
    } else {
        Write-Log -Message "winget not found. Please ensure App Installer is installed." -Level 'ERROR'
        Start-Process "ms-windows-store://pdp/?ProductId=$StoreProductId" -Wait
        Finish-Script -ExitCode 1 -Message "winget executable not found" -Level 'ERROR'
    }
}

# Reports whether the Company Portal package is currently installed.
function Test-CompanyPortalInstalled {
    Write-Log -Message "Checking if the Company Portal is installed..." -Level 'INFO'
    $installedApps = & $Winget list --name $CompanyName -e 2>$null
    if ($installedApps -match $CompanyName) {
        Write-Log -Message "Company Portal is installed. Preparing to uninstall..." -Level 'WARNING'
        return $true
    } else {
        Write-Log -Message "Company Portal is not installed." -Level 'INFO'
        return $false
    }
}

# ============================================================================
# PACKAGE ACTIONS
# Uninstalls and reinstalls the Company Portal through winget.
# ============================================================================

# Uninstalls the existing Company Portal package.
function Uninstall-CompanyPortal {
    Write-Log -Message "Uninstalling Company Portal..." -Level 'WARNING'
    try {
        & $Winget uninstall --name $CompanyName
        Write-Log -Message "Company Portal has been uninstalled successfully." -Level 'SUCCESS'
    }
    catch [System.Exception] {
        Finish-Script -ExitCode 1 -Message "Failed to uninstall Company Portal: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# Installs the Company Portal fresh from the Microsoft Store source.
function Install-CompanyPortal {
    Write-Log -Message "Installing Company Portal..." -Level 'INFO'
    try {
        & $Winget install $CompanyName --source msstore --accept-package-agreements --accept-source-agreements
        Write-Log -Message "Company Portal has been installed successfully." -Level 'SUCCESS'
    }
    catch [System.Exception] {
        Finish-Script -ExitCode 1 -Message "Failed to install Company Portal: $($_.Exception.Message)" -Level 'ERROR'
    }
}

# ============================================================================
# MAIN
# Flow: init -> elevate check -> resolve winget -> uninstall if present -> install.
# ============================================================================

try {
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    if ($script:LogReady) {
        Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
    }

    Test-AdminPrivilege
    $Winget = Resolve-WingetPath
    $isInstalled = Test-CompanyPortalInstalled
    if ($isInstalled) {
        Uninstall-CompanyPortal
    }
    Install-CompanyPortal

    Finish-Script -ExitCode 0 -Message "Company Portal reinstall completed" -Level 'SUCCESS'
}
catch {
    Finish-Script -ExitCode 1 -Message "Script error: $($_.Exception.Message)" -Level 'ERROR'
}
