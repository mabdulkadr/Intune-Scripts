<#
.TITLE
    Intune Feature Update Status

.SYNOPSIS
    Reports feature update profile deployment status per device.

.DESCRIPTION
    For each feature update profile, shows deployment state per device: offered, pending
    download, downloading, installing, pending reboot, installed, cancelled, safeguard held,
    or error. Identifies devices blocked by safeguard holds and those stuck in pending states.

.TAGS
    Intune,FeatureUpdate,Reporting,Updates

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementConfiguration.Read.All

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
    .\Get-IntuneFeatureUpdateStatus.ps1
    Reports feature update status for all profiles

.EXAMPLE
    .\Get-IntuneFeatureUpdateStatus.ps1 -ProfileName "Windows 11 24H2"
    Filters to a specific feature update profile

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Logs: %ProgramData%\get-intune-feature-update-status\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter()][string]$ProfileName,
    [Parameter()][string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-feature-update-status'
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
    Connect-MgGraph -Scopes 'DeviceManagementConfiguration.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

Write-Section "FEATURE UPDATE PROFILES"
$profiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles"

if ($ProfileName) {
    $profiles = $profiles | Where-Object { $_.displayName -like "*$ProfileName*" }
}

Write-Status "$($profiles.Count) feature update profile(s)" "Green"

if ($profiles.Count -eq 0) {
    Write-Log -Message "  No feature update profiles found." -Level 'WARNING'
    return
}

$report = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($profile in ($profiles | Sort-Object displayName)) {
    $pName = $profile.displayName
    $targetVer = $profile.featureUpdateVersion
    $rolloutStart = $profile.rolloutStartDateTime
    $rolloutEnd = $profile.endOfSupportDate
    $createdDate = $profile.createdDateTime

    Write-Section "PROFILE: $pName"
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  Target version   : $targetVer" -Level 'INFO'
    Write-Log -Message "  Rollout start    : $rolloutStart" -Level 'INFO'
    Write-Log -Message "  End of support   : $rolloutEnd" -Level 'INFO'
    Write-Log -Message "  Created          : $createdDate" -Level 'INFO'

    # Get assignments
    $assignments = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles/$($profile.id)/assignments"
    $assignCount = $assignments.Count
    Write-Log -Message "  Assignments      : $assignCount" -Level 'WARNING'

    # Get device states for this profile
    Write-Status "Fetching per-device deployment states..."
    $deviceStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles/$($profile.id)/deviceUpdateStates"

    if ($deviceStates.Count -eq 0) {
        Write-Log -Message "  No device state data available for this profile." -Level 'DEBUG'
        Write-Log -Message "  This may indicate the profile is new or the deployment service hasn't reported yet." -Level 'DEBUG'
        continue
    }

    Write-Status "$($deviceStates.Count) device states returned" "Green"

    # Categorize states
    $stateCounts = @{}
    $safeguardHeld = @()
    $errors = @()
    $pending = @()

    foreach ($ds in $deviceStates) {
        $state = if ($ds.status) { $ds.status } elseif ($ds.state) { $ds.state } else { 'unknown' }
        if (-not $stateCounts.ContainsKey($state)) { $stateCounts[$state] = 0 }
        $stateCounts[$state]++

        if ($state -like '*safeguard*' -or $state -like '*hold*') { $safeguardHeld += $ds }
        if ($state -like '*error*' -or $state -like '*fail*') { $errors += $ds }
        if ($state -like '*pending*' -or $state -like '*download*' -or $state -like '*install*') { $pending += $ds }

        $report.Add([PSCustomObject]@{
            ProfileName    = $pName
            TargetVersion  = $targetVer
            DeviceName     = $ds.deviceDisplayName
            DeviceId       = $ds.deviceId
            UserName       = $ds.userId
            State          = $state
            Substate       = $ds.substate
            LastUpdated    = $ds.lastUpdatedDateTime
            FeatureUpdateVersion = $ds.featureUpdateVersion
        })
    }

    # State distribution
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Deployment State Distribution ---" -Level 'WARNING'
    foreach ($sc in ($stateCounts.GetEnumerator() | Sort-Object Value -Descending)) {
        $stateColor = switch -Wildcard ($sc.Key) {
            '*installed*'  { 'Green' }
            '*success*'    { 'Green' }
            '*upToDate*'   { 'Green' }
            '*safeguard*'  { 'Red' }
            '*hold*'       { 'Red' }
            '*error*'      { 'Red' }
            '*fail*'       { 'Red' }
            '*pending*'    { 'Yellow' }
            '*download*'   { 'Yellow' }
            '*install*'    { 'Yellow' }
            '*reboot*'     { 'Yellow' }
            '*cancel*'     { 'DarkGray' }
            default        { 'White' }
        }
        Write-Log -Message "    $($sc.Key) : $($sc.Value)" -Level 'INFO'
    }

    # Safeguard holds
    if ($safeguardHeld.Count -gt 0) {
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  --- Devices on Safeguard Hold ($($safeguardHeld.Count)) ---" -Level 'ERROR'
        Write-Log -Message "  These devices have a Microsoft-applied compatibility block." -Level 'DEBUG'
        foreach ($sh in ($safeguardHeld | Select-Object -First 10)) {
            Write-Log -Message "    $($sh.deviceDisplayName)" -Level 'WARNING'
        }
        Write-Log -Message "    ... and $($safeguardHeld.Count - 10) more" -Level 'DEBUG'
    }

    # Errors
    if ($errors.Count -gt 0) {
        Write-Log -Message "" -Level 'INFO'
        Write-Log -Message "  --- Devices with Errors ($($errors.Count)) ---" -Level 'ERROR'
        foreach ($e in ($errors | Select-Object -First 10)) {
            Write-Log -Message "    $($e.deviceDisplayName) : $($e.substate)" -Level 'WARNING'
        }
        Write-Log -Message "    ... and $($errors.Count - 10) more" -Level 'DEBUG'
    }
}

# Summary
Write-Section "FEATURE UPDATE SUMMARY"
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Total profiles   : $($profiles.Count)" -Level 'INFO'
Write-Log -Message "  Total devices    : $($report.Count)" -Level 'INFO'

$stateOverall = $report | Group-Object State | Sort-Object Count -Descending
foreach ($so in $stateOverall) {
    Write-Log -Message "    $($so.Name) : $($so.Count)" -Level 'INFO'
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "FeatureUpdateStatus_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path ($($report.Count) rows)" "Green"
Write-Log -Message "" -Level 'INFO'
