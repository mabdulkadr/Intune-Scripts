<#
.TITLE
    Intune Device Timeline

.SYNOPSIS
    Shows a comprehensive timeline of everything that happened to a single device.

.DESCRIPTION
    Pulls all available data for one device: enrollment info, compliance evaluations,
    configuration profile states, app installation status, script execution results, detected
    apps, and hardware details. Presents as a chronological timeline for troubleshooting what
    changed on this device.

.TAGS
    Intune,Device,Timeline,Troubleshooting,Reporting

.PLATFORM
    Windows

.MINROLE
    Intune Administrator

.PERMISSIONS
    DeviceManagementManagedDevices.Read.All,DeviceManagementConfiguration.Read.All,DeviceManagementApps.Read.All,Device.Read.All

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
    .\Get-IntuneDeviceTimeline.ps1 -DeviceName "CYBR-PW00K4WR"
    Shows timeline for a single device

.NOTES
    - Requires Microsoft.Graph.Authentication module
    - Logs: %ProgramData%\get-intune-device-timeline\Logs\<timestamp>.log
#>

#Requires -Version 5.1

[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$DeviceName,
    [Parameter()][string]$ExportPath
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION - solution identity for the embedded logging block.
# ============================================================================

$SolutionName = 'get-intune-device-timeline'
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
    Connect-MgGraph -Scopes 'DeviceManagementManagedDevices.Read.All','DeviceManagementConfiguration.Read.All','DeviceManagementApps.Read.All','Device.Read.All' -ErrorAction Stop
    $context = Get-MgContext
}
Write-Status "Signed in as: $($context.Account)" "Green"

