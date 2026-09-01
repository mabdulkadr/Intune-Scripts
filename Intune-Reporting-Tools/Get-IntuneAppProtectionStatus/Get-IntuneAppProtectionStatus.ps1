<#
.TITLE
    Intune App Protection Status

.SYNOPSIS
    Reports App Protection Policy (MAM) status across users.

.DESCRIPTION
    Shows which app protection policies exist, their configuration, and user check-in status.
    Identifies users with flagged apps and overall MAM enrollment health.

.TAGS
    Intune,MAM,AppProtection,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementApps.Read.All

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    1.1.0

.CHANGELOG
    1.1.0 (2026-08-26)
    - Migrated to Enterprise Standards canonical structure (header, logging, banner, ErrorActionPreference, full cmdlet names, typed catches)
    1.0.0
    - Initial release

.LASTUPDATE
    2026-08-26

.EXAMPLE
    .\Get-IntuneAppProtectionStatus.ps1
    Reports App Protection Policy status

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Logs: %ProgramData%\get-intune-app-protection-status\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding()]
param([Parameter()][string]$ExportPath)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-app-protection-status'
$ScriptMode   = 'run'

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
# MAIN ENTRY LOGGING INITIALIZATION
# Flow: init -> banner -> modules -> Graph connection -> report generation.
# ============================================================================

$null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
Write-Banner
if ($script:LogReady) {
    Write-Log -Message "Log file ready: $($script:LogFile)" -Level 'DEBUG'
}
Write-Log -Message "Script started" -Level 'INFO'
# ============================================================================
# REPORT OUTPUT ANCHORING
# Anchor relative output paths beside the script so CSV exports land in a
# predictable location regardless of the caller's current directory.
# Fallback chain: $PSScriptRoot -> $PSCommandPath -> $MyInvocation -> Get-Location.
# ============================================================================

$scriptDirectory = if ($PSScriptRoot) {
    $PSScriptRoot
}
elseif ($PSCommandPath) {
    Split-Path -Parent $PSCommandPath
}
elseif ($MyInvocation.MyCommand.Path) {
    Split-Path -Parent $MyInvocation.MyCommand.Path
}
else {
    (Get-Location).Path
}

if ($ExportPath -and -not [System.IO.Path]::IsPathRooted($ExportPath)) {
    $ExportPath = [System.IO.Path]::GetFullPath((Join-Path $scriptDirectory $ExportPath))
}

function Write-Status { param([string]$Msg,[string]$Color='Cyan'); $level = switch ($Color) { 'Red'{'ERROR'} 'Yellow'{'WARNING'} 'Green'{'SUCCESS'} 'DarkYellow'{'WARNING'} 'DarkGray'{'DEBUG'} default{'INFO'} }; Write-Log -Message $Msg -Level $level }
function Write-Section { param([string]$Msg); Write-Log -Message "=== $Msg ===" -Level 'INFO' }

function Get-MgGraphAllPages {
    param([string]$Uri,[string]$Method='GET')
    try {
        $response = Invoke-MgGraphRequest -Uri $Uri -Method $Method -ErrorAction Stop
        $results = @()
        if ($null -ne $response.value) { $results += $response.value }
        elseif ($response) { $results += $response }
        while ($response.'@odata.nextLink') {
            $response = Invoke-MgGraphRequest -Uri $response.'@odata.nextLink' -Method GET -ErrorAction Stop
            if ($null -ne $response.value) { $results += $response.value }
        }
        return ,$results
    } catch [System.Exception] { Write-Verbose "Graph call failed: $_"; return @() }
}

Write-Section "AUTHENTICATION"
$context = Get-MgContext
if (-not $context) {
    Connect-MgGraph -Scopes 'DeviceManagementApps.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

# Windows App Protection Policies
Write-Section "WINDOWS APP PROTECTION POLICIES"
$winPolicies = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/windowsManagedAppProtections"
Write-Status "Found $($winPolicies.Count) Windows app protection policies" "Green"

foreach ($p in $winPolicies) {
    Write-Log -Message "    $($p.displayName)" -Level 'INFO'
    Write-Log -Message "      Allowed data transfer  : $($p.allowedOutboundDataTransferDestinations)" -Level 'DEBUG'
    Write-Log -Message "      Print blocked          : $($p.printBlocked)" -Level 'DEBUG'
    Write-Log -Message "      Org data required      : $($p.isAssigned)" -Level 'DEBUG'

    $report.Add([PSCustomObject]@{
        PolicyName=$p.displayName; PolicyType='Windows MAM'; Platform='Windows'
        IsAssigned=$p.isAssigned; PrintBlocked=$p.printBlocked
        AllowedTransfer=$p.allowedOutboundDataTransferDestinations
        CreatedDateTime=$p.createdDateTime; LastModified=$p.lastModifiedDateTime
    })
}

# MAM managed app statuses
Write-Section "MANAGED APP REGISTRATIONS"
Write-Status "Fetching managed app registrations..."
$managedAppRegs = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceAppManagement/managedAppRegistrations?`$top=100"
Write-Status "Found $($managedAppRegs.Count) managed app registrations" "Green"

$userAppCounts = @{}
$platformCounts = @{}

foreach ($reg in $managedAppRegs) {
    $userId = $reg.userId
    $platform = $reg.deviceType
    if ($null -ne $userId) {
        if (-not $userAppCounts.ContainsKey($userId)) { $userAppCounts[$userId] = 0 }
        $userAppCounts[$userId]++
    }
    if ($null -ne $platform) {
        if (-not $platformCounts.ContainsKey($platform)) { $platformCounts[$platform] = 0 }
        $platformCounts[$platform]++
    }
}

Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Unique users with managed apps : $($userAppCounts.Count)" -Level 'INFO'
Write-Log -Message "  Total app registrations        : $($managedAppRegs.Count)" -Level 'INFO'

if ($platformCounts.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- By Platform ---" -Level 'WARNING'
    foreach ($pc in ($platformCounts.GetEnumerator() | Sort-Object Value -Descending)) {
        Write-Log -Message "    $($pc.Key) : $($pc.Value)" -Level 'INFO'
    }
}

# Flagged users
$flaggedUsers = $managedAppRegs | Where-Object { $_.flaggedReasons -and $_.flaggedReasons.Count -gt 0 }
if ($flaggedUsers.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Flagged Users ($($flaggedUsers.Count)) ---" -Level 'ERROR'
    foreach ($fu in ($flaggedUsers | Select-Object -First 15)) {
        Write-Log -Message "    User: $($fu.userId) | Reason: $($fu.flaggedReasons -join ', ')" -Level 'WARNING'
    }
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "AppProtectionStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'
