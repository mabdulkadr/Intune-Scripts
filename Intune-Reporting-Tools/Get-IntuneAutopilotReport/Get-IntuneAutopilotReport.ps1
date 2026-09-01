<#
.TITLE
    Intune Autopilot Report

.SYNOPSIS
    Reports Autopilot device registration and deployment profile status.

.DESCRIPTION
    Lists all Autopilot registered devices with their profile assignment state, group tag,
    deployment profile, purchase order, serial number, and enrollment status. Identifies
    devices registered but not enrolled, devices with no profile assigned, and deployment
    errors.

.TAGS
    Intune,Autopilot,Enrollment,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementServiceConfig.Read.All,DeviceManagementManagedDevices.Read.All

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
    .\Get-IntuneAutopilotReport.ps1
    Reports Autopilot device inventory

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Logs: %ProgramData%\get-intune-autopilot-report\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding()]
param([Parameter()][string]$ExportPath)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-autopilot-report'
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
    Connect-MgGraph -Scopes 'DeviceManagementServiceConfig.Read.All','DeviceManagementManagedDevices.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

Write-Section "AUTOPILOT DEVICE INVENTORY"
Write-Status "Fetching Autopilot device identities..."
$apDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities"
Write-Status "Found $($apDevices.Count) Autopilot registered devices" "Green"

Write-Status "Fetching Autopilot deployment profiles..."
$apProfiles = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles"
Write-Status "Found $($apProfiles.Count) deployment profiles" "Green"

# Build profile lookup
$profileMap = @{}
foreach ($p in $apProfiles) { $profileMap[$p.id] = $p.displayName }

# Fetch managed devices for cross-reference
Write-Status "Fetching managed devices for enrollment cross-reference..."
$managedDevices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=operatingSystem eq 'Windows'&`$select=id,deviceName,serialNumber,azureADDeviceId,enrolledDateTime"
$managedSerials = @{}
foreach ($md in $managedDevices) {
    if ($md.serialNumber) { $managedSerials[$md.serialNumber] = $md }
}

$report = [System.Collections.Generic.List[PSCustomObject]]::new()
$profileAssigned = 0; $profileNotAssigned = 0; $enrolled = 0; $notEnrolled = 0

foreach ($ap in $apDevices) {
    $serial = $ap.serialNumber
    $profileStatus = $ap.deploymentProfileAssignmentStatus
    $profileName = '-'
    if ($ap.deploymentProfileAssignedDateTime -and $ap.deploymentProfile) {
        $profileName = $ap.deploymentProfile
    }
    $intendedProfile = $ap.intendedDeploymentProfileAssignedDateTime

    $hasProfile = $profileStatus -and $profileStatus -ne 'notAssigned' -and $profileStatus -ne 'failed'
    if ($hasProfile) { $profileAssigned++ } else { $profileNotAssigned++ }

    # Check if enrolled
    $isEnrolled = $false
    $enrolledDevice = $null
    if ($serial -and $managedSerials.ContainsKey($serial)) {
        $isEnrolled = $true
        $enrolledDevice = $managedSerials[$serial]
    }
    if ($isEnrolled) { $enrolled++ } else { $notEnrolled++ }

    $groupTag = $ap.groupTag
    $purchaseOrder = $ap.purchaseOrderIdentifier
    $model = $ap.model
    $manufacturer = $ap.manufacturer

    $report.Add([PSCustomObject]@{
        SerialNumber       = $serial
        Model              = $model
        Manufacturer       = $manufacturer
        GroupTag           = $groupTag
        PurchaseOrder      = $purchaseOrder
        ProfileStatus      = $profileStatus
        ProfileAssignDate  = $ap.deploymentProfileAssignedDateTime
        EnrollmentState    = $ap.enrollmentState
        IsEnrolled         = $isEnrolled
        EnrolledDeviceName = if ($enrolledDevice) { $enrolledDevice.deviceName } else { '-' }
        EnrolledDate       = if ($enrolledDevice) { $enrolledDevice.enrolledDateTime } else { '-' }
        LastContacted      = $ap.lastContactedDateTime
        AddressableUserName = $ap.addressableUserName
        UserPrincipalName  = $ap.userPrincipalName
    })
}

Write-Section "AUTOPILOT STATUS SUMMARY"
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Total registered devices   : $($apDevices.Count)" -Level 'INFO'
Write-Log -Message "  Profile assigned           : $profileAssigned" -Level 'SUCCESS'
Write-Log -Message "  Profile NOT assigned       : $profileNotAssigned" -Level 'WARNING'
Write-Log -Message "  Enrolled in Intune         : $enrolled" -Level 'SUCCESS'
Write-Log -Message "  Registered but not enrolled: $notEnrolled" -Level 'WARNING'

# Profile status breakdown
$statusGroups = $report | Group-Object ProfileStatus | Sort-Object Count -Descending
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  --- Profile Assignment Status ---" -Level 'WARNING'
foreach ($sg in $statusGroups) {
    $statusColor = switch ($sg.Name) { 'assigned'{'Green'} 'notAssigned'{'Red'} 'failed'{'Red'} 'pending'{'Yellow'} default{'White'} }
    Write-Log -Message "    $($sg.Name) : $($sg.Count)" -Level 'INFO'
}

# Group tag distribution
$tagGroups = $report | Where-Object { $_.GroupTag } | Group-Object GroupTag | Sort-Object Count -Descending
if ($tagGroups.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Group Tag Distribution ---" -Level 'WARNING'
    foreach ($tg in ($tagGroups | Select-Object -First 15)) {
        Write-Log -Message "    $($tg.Name) : $($tg.Count) device(s)" -Level 'INFO'
    }
}

# Model distribution
$modelGroups = $report | Where-Object { $_.Model } | Group-Object Model | Sort-Object Count -Descending | Select-Object -First 10
if ($modelGroups.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Top Models ---" -Level 'WARNING'
    foreach ($mg in $modelGroups) {
        Write-Log -Message "    $($mg.Name) : $($mg.Count)" -Level 'INFO'
    }
}

# Deployment profiles
if ($apProfiles.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Deployment Profiles ---" -Level 'WARNING'
    foreach ($p in $apProfiles) {
        $mode = if ($p.extractHardwareHash) { 'Hardware hash' } else { 'Standard' }
        Write-Log -Message "    $($p.displayName) | $mode | OOBE: $(if($p.outOfBoxExperienceSettings.hidePrivacySettings){'Privacy hidden'}else{'Standard'})" -Level 'WARNING'
    }
}

# Devices without profiles
$noProfile = $report | Where-Object { $_.ProfileStatus -eq 'notAssigned' -or -not $_.ProfileStatus }
if ($noProfile.Count -gt 0) {
    Write-Log -Message "" -Level 'INFO'
    Write-Log -Message "  --- Devices Without Profile ($($noProfile.Count)) ---" -Level 'ERROR'
    foreach ($np in ($noProfile | Select-Object -First 15)) {
        Write-Log -Message "    $($np.SerialNumber) | $($np.Model) | Tag: $($np.GroupTag)" -Level 'WARNING'
    }
    Write-Log -Message "    ... and $($noProfile.Count - 15) more" -Level 'DEBUG'
}

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "AutopilotReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$report | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'