Write-Section "RESOLVING DEVICE: $DeviceName"
$devices = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices?`$filter=deviceName eq '$DeviceName'"
if ($devices.Count -eq 0) { Write-Log -Message "  ERROR: Device not found." -Level 'ERROR'; return }
$device = $devices[0]
$deviceId = $device.id

# Device info
Write-Log -Message "" -Level 'INFO'
Write-Log -Message "  Device Name      : $($device.deviceName)" -Level 'INFO'
Write-Log -Message "  Serial Number    : $($device.serialNumber)" -Level 'INFO'
Write-Log -Message "  Model            : $($device.manufacturer) $($device.model)" -Level 'INFO'
Write-Log -Message "  OS               : $($device.operatingSystem) $($device.osVersion)" -Level 'INFO'
Write-Log -Message "  Primary User     : $($device.userPrincipalName)" -Level 'INFO'
Write-Log -Message "  Entra Device ID  : $($device.azureADDeviceId)" -Level 'INFO'
Write-Log -Message "  Compliance       : $($device.complianceState)" -Level 'WARNING'
Write-Log -Message "  Management Agent : $($device.managementAgent)" -Level 'INFO'
Write-Log -Message "  Ownership        : $($device.managedDeviceOwnerType)" -Level 'INFO'
Write-Log -Message "  Encrypted        : $($device.isEncrypted)" -Level 'INFO'
Write-Log -Message "  Enrolled         : $($device.enrolledDateTime)" -Level 'INFO'
Write-Log -Message "  Last Sync        : $($device.lastSyncDateTime)" -Level 'INFO'

$timeline = [System.Collections.Generic.List[PSCustomObject]]::new()

# Enrollment event
if ($device.enrolledDateTime) {
    $timeline.Add([PSCustomObject]@{ Timestamp=$device.enrolledDateTime; Category='Enrollment'; Event='Device enrolled'; Detail="User: $($device.userPrincipalName)"; State='Success' })
}
if ($device.lastSyncDateTime) {
    $timeline.Add([PSCustomObject]@{ Timestamp=$device.lastSyncDateTime; Category='Sync'; Event='Last sync check-in'; Detail='Device checked in with Intune'; State='Info' })
}

# Configuration profile states
Write-Section "CONFIGURATION PROFILE STATES"
$configStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/deviceConfigurationStates"
Write-Status "$($configStates.Count) configuration profile states" "Green"

foreach ($cs in $configStates) {
    $stateColor = switch ($cs.state) { 'compliant'{'Green'} 'conflict'{'Red'} 'error'{'Red'} 'notApplicable'{'DarkGray'} default{'Yellow'} }
    Write-Log -Message "    [$($cs.state.ToUpper().PadRight(12))] $($cs.displayName)" -Level 'INFO'

    $ts = if ($cs.lastModifiedDateTime) { $cs.lastModifiedDateTime } elseif ($device.lastSyncDateTime) { $device.lastSyncDateTime } else { Get-Date -Format 'o' }
    $timeline.Add([PSCustomObject]@{ Timestamp=$ts; Category='Config Profile'; Event=$cs.displayName; Detail="State: $($cs.state)"; State=$cs.state })
}

# Compliance policy states
Write-Section "COMPLIANCE POLICY STATES"
$compStates = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/deviceCompliancePolicyStates"
Write-Status "$($compStates.Count) compliance policy states" "Green"

foreach ($cs in $compStates) {
    $stateColor = switch ($cs.state) { 'compliant'{'Green'} 'nonCompliant'{'Red'} 'conflict'{'Red'} default{'Yellow'} }
    Write-Log -Message "    [$($cs.state.ToUpper().PadRight(12))] $($cs.displayName)" -Level 'INFO'

    $ts = if ($cs.lastModifiedDateTime) { $cs.lastModifiedDateTime } else { $device.lastSyncDateTime }
    $timeline.Add([PSCustomObject]@{ Timestamp=$ts; Category='Compliance'; Event=$cs.displayName; Detail="State: $($cs.state)"; State=$cs.state })
}

# App installation states
Write-Section "APP INSTALLATION STATES"
Write-Status "Fetching app install statuses for device..."
$appStatuses = Get-MgGraphAllPages -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/managedDeviceOverview"

# Try per-device app status
$deviceApps = @()
try {
    $response = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/detectedApps" -Method GET -ErrorAction Stop
    if ($response.value) { $deviceApps = $response.value }
} catch [System.Exception] { }

if ($deviceApps.Count -gt 0) {
    Write-Status "$($deviceApps.Count) detected apps" "Green"
    $topApps = $deviceApps | Sort-Object displayName | Select-Object -First 20
    foreach ($app in $topApps) {
        Write-Log -Message "    $($app.displayName) v$($app.version)" -Level 'INFO'
        $timeline.Add([PSCustomObject]@{ Timestamp=$device.lastSyncDateTime; Category='Detected App'; Event=$app.displayName; Detail="Version: $($app.version)"; State='Info' })
    }
    Write-Log -Message "    ... and $($deviceApps.Count - 20) more detected apps" -Level 'DEBUG'
} else {
    Write-Log -Message "    No detected app data available via this endpoint" -Level 'DEBUG'
}

# Hardware info
Write-Section "HARDWARE DETAILS"
$hwInfo = $device.hardwareInformation
if ($hwInfo) {
    if ($hwInfo.totalStorageSpace -and $hwInfo.totalStorageSpace -gt 0) {
        $totalGB = [math]::Round($hwInfo.totalStorageSpace / 1GB, 1)
        $freeGB = [math]::Round($hwInfo.freeStorageSpace / 1GB, 1)
        $usedPct = [math]::Round((($hwInfo.totalStorageSpace - $hwInfo.freeStorageSpace) / $hwInfo.totalStorageSpace) * 100, 1)
        Write-Log -Message "    Storage: $freeGB GB free of $totalGB GB ($usedPct% used)" -Level 'WARNING'
    }
    if ($hwInfo.totalRam) {
        Write-Log -Message "    RAM: $([math]::Round($hwInfo.totalRam / 1GB, 1)) GB" -Level 'INFO'
    }
    Write-Log -Message "    Wired IP: $($hwInfo.wiredIPv4Addresses -join ', ')" -Level 'INFO'
    Write-Log -Message "    WiFi MAC: $($hwInfo.wifiMacAddress)" -Level 'INFO'
} else {
    # Try to get extended hardware info
    try {
        $fullDevice = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId`?`$select=hardwareInformation,physicalMemoryInBytes" -Method GET -ErrorAction Stop
        if ($fullDevice.physicalMemoryInBytes) {
            Write-Log -Message "    RAM: $([math]::Round($fullDevice.physicalMemoryInBytes / 1GB, 1)) GB" -Level 'INFO'
        }
    } catch [System.Exception] { Write-Log -Message "    Hardware details not available" -Level 'DEBUG' }
}

# Defender protection state
Write-Section "DEFENDER STATUS"
try {
    $protState = Invoke-MgGraphRequest -Uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/$deviceId/windowsProtectionState" -Method GET -ErrorAction Stop
    Write-Log -Message "    Real-time protection : $($protState.realTimeProtectionEnabled)" -Level 'WARNING'
    Write-Log -Message "    Engine version       : $($protState.engineVersion)" -Level 'INFO'
    Write-Log -Message "    Signature version    : $($protState.antiVirusSignatureVersion)" -Level 'INFO'
    Write-Log -Message "    Signature updated    : $($protState.antiVirusSignatureLastUpdateDateTime)" -Level 'INFO'
    Write-Log -Message "    Last quick scan      : $($protState.lastQuickScanDateTime)" -Level 'INFO'
    Write-Log -Message "    Last full scan       : $($protState.lastFullScanDateTime)" -Level 'INFO'
    Write-Log -Message "    Malware protection   : $($protState.malwareProtectionEnabled)" -Level 'WARNING'
} catch [System.Exception] {
    Write-Log -Message "    Defender data not available" -Level 'DEBUG'
}

# Sort timeline chronologically
$timeline = @($timeline | Sort-Object { try { [datetime]$_.Timestamp } catch [System.Exception] { [datetime]::MinValue } } -Descending)

Write-Section "DEVICE TIMELINE (newest first)"
Write-Log -Message "" -Level 'INFO'
foreach ($t in ($timeline | Select-Object -First 50)) {
    $stateColor = switch ($t.State) { 'compliant'{'Green'} 'Success'{'Green'} 'conflict'{'Red'} 'error'{'Red'} 'nonCompliant'{'Red'} 'notApplicable'{'DarkGray'} 'Info'{'Cyan'} default{'White'} }
    $tsDisplay = try { ([datetime]$t.Timestamp).ToString('yyyy-MM-dd HH:mm') } catch [System.Exception] { $t.Timestamp }
    Write-Log -Message "  $tsDisplay  " -Level 'DEBUG'
    Write-Log -Message "[$($t.Category.PadRight(15))] " -Level 'INFO'
    Write-Log -Message "$($t.Event)" -Level 'INFO'
    if ($t.Detail -and $t.Detail -ne "State: $($t.State)") {
        Write-Log -Message "                                    $($t.Detail)" -Level 'DEBUG'
    }
}
Write-Log -Message "  ... $($timeline.Count - 50) more events (see CSV)" -Level 'DEBUG'

$path = if ($ExportPath) { $ExportPath } else { Join-Path $env:TEMP "$($DeviceName)_Timeline_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv" }
$timeline | Export-Csv -Path $path -NoTypeInformation -Encoding UTF8
Write-Status "Exported to: $path" "Green"
Write-Log -Message "" -Level 'INFO'
